# Backend de homologacao — Petita (Neon Auth + UBS)

**Nao publicado. Nao utilizar com dados reais.** O APK publico e o site de download nao foram modificados.

## Objetivo

API HTTPS isolada para duvidas educativas **nao urgentes**, vinculadas exclusivamente a uma UBS. Gestantes se autenticam pelo Neon Managed Better Auth (Google, quando configurado) e recebem o proprio historico; profissionais aprovados consultam somente a fila anonimizada de sua UBS; administradores tratam acessos e metricas agregadas.

Nao confundir esta API com Neon Auth: ativar OAuth no Neon nao habilita automaticamente login no Flutter. E necessario implementar retorno seguro do navegador ao Android e obtencao do JWT Neon; nao passar tokens em query strings nem usar token Google como se fosse Neon JWT.

## Infraestrutura gratuita de homologacao

Implantar como **projeto Vercel separado**, com Root Directory `backend`, vinculado ao repositorio da Petita. Nao adicionar as rotas ao site publico `petita-download` nem expor a `DATABASE_URL`. Variaveis **somente server-side**:

- `DATABASE_URL`: conexao PostgreSQL do Neon da branch de homologacao, role de banco restrita a esse projeto (preferencialmente dedicada).
- `NEON_AUTH_BASE_URL`: URL completa do Neon Auth dessa branch, **incluindo** `/neondb/auth`.
- `NEON_AUTH_JWKS_URL`: JWKS correspondente a mesma branch.
- `PETITA_WEB_ORIGIN` (opcional): origem HTTPS exata da futura UI Web autorizada para CORS.

Este backend nao requer credenciais Google Cloud ou Client Secret no Node: tais credenciais pertencem **ao Neon Auth**. O Google OAuth de producao ainda depende de configuracao humana no Google Cloud e do retorno validado no Flutter.

## Modelo e niveis de acesso

- `petita_atendimento.duvidas` **nao contem** identidade da gestante.
- `petita_privado.autoria_duvidas` associa cada duvida a um usuario Neon e fica inacessivel a equipes; API `GET /api/questions/mine` faz a consulta privada.
- `petita_privado.vinculos_gestantes` e `petita_privado.solicitacoes_vinculo_gestantes`: gestante solicita uma UBS; administrador valida o vinculo por procedimento institucional antes do envio.
- `petita_atendimento.vinculos_equipes`: um profissional, uma UBS, acesso aprovado e revogavel; sem listagem de perguntas de outras UBS.
- `petita_atendimento.acessos`: papeis `gestante`, `equipe_ubs`, `administrador`. O servidor cria automaticamente somente papel `gestante` para usuario Neon validado.
- Admin **nao possui endpoint que recupere as perguntas individuais ou a autoria**. Enxerga pedidos e indicadores agregados.

**Bootstrap admin:** apos login Google validado, um responsavel tecnico autorizado deve identificar o UUID Neon exato daquela conta e promove-la de forma auditavel no banco; nao se promove por dominio de e-mail ou por um atributo de requisicao. Nao criar admin ficticio em producao.

## Endpoints e controles

`GET /api/health`, `GET /api/ubs` sao publicos. Demais endpoints exigem Bearer JWT Neon com assinatura EdDSA verificada por JWKS, emissor e expiracao, seguidos de papel e vinculo ativos consultados no servidor.

| Metodo e rota | Autorizacao |
| --- | --- |
| `GET /api/me` | sessao Neon, retorna apenas papel/UBS |
| `POST /api/patient/ubs-request` | gestante, pede vinculo |
| `POST /api/questions` | gestante, UBS confirmada, quatro aceites e sem sinais de alerta |
| `GET /api/questions/mine` | gestante, somente autoria privada da propria conta |
| `POST /api/team/access-request` | solicita acesso sem conceder papel automaticamente |
| `GET /api/team/queue` | equipe ativa, filtro UBS **exclusivamente do banco** |
| `POST /api/team/questions/:id/answer` | equipe da UBS da duvida; resposta facultativa |
| `POST /api/team/questions/:id/close` | equipe da UBS; encerra sem resposta |
| `GET /api/admin/requests` | admin, solicitacoes das equipes e gestantes |
| `POST /api/admin/team-requests/:id/approve|reject` | admin, aplica/rejeita acesso profissional |
| `POST /api/admin/patient-ubs-requests/:id/approve|reject` | admin, confirma/rejeita UBS |
| `POST /api/admin/team/disable` | admin, revoga equipe |
| `GET /api/admin/overview` | admin, somente contagens por UBS |

O endpoint de envio **ignora qualquer UBS enviada no corpo**: a unidade e lida de `vinculos_gestantes`. Dados cadastrais nao aparecem no DTO de fila. A mensagem livre pode se autoidentificar; UI e API avisam e barram indicadores obvios, nao prometem anonimato absoluto.

## Testes e limites

CI `Validar API Petita Neon (sem deploy)` roda testes de papel, UBS, quatro consentimentos, urgencia e sintaxe, sem segredos ou acesso ao banco.

**Pendentes antes de deploy e testes reais:** validar `neon(...).transaction()` e consultas na branch de homologacao, JWT real emitido pelo Neon, criacao de usuario apos login Google, concorrencia (resposta/encerramento), 401/403 entre UBS, rejeicao de content com PII, sessions/logout, falhas de rede, clinica/legal, protecao LGPD e propagacao da revogacao. A ausencia dessas evidencias impede publicacao.

A politica institucional deve definir quem confere a UBS da gestante e quem valida solicitacoes de profissionais. Este canal facultativo nao altera deveres assistenciais de um profissional na UBS fora do aplicativo.

Consultar `../documentos/FLUXO_DUVIDAS_NEON_2026_10.md` para roteiro completo.
