# Implementação institucional — 26/11/2026
Base confirmada: feat/neon-enrollment-20261126 @fc554711, sem commit posterior ao início. Main atual3a09378; PRs15/17/24–28 abertas. PR28 já contém migrations001–005, transportes e backend; telas Flutter ainda apontavam ao Supabase legado.

Marco1: reaproveitadas correções de persistência/feedback/PDF/RAG da PR24 e manifesto Web/iOS da PR25, sem merge na main e sem refazer componentes. Lockfile npm gerado;17 testes Node passaram e npm audit retornou0 vulnerabilidades. Questionário SHA9dbc0ceebb6b507df1c5d15a812ddbb689fe2935e4ba8c8e9637f8de0d4678dd preservado.

Neon: acesso de leitura confirmado a round-cherry-59699884 /br-purple-surf-b6k7zrka, homologação pronta. Email/password+OTP já ativos. A origem Flutter não está autorizada; não alterar configuração sensível nem solicitar OTP/credenciais pelo chat. Vercel API existente foi identificado; não criar paralelo nem fazer deploy da tela bloqueada. vercel.json passa a desativar Git deployments nesta candidata, conforme contrato Vercel, para evitar publicar autenticação ao enviar commits.

Próximo: integração real Flutter/Auth e controlador de consentimento/sincronização/revisões com testes in-memory explícitos. Nenhum teste positivo com OTP real realizado. Não declarar candidata aprovada para produção.
