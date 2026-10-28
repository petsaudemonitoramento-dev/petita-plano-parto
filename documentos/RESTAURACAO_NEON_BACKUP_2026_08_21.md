# Restauração da Petita no Neon — 19/10/2026

## Fonte
- Arquivo fornecido: backup PostgreSQL compactado gerado em 21/08/2026 (não contém alterações posteriores).
- Verificação: gzip legível, dump SQL do cluster PostgreSQL.
- ZIP do Storage: arquivo válido, porém vazio (zero objetos).
- O dump também não registra objetos em `storage.objects`.

## Destino
- Projeto Neon: `petita-plano-parto` (`odd-rain-12685360`)
- Branch principal: `br-flat-smoke-b6tb97ou`
- PostgreSQL 17, região São Paulo.
- Validação prévia no branch temporário `validacao-backup-2026-08-21`.
- Complemento de esquema: `neon_complemento_backup_20260821.sql`.
- Migração do banco principal realizada com transação; verificação de contagem concluída.

| Tabela / objeto | Linhas na origem (backup) | No Neon principal |
|---|---:|---:|
| UBS | 3 | 3 |
| perfis | 1 | 1 |
| base de conhecimentos | 3 | 3 |
| opções de sinais de alerta | 9 | 9 |
| planos de parto | 0 | 0 |
| dúvidas enviadas | 0 | 0 |
| respostas UBS | 0 | 0 |
| trechos vetoriais RAG | 0 | 0 |
| categorias educativas | não presente no backup | 8 (pré-cadastradas pela reconstrução V6) |

## Garantias e limitações

- Todas as **15 tabelas** principais têm RLS ativada.
- Nenhuma política de acesso ao cliente foi liberada ainda (zero `pg_policies`).
- A extensão vetorial PostgreSQL foi testada.
- O registro administrativo antigo foi preservado, mas **não está autenticado no Neon**.
  A associação a uma futura identidade Neon Auth deverá ser validada por responsável autorizado.
- Dados de `auth.users`, hashes de senhas, tokens de sessão, roles e secrets do Supabase
  **não foram transferidos**; não restaurar o dump inteiro no Neon.
- Triggers/funções e políticas dependentes do Supabase Auth não foram transplantados.
- Não se importou o ZIP vazio, nem foram criados documentos inexistentes.
- As 8 categorias foram pré-criadas antes da restauração; não confundir com dados do backup.
- A aplicação Flutter permanece apontada ao Supabase. É necessário migrar os serviços de acesso,
  API e processamento RAG e integrar o login. Nenhum deploy de produção foi realizado.
- Esta restauração cobre o estado do banco **em 21/08/2026**; se existirem dados inseridos depois,
  será necessária outra exportação.

## Próximas integrações

1. Configurar Neon Auth (Google OAuth e email/senha) pelo responsável.
2. Vincular contas autorizadas a `public.profiles.auth_user_id`, sem atribuir o papel de admin automaticamente.
3. Implementar API com validação de sessão/JWT, segregação por UBS e acesso mínimo.
4. Adaptar serviços Flutter e as três Edge Functions Supabase (RAG/upload/remoção).
5. Configurar armazenamento privado para PDFs/DOCX quando necessário.
6. Testar fluxo gestante, equipe UBS, administração e o funcionamento offline antes de produção.

**Status:** banco de dados restaurado e verificado; aplicativo ainda não migrado/operacional.
