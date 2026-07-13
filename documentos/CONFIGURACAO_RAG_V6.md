# Configuração do RAG — Petita V6.0

A configuração é feita uma vez. Depois disso, o administrador envia e remove documentos diretamente pelo app, sem participação do desenvolvedor no uso cotidiano.

## 1. Executar o patch SQL

No Supabase:

1. Abra **SQL Editor**.
2. Crie uma nova query.
3. Copie o conteúdo de `supabase_patch_v6_rag_documentos.sql`.
4. Execute.

O patch cria:

- bucket privado `support-documents`;
- tabela `support_documents`;
- tabela `document_chunks` com vetores de 1024 dimensões;
- logs do RAG;
- busca semântica com pgvector;
- função para a gestante consultar as próprias dúvidas;
- políticas que restringem documentos ao Admin.

## 2. Criar uma conta Cloudflare

A Cloudflare será usada apenas para:

- converter PDF/DOCX em texto;
- gerar embeddings;
- elaborar uma resposta baseada somente nos trechos encontrados.

A Petita não usa busca livre na web.

No painel Cloudflare:

1. Localize o **Account ID**.
2. Crie um API Token com permissão para usar **Workers AI**.
3. Guarde o Account ID e o token; não coloque esses valores no Flutter nem no GitHub.

## 3. Instalar ou usar a CLI do Supabase

No PowerShell, dentro do projeto:

```powershell
cd "C:\apppetita\plano_parto_pet_saude"
npx supabase login
npx supabase link --project-ref ugsdkclpfiwfvjbumrjh
```

## 4. Cadastrar os secrets

Substitua os valores abaixo pelos dados da Cloudflare:

```powershell
npx supabase secrets set CLOUDFLARE_ACCOUNT_ID="SEU_ACCOUNT_ID"
npx supabase secrets set CLOUDFLARE_API_TOKEN="SEU_TOKEN"
npx supabase secrets set PETITA_PUBLISHABLE_KEY="SUA_CHAVE_SB_PUBLISHABLE"
```

A variável `PETITA_PUBLISHABLE_KEY` deve receber a mesma chave pública `sb_publishable_...` usada em `lib/config/supabase_config.dart`. Ela não é uma credencial administrativa; serve para validar que a chamada pública do RAG veio do aplicativo.

As variáveis `SUPABASE_URL`, `SUPABASE_ANON_KEY` e `SUPABASE_SERVICE_ROLE_KEY` são fornecidas automaticamente no ambiente das Edge Functions.

## 5. Publicar as Edge Functions

```powershell
npx supabase functions deploy process-support-document
npx supabase functions deploy ask-petita-rag
npx supabase functions deploy delete-support-document
```

## 6. Testar

1. Entre no app com a conta Admin.
2. Abra **Documentos de apoio**.
3. Selecione uma categoria.
4. Escolha PDF com texto selecionável ou DOCX, até 20 MB.
5. Toque em **Anexar documento**.
6. Aguarde o status mudar de **Processando...** para **Disponível para a Petita**.
7. Abra o chat e faça uma pergunta relacionada ao documento.

## Limites definidos no app

- formatos: PDF textual e DOCX;
- máximo por arquivo: 20 MB;
- máximo total reservado: 900 MB;
- máximo de 600 trechos por documento;
- PDF escaneado é recusado;
- o processamento acontece em lotes automáticos para não depender de script local.

O espaço de arquivos e o espaço do banco são limites diferentes. Os 900 MB controlam os arquivos no Storage; trechos e embeddings também ocupam o banco Postgres. A tela Admin exibe o uso dos arquivos, mas o painel do Supabase deve continuar sendo acompanhado para verificar o tamanho do banco.

## Quando um documento é removido

A função de remoção apaga:

- o PDF/DOCX do Storage;
- o registro do documento;
- todos os trechos e embeddings associados, por exclusão em cascata.

## Erros comuns

### PDF sem texto selecionável

Converta o documento para um PDF textual ou envie a versão DOCX.

### Segredo não configurado

Confirme `CLOUDFLARE_ACCOUNT_ID`, `CLOUDFLARE_API_TOKEN` e `PETITA_PUBLISHABLE_KEY` em **Edge Functions > Secrets**.

### Documento permanece em processamento

Consulte os logs da função `process-support-document`. Em planos gratuitos, documentos muito extensos podem atingir limites temporários do serviço de IA. Remova o documento se necessário e envie uma versão dividida em partes menores.

### A Petita não encontra resposta

Confirme se:

- o documento está como **Disponível para a Petita**;
- a pergunta corresponde ao conteúdo;
- o documento foi classificado na categoria correta;
- o conteúdo extraído está legível.
