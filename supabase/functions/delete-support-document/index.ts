import { createClient } from 'npm:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders })

  try {
    const authHeader = req.headers.get('Authorization') ?? ''
    const supabaseUrl = mustEnv('SUPABASE_URL')
    const anonKey = mustEnv('SUPABASE_ANON_KEY')
    const serviceRoleKey = mustEnv('SUPABASE_SERVICE_ROLE_KEY')

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    })
    const { data: userData, error: userError } = await userClient.auth.getUser()
    if (userError || !userData.user) return json({ error: 'Usuário não autenticado.' }, 401)

    const { data: profile } = await userClient.from('profiles').select('role').eq('id', userData.user.id).maybeSingle()
    if (profile?.role !== 'admin') return json({ error: 'Apenas administradores podem remover documentos.' }, 403)

    const { document_id } = await req.json()
    if (!document_id) return json({ error: 'document_id é obrigatório.' }, 400)

    const service = createClient(supabaseUrl, serviceRoleKey)
    const { data: document, error } = await service
      .from('support_documents')
      .select('id, file_path')
      .eq('id', document_id)
      .single()
    if (error || !document) return json({ error: 'Documento não encontrado.' }, 404)

    const { error: storageError } = await service.storage.from('support-documents').remove([document.file_path])
    if (storageError) throw new Error(storageError.message)

    const { error: deleteError } = await service.from('support_documents').delete().eq('id', document_id)
    if (deleteError) throw new Error(deleteError.message)

    return json({ deleted: true })
  } catch (error) {
    return json({ error: error instanceof Error ? error.message : String(error) }, 500)
  }
})

function mustEnv(name: string): string {
  const value = Deno.env.get(name)
  if (!value) throw new Error(`Segredo ${name} não configurado.`)
  return value
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  })
}
