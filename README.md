# Plano de Parto PET Saúde — Petita

Aplicativo Flutter offline-first para construção guiada do Plano de Parto, atendimento educativo pela Petita, integração Supabase, fluxo Multi UBS e envio anonimizado de dúvidas.

## Versão

`0.2.0-beta` / build `20` — V6.0

## Principais recursos da V6.0

- chat responsivo em formato de conversa, com barra de progresso intuitiva;
- aviso fixo no rodapé: **“A Petita pode cometer erros. Confirme informações importantes com a equipe de saúde.”**;
- indicador animado enquanto a Petita consulta a base;
- RAG documental automático sem busca livre na internet;
- upload administrativo de PDF com texto selecionável e DOCX;
- limite de 20 MB por arquivo e reserva interna de 900 MB para documentos;
- processamento automático: conversão, divisão em trechos, embeddings e busca semântica;
- remoção de documento apagando arquivo, trechos e embeddings;
- base fixa validada consultada antes do RAG;
- categorias compartilhadas com a experiência da gestante e cadastro de novas categorias pelo Admin;
- solicitações da Equipe UBS apresentadas em lista para aceitar ou recusar;
- tela **Minhas dúvidas**, na qual a gestante acompanha o status e lê respostas da UBS;
- sem notificações push nesta versão;
- funções principais do Plano de Parto continuam offline-first.

## Arquitetura RAG

```text
Admin anexa PDF/DOCX
        ↓
Supabase Storage
        ↓
Edge Function converte o arquivo em texto
        ↓
Texto é dividido em trechos
        ↓
Cloudflare Workers AI gera embeddings
        ↓
Supabase pgvector armazena e pesquisa os trechos
        ↓
Petita formula resposta usando somente as referências cadastradas
```

O processamento dos embeddings é dividido automaticamente em lotes. O administrador não precisa executar scripts após o sistema estar configurado.

## Configuração obrigatória

Antes de utilizar o RAG, siga:

`documentos/CONFIGURACAO_RAG_V6.md`

Execute também no SQL Editor do Supabase:

`documentos/supabase_patch_v6_rag_documentos.sql`

## Rodar localmente

```powershell
cd "C:\apppetita\plano_parto_pet_saude"
flutter clean
flutter pub get
flutter run -d chrome --release
```

Para publicar pelo GitHub Pages, mantenha o workflow já existente no repositório. Depois de copiar esta versão, faça `git add`, `git commit` e `git push`; o Actions fará um novo deploy.

## Segurança

- o Flutter utiliza apenas a chave pública/publishable do Supabase;
- a `service_role` fica somente nas Edge Functions;
- tokens da Cloudflare ficam como secrets do Supabase;
- a função pública de consulta RAG valida a chave publishable do aplicativo, enquanto anexar e remover documentos exige sessão Admin;
- Admin é validado no servidor antes de anexar, processar ou remover documentos;
- dúvidas vistas pela Equipe UBS permanecem anonimizadas;
- respostas da Petita são educativas e não substituem avaliação profissional.
