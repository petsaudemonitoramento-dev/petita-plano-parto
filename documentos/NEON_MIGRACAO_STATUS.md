# Petita V6.0 — Migração Supabase → Neon (estado parcial)

## Destino preparado em 16/10/2026

- Projeto Neon **petita-plano-parto**
- Project ID: `odd-rain-12685360`
- Branch: `main` (`br-flat-smoke-b6tb97ou`)
- Região: `aws-sa-east-1` (São Paulo); PostgreSQL 17
- Base SQL: `documentos/neon_schema_base_v6.sql`
- Instalação validada: 13 tabelas, extensão `vector`, índices, RLS ativada, 3 UBS e 8 categorias.
- **Neon Auth NÃO habilitado**: o responsável pelo projeto configurará autenticação, inclusive Google OAuth, posteriormente.
- **Neon Data API NÃO habilitada**: tabelas não devem ser expostas antes de autenticação, autorização e testes.
- O projeto `supabase-keeper` não foi modificado.
- O app Flutter V6.0 original não foi modificado nem redirecionado ao Neon.

## Fonte Supabase bloqueada

- Projeto Supabase original: `ugsdkclpfiwfvjbumrjh` (`Petitaapp`).
- Status observado: `INACTIVE`.
- As chamadas para inspecionar tabelas, executar SQL e listar migrações expiraram.
- Os scripts SQL versionados no repositório NÃO representam necessariamente o estado real
  do banco original. O esquema Neon é uma **reconstrução parcial**, não um `pg_dump`.
- Não foram copiadas gestantes, contas, planos de parto, dúvidas, respostas, documentos
  nem embeddings. Não criar dados fictícios para aparentar restauração.

**Para migrar registros reais:** obter o backup/exportação do banco inativo no painel Supabase,
inspecioná-lo de forma segura, mapear diferenças de schema, importar para o Neon com validação
de contagem de linhas, chaves e relacionamentos; importar arquivos do Storage separadamente.
Se o backup contiver dados de saúde, protegê-lo e não colocá-lo no GitHub público.

## Atenção: banco preparado ≠ aplicativo migrado

- `lib/main.dart` e `lib/services/supabase_service.dart` ainda inicializam e usam
  `supabase_flutter`. Não substituir a URL Supabase por uma URL PostgreSQL Neon.
- O Flutter **não pode** usar `DATABASE_URL` ou senha administrativa diretamente.
- É necessária uma camada de API segura (Neon Functions em região suportada,
  Cloudflare Worker ou backend existente) para ler e escrever dados.
- O backend deverá validar JWT/sessão antes de cada requisição, impor perfis
  (patient, ubs_team, admin) e restringir equipes às respectivas UBS.
- O RLS está habilitado, **sem políticas abertas**; nenhuma regra de autorização final
  foi implementada, de propósito, enquanto o login não estiver integrado.
- O schema usa `profiles.auth_user_id text` e campos de identidade textuais
  onde a origem usava `auth.users`. Exige reconciliação de identidades na importação.
- Neon Auth usa Better Auth; não supor que senhas e sessões Supabase migrem.
  Google OAuth é suportado no Neon Auth, mas a integração Flutter requer tratar
  corretamente fluxo de browser/deep link e tokens.
- `team_questions_anonymous` é uma view restrita, sem ID de paciente.
  O isolamento por UBS precisa ser imposto e testado na API.
- As RPCs dependentes de `auth.uid()` e `auth.jwt()` não foram copiadas.
  Reimplementar com verificação segura de identidade antes de disponibilizar.
- As 3 Edge Functions Supabase `ask-petita-rag`, `process-support-document`
  e `delete-support-document` ainda não foram migradas.
- O Storage `support-documents` e os arquivos não foram migrados.
- Se forem necessárias Functions ou Object Storage do Neon, confirmar
  disponibilidade na região do projeto; São Paulo não está entre as regiões
  anunciadas para esses serviços na documentação consultada. É possível usar
  provedor externo mantendo o banco Neon em São Paulo.
- A geração local do PDF de Plano de Parto e os assets offline-first
  seguem intactos no repositório Flutter.

## Portabilidade e conferência antes do corte definitivo

1. Recuperar backup Supabase e reconciliar colunas, constraints, functions e dados.
2. Concluir API, storage de documentos e processamento documental / RAG.
3. Integrar Neon Auth ou outro provedor com Google OAuth e email/senha.
4. Criar políticas de acesso compatíveis com as identidades e validar LGPD.
5. Testar fluxo completo de gestante, profissional UBS e admin; garantir
   que nenhuma UBS enxergue perguntas de outra.
6. Conferir e comparar contagens e hashes de dados migrados; testar embeddings
   e PDF sem rede; preparar rollback.
7. Somente então alterar a configuração do Flutter e publicar.

**Não há corte para produção nesta etapa.**
