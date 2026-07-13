import { createClient } from 'npm:@supabase/supabase-js@2'

declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void }

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const EMBEDDING_MODEL = '@cf/baai/bge-m3'
const MAX_CHUNKS = 600
const CHUNK_SIZE = 2200
const CHUNK_OVERLAP = 280
const EMBEDDING_BATCH_SIZE = 12

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabaseUrl = mustEnv('SUPABASE_URL')
    const anonKey = mustEnv('SUPABASE_ANON_KEY')
    const serviceRoleKey = mustEnv('SUPABASE_SERVICE_ROLE_KEY')
    const token = authHeader.replace(/^Bearer\s+/i, '').trim()
    const internalCall = token === serviceRoleKey

    if (!internalCall) {
      const userClient = createClient(supabaseUrl, anonKey, {
        global: { headers: { Authorization: authHeader } },
      })
      const { data: userData, error: userError } = await userClient.auth.getUser()
      if (userError || !userData.user) return json({ error: 'Usuário não autenticado.' }, 401)

      const { data: profile } = await userClient
        .from('profiles')
        .select('role')
        .eq('id', userData.user.id)
        .maybeSingle()
      if (profile?.role !== 'admin') return json({ error: 'Apenas administradores podem processar documentos.' }, 403)
    }

    const { document_id, phase = 'prepare' } = await req.json()
    if (!document_id) return json({ error: 'document_id é obrigatório.' }, 400)

    const service = createClient(supabaseUrl, serviceRoleKey)
    const { data: document, error: documentError } = await service
      .from('support_documents')
      .select('*')
      .eq('id', document_id)
      .single()
    if (documentError || !document) return json({ error: 'Documento não encontrado.' }, 404)

    if (phase === 'embed') {
      EdgeRuntime.waitUntil(processEmbeddingBatch(service, document))
      return json({ accepted: true, phase: 'embed', document_id }, 202)
    }

    await service
      .from('support_documents')
      .update({
        status: 'processing',
        processing_error: null,
        chunk_count: 0,
        total_chunks: 0,
        embedded_chunks: 0,
        updated_at: new Date().toISOString(),
      })
      .eq('id', document_id)

    EdgeRuntime.waitUntil(prepareDocument(service, document))
    return json({ accepted: true, phase: 'prepare', document_id }, 202)
  } catch (error) {
    return json({ error: safeMessage(error) }, 500)
  }
})

