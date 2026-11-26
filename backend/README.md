# Petita — API canônica Neon (candidata de homologação)
Não publicada. Não utilizar dados reais. Implementa as rotas UBS, perfil já vinculado, dúvidas não urgentes, fila, resposta e decisão/revogação de acesso profissional nas funções de `petita`/ `petita_private` das PRs #15/#17. Não reutiliza `petita_atendimento`/ `petita_privado` da PR #19.

Neon JWT: iss e aud são a ORIGEM do Auth (não /neondb/auth), conforme https://neon.com/docs/auth/guides/plugins/jwt. EdDSA, exp/iat/sub obrigatórios, email verificado, usuário não banido. Papel só do banco. Contexto por transação READ COMMITTED, role petita_runtime, parâmetros vinculados, sem fallback para owner. O backend recusa login com bypass/CREATEROLE/CREATEDB/superuser e não expõe credenciais ao cliente. A autorização de perfil usa vínculos já aprovados. JWT pode permanecer válido até expiração: revogação de sessão imediata ainda precisa de solução/teste; revogação de vínculo no banco é consultada a cada operação.

Configuração exclusiva de preview: PETITA_MODE=homologacao, DATABASE_URL (login dedicado, TLS verify-full), PETITA_DB_LOGIN, NEON_AUTH_BASE_URL, NEON_AUTH_JWKS_URL, PETITA_WEB_ORIGIN. Nunca utilizar owner ou credenciais de produção. Não usar domínio da versão pública antiga. API retorna dados em envelope {data:[...]}. /api/health não verifica o banco; GET /api/ubs é um teste de DB público sem dados pessoais.

Limites explícitos: não há cadastro automático de identidade, vínculo gestante/UBS, plano de parto sincronizado, consentimento versionado persistente, encerramento sem resposta, RAG/arquivos, rate limiting persistente, adaptador Flutter ou publicação. Não simular sucesso desses fluxos: rota ausente retorna 404. Esta PR não substitui a revisão clínica e jurídica, nem autoriza uso real. Não habilitar Data API. O teste de regressão usa dados fictícios e não conecta ao banco. Rodar testes de JWT real e autorização com login dedicado antes de qualquer deploy público. A branch institucional de homologação possui migrations 001–003; main do banco não foi alterado.

npm install --ignore-scripts
npm run check
npm test

Antes do deploy, gerar e revisar package-lock.json, usar npm ci, verificar dependências, validar regras de Vercel e concluir gates de integração. A migração do Flutter continua em PR própria para preservar a experiência offline e o questionário.

## Migration 004
A API passa a exigir a migration 004 antes de operações autenticadas. A identidade Neon verificada é consultada no banco (emailVerified, banned) e o cadastro inicial é explícito via POST /api/profile, sem parâmetros de identidade/papel/UBS. A função cria somente patient sem vínculo UBS; o vínculo profissional e a vinculação institucional da gestante continuam processos de autorização separados. O contexto continua derivado exclusivamente do JWT validado pelo backend. A verificação de estado da conta não prova revogação individual de JWT em logout. Não aplicar 004 em produção sem CI, revisão e reconciliação da identidade histórica.

## Migration 005 — consentimento de sincronização e revisão
Consentimento online é um ato separado e explícito, com versão atual do termo e chave de operação; não se inferem consentimentos históricos. Eventos grant/withdraw são append-only. RLS restringe leitura e escrita ao paciente autenticado, e políticas restritivas impedem INSERT/UPDATE de planos sem consentimento ativo. Atualizações exigem expected_revision e retornam 409 em conflito; não há sobrescrita silenciosa. As rotas de leitura dos planos continuam disponíveis ao titular, inclusive após retirar consentimento, para assegurar acesso aos próprios registros. Não há exclusão/exportação completa, revisão jurídica ou integração da UI nesta entrega. O limite de corpo atual é 16 KiB, não há armazenamento documental/RAG. Homologação exclusivamente com dados fictícios.

## Homologação do login web
Tela interna auth-preview.html utiliza o SDK oficial Neon para cadastro, entrada, confirmação por OTP, reenvio, sessão e criação do perfil. O endpoint de configuração é restrito ao modo homologacao, flag PETITA_AUTH_PREVIEW e domínio confiável exato. Não usar dados reais. O build inicial passou em 17 testes, porém npm reportou 5 vulnerabilidades (3 altas, 1 crítica, 1 baixa); a nova verificação npm audit --audit-level=high bloqueia publicação até análise e correção. A tela ainda não foi publicada nem testada com OTP real; não equivale à integração do Flutter. O fluxo nativo Android e o fluxo Flutter Web ainda precisam de implementação e validação de sessão. Não compartilhar senhas/OTP em chats ou logs.
