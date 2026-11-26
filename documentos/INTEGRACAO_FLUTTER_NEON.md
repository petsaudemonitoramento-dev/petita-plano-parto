# Adaptador Flutter para API Neon — etapa de homologação

O novo NeonApiClient funciona em Android e Web via package:http. Integra o contrato HTTP da PR #26 para catálogo UBS, perfil já vinculado, perguntas e fila, solicitação/aprovação/revogação profissional. Não conecta diretamente ao Postgres. Não embute uma URL de deployment protegido nem aceita origem não HTTPS. O token vem de um provedor autenticado e não é persistido pelo adaptador. Nunca simular sucesso; erros são explicitamente retornados ao chamador. Chaves de idempotência devem ser geradas e conservadas por operação no fluxo da UI.

Ainda não substitui SupabaseService nos widgets nem inicializa Neon Auth. A integração de sessão Neon para Flutter, vinculação segura de identidade e UBS, consentimento, sincronização, armazenamento/RAG, cifragem local e testes em aparelhos são gates separados; não publicar esta branch como migração concluída. O cliente e seus testes são candidatos de integração e não alteram a versão pública.