async function prepareDocument(service: ReturnType<typeof createClient>, document: Record<string, unknown>) {
  const documentId = String(document.id)
  try {
    const filePath = String(document.file_path)
    const fileName = String(document.file_name)
    const mimeType = String(document.mime_type)

    const { data: blob, error: downloadError } = await service.storage
      .from('support-documents')
      .download(filePath)
    if (downloadError || !blob) throw new Error(`Falha ao baixar o arquivo: ${downloadError?.message ?? 'arquivo indisponível'}`)

    const markdown = await convertToMarkdown(blob, fileName, mimeType)
    const cleaned = cleanMarkdown(markdown)
    if (mimeType === 'application/pdf' && cleaned.length < 300) {
      throw new Error('O PDF não possui texto selecionável suficiente. Envie um PDF textual ou um arquivo DOCX.')
    }
    if (cleaned.length < 80) throw new Error('Não foi possível extrair conteúdo textual suficiente do documento.')

    const chunks = splitIntoChunks(cleaned)
    if (chunks.length === 0) throw new Error('Nenhum trecho útil foi encontrado no documento.')
    if (chunks.length > MAX_CHUNKS) {
      throw new Error(`O documento gerou mais de ${MAX_CHUNKS} trechos. Divida o arquivo em documentos menores.`)
    }

    await service.from('document_chunks').delete().eq('document_id', documentId)

    for (let start = 0; start < chunks.length; start += 100) {
      const rows = chunks.slice(start, start + 100).map((content, index) => ({
        document_id: documentId,
        chunk_index: start + index,
        content,
        embedding: null,
      }))
      const { error: insertError } = await service.from('document_chunks').insert(rows)
      if (insertError) throw new Error(`Falha ao salvar os trechos extraídos: ${insertError.message}`)
    }

    await service
      .from('support_documents')
      .update({
        status: 'processing',
        total_chunks: chunks.length,
        embedded_chunks: 0,
        chunk_count: 0,
        processing_error: null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', documentId)

    await invokeNextBatch(documentId)
  } catch (error) {
    await markDocumentError(service, documentId, error)
  }
}

async function processEmbeddingBatch(service: ReturnType<typeof createClient>, document: Record<string, unknown>) {
  const documentId = String(document.id)
  try {
    if (String(document.status) === 'available') return

    const { data: pending, error: pendingError } = await service
      .from('document_chunks')
      .select('id, document_id, chunk_index, content')
      .eq('document_id', documentId)
      .is('embedding', null)
      .order('chunk_index', { ascending: true })
      .limit(EMBEDDING_BATCH_SIZE)
    if (pendingError) throw new Error(`Falha ao carregar trechos pendentes: ${pendingError.message}`)

    const rows = Array.isArray(pending) ? pending : []
    if (rows.length === 0) {
      const total = Number(document.total_chunks ?? document.chunk_count ?? 0)
      await service
        .from('support_documents')
        .update({
          status: 'available',
          chunk_count: total,
          embedded_chunks: total,
          processing_error: null,
          processed_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('id', documentId)
      return
    }

    const texts = rows.map((row) => String(row.content))
    const embeddings = await createEmbeddings(texts)
    if (embeddings.length !== rows.length) throw new Error('A quantidade de vetores gerados não corresponde aos trechos enviados.')

    const updateResults = await Promise.all(
      rows.map((row, index) =>
        service.from('document_chunks').update({ embedding: embeddings[index] }).eq('id', row.id),
      ),
    )
    const updateError = updateResults.find((result) => result.error)?.error
    if (updateError) throw new Error(`Falha ao salvar a busca semântica: ${updateError.message}`)

    const { count: remaining, error: countError } = await service
      .from('document_chunks')
      .select('id', { count: 'exact', head: true })
      .eq('document_id', documentId)
      .is('embedding', null)
    if (countError) throw new Error(`Falha ao conferir o processamento: ${countError.message}`)

    const total = Number(document.total_chunks ?? 0)
    const remainingCount = remaining ?? 0
    const embedded = Math.max(0, total - remainingCount)
    await service
      .from('support_documents')
      .update({
        status: remainingCount === 0 ? 'available' : 'processing',
        embedded_chunks: embedded,
        chunk_count: remainingCount === 0 ? total : embedded,
        processing_error: null,
        processed_at: remainingCount === 0 ? new Date().toISOString() : null,
        updated_at: new Date().toISOString(),
      })
      .eq('id', documentId)

    if (remainingCount > 0) await invokeNextBatch(documentId)
  } catch (error) {
    await markDocumentError(service, documentId, error)
  }
}

async function invokeNextBatch(documentId: string) {
  const supabaseUrl = mustEnv('SUPABASE_URL')
  const serviceRoleKey = mustEnv('SUPABASE_SERVICE_ROLE_KEY')
  const response = await fetch(`${supabaseUrl}/functions/v1/process-support-document`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${serviceRoleKey}`,
      apikey: serviceRoleKey,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ document_id: documentId, phase: 'embed' }),
  })
  if (!response.ok) {
    const detail = await response.text()
    throw new Error(`Não foi possível continuar o processamento automático: ${detail || response.statusText}`)
  }
}

async function markDocumentError(service: ReturnType<typeof createClient>, documentId: string, error: unknown) {
  await service
    .from('support_documents')
    .update({
      status: 'error',
      processing_error: safeMessage(error),
      updated_at: new Date().toISOString(),
    })
    .eq('id', documentId)
}

async function convertToMarkdown(blob: Blob, fileName: string, mimeType: string): Promise<string> {
  const accountId = mustEnv('CLOUDFLARE_ACCOUNT_ID')
  const apiToken = mustEnv('CLOUDFLARE_API_TOKEN')
  const form = new FormData()
  form.append('files', new File([await blob.arrayBuffer()], fileName, { type: mimeType }))
  form.append('conversionOptions', JSON.stringify({ output: { format: 'text' }, pdf: { metadata: false } }))

  const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/tomarkdown`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiToken}` },
    body: form,
  })
  const payload = await response.json()
  if (!response.ok || payload?.success !== true) {
    throw new Error(`Conversão do documento falhou: ${payload?.errors?.[0]?.message ?? response.statusText}`)
  }
  const result = payload.result?.[0]
  if (!result || result.format === 'error') throw new Error(result?.error ?? 'O arquivo não pôde ser convertido em texto.')
  return String(result.data ?? '')
}

async function createEmbeddings(inputs: string[]): Promise<number[][]> {
  const accountId = mustEnv('CLOUDFLARE_ACCOUNT_ID')
  const apiToken = mustEnv('CLOUDFLARE_API_TOKEN')
  const response = await fetch(`https://api.cloudflare.com/client/v4/accounts/${accountId}/ai/v1/embeddings`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ model: EMBEDDING_MODEL, input: inputs }),
  })
  const payload = await response.json()
  if (!response.ok || !Array.isArray(payload?.data)) {
    throw new Error(`Falha ao gerar busca semântica: ${payload?.error?.message ?? response.statusText}`)
  }
  return payload.data.map((item: { embedding: number[] }) => item.embedding)
}

function cleanMarkdown(value: string): string {
  return value
    .replace(/!\[[^\]]*\]\(data:image\/[^)]+\)/gi, ' ')
    .replace(/<img[^>]*>/gi, ' ')
    .replace(/\r/g, '')
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{4,}/g, '\n\n')
    .trim()
}

function splitIntoChunks(text: string): string[] {
  const paragraphs = text.split(/\n\s*\n/).map((p) => p.trim()).filter(Boolean)
  const chunks: string[] = []
  let current = ''

  const pushCurrent = () => {
    const value = current.trim()
    if (value.length >= 80) chunks.push(value)
    current = ''
  }

  for (const paragraph of paragraphs) {
    if (paragraph.length > CHUNK_SIZE) {
      pushCurrent()
      let start = 0
      while (start < paragraph.length) {
        const end = Math.min(paragraph.length, start + CHUNK_SIZE)
        const part = paragraph.slice(start, end).trim()
        if (part.length >= 80) chunks.push(part)
        if (end >= paragraph.length) break
        start = Math.max(start + 1, end - CHUNK_OVERLAP)
      }
      continue
    }

    const candidate = current ? `${current}\n\n${paragraph}` : paragraph
    if (candidate.length <= CHUNK_SIZE) {
      current = candidate
    } else {
      const previous = current
      pushCurrent()
      const overlap = previous.slice(Math.max(0, previous.length - CHUNK_OVERLAP)).trim()
      current = overlap ? `${overlap}\n\n${paragraph}` : paragraph
    }
  }
  pushCurrent()
  return chunks
}

function mustEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Segredo ${name} não configurado.`)
  return value
}

function safeMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error)
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
