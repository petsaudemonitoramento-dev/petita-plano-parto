# API institucional Neon — homologação

Estado vigente: fonte `89aa160` da PR28, implementação Flutter em `lib/services/institutional` e telas em `lib/screens/institutional`. Entrega, evidências, instalação e bloqueios em [ENTREGA_RC_INSTITUCIONAL_20261126.md](../documentos/ENTREGA_RC_INSTITUCIONAL_20261126.md). **NO-GO para produção/assistência.** As referências anteriores à ausência de cadastro, consentimento, planos e adaptador Flutter foram superadas no fonte; integração real continua não homologada.

Reutiliza os schemas canônicos `petita`/`petita_private` e migrations001–006. Nenhuma migração deste checkpoint foi aplicada remotamente. Não utiliza schemas alternativos da PR19. Cadastro explícito cria somente patient, identidade do JWT verificado, sem papel/UBS escolhidos pelo cliente. Equipe/admin e vínculos dependem das funções autorizadoras no banco; admin inicial só por processo institucional externo.

JWT EdDSA, issuer/audience da origem Auth (sem caminho), exp/iat/sub, e-mail verificado e conta não banida. Estado da conta/perfil/vínculo é consultado por transação READ COMMITTED. Login dedicado, TLS verify-full, petita_runtime sem owner/BYPASSRLS/CREATEROLE/CREATEDB; queries parametrizadas e falha fechada. JWT emitido pode persistir até expiração: não afirmar revogação individual imediata em logout.

Configuração do backend: `PETITA_MODE=homologacao`, `DATABASE_URL` do login dedicado, `PETITA_DB_LOGIN`, `NEON_AUTH_BASE_URL`, `NEON_AUTH_JWKS_URL`, `PETITA_WEB_ORIGIN` exata. Não colocar credenciais em Flutter. `.git.deploymentEnabled=false` preserva bloqueio de publicação da autenticação. SSO Vercel=all/origens Auth ainda exigem resolução institucional; não usar bypass token no app. Node CI/engines22, projeto Vercel informado26: reconciliar antes de publicação autorizada.

Rotas: `/api/profile`, `/api/me`, `/api/consent`, `/api/consent/withdraw`, `/api/plans`, catálogo UBS, dúvidas do titular, fila profissional, solicitação/aprovação/revogação profissional, solicitação/aprovação/revogação de vínculo gestante/UBS. Identidade/papel nunca vêm do corpo. Envelope `{data:[...]}`, erros sanitizados; `/api/health` não verifica banco. Corpo16KiB/respostas do plano12KiB, revisão esperada e409 em conflito. Consentimento append-only e RLS restritiva bloqueiam gravação incompatível. Leitura dos próprios planos continua após retirada para preservar direito de acesso.

Sem SQL genérico, fallback legado, RAG/documentos assistenciais, endpoint de elevação de privilégios ou bootstrap administrativo pelo cliente. Rate limiting persistente geral, eliminação remota completa e revisão LGPD continuam pendentes.

No Codex Cloud, na raiz:

```sh
bash tool/run_bounded_audit.sh npm-ci 180 npm ci --prefix backend --ignore-scripts
bash tool/run_bounded_audit.sh api-tests 180 npm test --prefix backend
bash tool/run_bounded_audit.sh auth-web 180 npm run --prefix backend build:flutter-auth
bash tool/run_bounded_audit.sh deps 180 npm audit --prefix backend --audit-level=high
bash tool/run_bounded_audit.sh postgres 180 python3 tools/test_neon_patient_ubs.py
```

SDK oficial `@neon/auth`0.8.2, lockfile versionado; bundle local gerado antes do build Web. Testes JWT assinados com chaves fictícias e PostgreSQL real descartável/Auth fictício não comprovam OTP/JWT/RLS na infraestrutura real. A tela antiga auth-preview também continua sem autorização de deployment. Main, produção e dados existentes não foram alterados.
