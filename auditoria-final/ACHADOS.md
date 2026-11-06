# Achados técnicos — auditoria final Petita

**Estado em 2026-11-06 / A0:** 22 testes existentes de storage/recuperação/consentimento aprovados (4s, wrapper 180s). Hipóteses de backend ainda em investigação. Nenhum resultado de mock comprova configuração implantada.

## Achados comprovados na retomada (2026-11-06)

### SEC-01 — P0 condicional: administrador inativo alcança operações privilegiadas
- CONFIRMADO no código executado com fixtures: handlers delete-support-document/index.ts:33–34 e process-support-document/index.ts:37–41 selecionavam somente role, ignorando active. Sessão válida e perfil legível com role=admin/active=false obtinham 200 (remoção) e 202 (processamento), com criação de cliente service-role. Permite alterar/remover base educativa após desativação da conta, se perfil continuar legível e sessão válida.
- Impacto e condição: autorização sensível contornada no handler. Visibilidade real do perfil inativo/RLS e validade de sessão no ambiente implantado NÃO VERIFICADAS; não afirmar exploração produtiva. Teste não simula banco nem valida tokens criptográficos.
- Reprodução antes: wrapper edge-authorization-before 60, Node 24.19.0, --experimental-vm-modules --test-isolation=none --test --test-name-pattern='inactive admin' tool/test_edge_security.mjs: **2 falhas**, 200/202 em vez de 403, <1s.
- CORRIGIDO somente na branch: selecionar role, active e exigir active===true antes do cliente privilegiado. Ausente/null também negados. Chamada interna service-role do processador mantém contrato existente, ainda exige credencial de servidor (não testada aqui).
- Depois: wrapper edge-after 60, **24 testes aprovados, 1s**; pacientes/equipes A e B/metadados adulterados/admins inativos negados sem efeitos privilegiados. Admin ativo preservado. Sem deploy: instância remota permanece não verificada.

### SEC-02 — P1: RAG publicável aciona provedor sem identidade/limite no handler
- CONFIRMADO em ask-petita-rag/index.ts:17–27 e config.toml:5: apenas apikey é verificada. Fixture com chave pública e nenhum Authorization faz três chamadas aceitas, três embeddings e zero verificações de usuário. Entrada sintética enviada ao fetch externo simulado.
- Limites: chave pública não é segredo; endpoint educativo público pode ser intencional. Falta de quota no handler permite abuso de custo e transmissão não autenticada; WAF/quota externos NÃO VERIFICADOS. Não provado vazamento de documentos privados nem de pacientes.
- Teste de caracterização no arquivo Edge aprovado confirma o risco presente; não é gate que prova correção. Falta/wrong key e questão >1500 não acionam provedor.
- Janela B: definir política público/autenticado e quota persistente adequada; testar abuso com fixtures. Não improvisar login nem alterar textos clínicos.

### SEC-03 — P1: diagnóstico interno retornado no RAG
- CONFIRMADO em ask-petita-rag/index.ts:65–66,174–175: falha sintética de fetch retorna mensagem interna no JSON ao chamador, status 200. Teste injeta fixture-internal-diagnostic e detecta marcador sem copiar dados reais.
- Risco: detalhes de provedor/configuração podem chegar ao cliente; nenhum segredo real exposto no teste. Janela B: erro público genérico, telemetria mínima sem payload, regressão negativa. Caracterização atual permanece explicitamente nomeada.

## Escopo dos testes de handlers
Node executa TypeScript real com remoção de tipos via stripTypeScriptTypes e VM; apenas import do SDK, Deno.env/serve, fetch e storage são mocks. Nenhum request sai da VM. Node test runner em subprocesso foi bloqueado pelo sandbox; única retentativa em processo (--test-isolation=none) resolveu. Um ajuste do assert de erro acomodou prefixo Error: entre realms; não foi retentativa de erro do produto. Parsing/embedding de arquivos, gateway JWT e RLS do banco não estão simulados como prova de segurança.

## Severidade e evidência
- **P0:** exposição de dados/credenciais, acesso indevido, privilégio indevido, quebra de isolamento entre UBS, perda irrecuperável de dados, orientação clínica perigosa.
- **P1:** falha funcional importante, regressão offline, PDF inválido ou lento em nível impeditivo, upgrade com perda de dados.
- **P2:** manutenção, documentação, UX/acessibilidade ou desempenho sem dano imediato comprovado.
- **OBS/UNKNOWN:** hipótese ainda não confirmada, não deve receber selo "corrigido".

| ID | Severidade | Status | Evidência `arquivo:linha` | Como reproduzir | Impacto | Correção proposta | Teste antes/depois | Risco residual |
|---|---|---|---|---|---|---|---|---|
| INSP-01 | UNKNOWN | A INVESTIGAR | `lib/main.dart`; `lib/config/supabase_config.dart` | Revisar caminho de inicialização e autenticação contra arquitetura Neon planejada | Possível divergência funcional/backend | Documentar e propor migração segura somente em ambiente de teste | Pendente | Pendente |
| INSP-02 | UNKNOWN | A INVESTIGAR | `lib/services/storage_service.dart` | Localizar dados de saúde persistidos e mecanismo do SO/backup | Confidencialidade e persistência | Modelo de ameaças e avaliação de storage mais adequado | Pendente | Pendente |
| INSP-03 | UNKNOWN | A INVESTIGAR | `supabase/config.toml` e `supabase/functions/ask-petita-rag/index.ts` | Checar autenticação efetiva, abusos e limites | Custo e uso indevido | Endurecimento condicionado a evidências | Pendente | Pendente |
| INSP-04 | UNKNOWN | A INVESTIGAR | `lib/screens/admin/`; `lib/screens/ubs/`; SQL/RPCs | Acesso por perfis fictícios A/B/gestante/admin | Privacidade/segregação | Padrões de autorização no servidor e testes negativos | Pendente | Pendente |
| INSP-05 | P2 potencial | A INVESTIGAR | `README.md`; `lib/config/app_info.dart` | Comparar versão exibida com pubspec | Documentação equivocada | Atualizar apenas após confirmação | Pendente | Pendente |
| INSP-06 | UNKNOWN | A INVESTIGAR | `.github/workflows/publicar_apk_petita_v030.yml` | Revisar certificados, segredos e upgrade sem acessar valores | Distribuição segura e continuidade | Processo de assinatura reproduzível com chave protegida/rotacionada | Pendente | Pendente |

## Regras para editar este relatório
1. Adicionar linha por achado confirmado; não misturar múltiplos riscos em um único ID.
2. Evitar copiar PII, tokens, chaves privadas, sessões ou respostas reais. Para exemplo, dados fictícios.
3. Toda falha confirmada deve ter caso mínimo reprodutível, impacto e fix localizado ou bloqueio explícito.
4. Um CI verde não prova segurança de backend real. Separar inspeção estática de teste com permissão controlada.
5. Não classificar como P0 por ansiedade: demonstrar cenário plausível de dano e as condições necessárias.
6. Registrar quando um risco não pode ser testado na nuvem ou sem Android real: `NÃO VERIFICADO` + teste manual sugerido.
