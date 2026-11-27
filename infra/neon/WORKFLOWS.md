# Dúvidas e aprovação de equipes — migrations 002/003

Branch `infra/neon-duvidas-aprovacao`, dependente de `infra/neon-identidade-rls` (PR #15). A PR deve ter essa branch como base até sua integração. Depois, retarget para main e atualizar o histórico sem reimplementar 001. Os workflows aceitam temporariamente ambas as bases. Nenhuma migration desta entrega foi aplicada no Neon institucional.

## Operações entregues

As interfaces abaixo são **funções SQL seguras**, chamadas futuramente pela API HTTPS autenticada. Não são endpoints publicados, não ativam Neon Auth e não são chamadas diretamente pelo APK. A fronteira de confiança e verificação de token continuam as da [fundação](README.md): backend restrito, contexto issuer/subject derivado de token validado, SET LOCAL e queries parametrizadas. Uma credencial SQL capaz de configurar esse contexto nunca pode ser enviada ao cliente.

| Função em `petita` | Entrada | Resultado / autorização |
|---|---|---|
| `submit_patient_question` | UUID idempotency, UBS, categoria, texto, self_risk_level, array warning_signs, urgency_acknowledged, expected_response_notice_accepted | JSON id/public_code/status; paciente ativo e UBS exatamente igual à do perfil/servidor |
| `list_my_patient_questions` | Limite 1–100, cursor opcional `(before_created,before_id)` | Somente dúvidas/respostas do perfil atual, sem parâmetro patient_id ou busca pública por código |
| `respond_to_patient_question` | Question UUID, texto, UUID idempotency | JSON id/question_id/status; equipe ativa com vínculo aprovado e UBS da pergunta |
| `decide_team_access_request` | Request UUID, approve boolean | JSON id/status/decided_by/decided_at; admin ativo, proibida autoaprovação |
| `request_ubs_team_access` | UBS solicitada, UUID idempotency | Cria solicitação pendente para a própria identidade; não concede privilégio |
| `list_team_patient_questions` | Limite/cursor | Projeção mínima de pendências da própria UBS, sem patient_id, perfil, email, nome, plano ou vínculo privado |
| `list_team_access_requests` | Limite 1–100 | Fila administrativa pendente, sem confiar em nome/email declarados pelo cliente |
| `revoke_ubs_team_access` | Perfil alvo, motivo de 3–1000 caracteres | Desativa vínculo, preserva aprovação anterior e registra evento com admin/data; não apaga histórico |

Exemplos conceituais com parâmetros vinculados pela API:

```sql
SELECT petita.submit_patient_question($1::uuid,$2,$3,$4,$5,$6::text[],$7,$8);
SELECT * FROM petita.list_my_patient_questions($1,$2::timestamptz,$3::uuid);
SELECT petita.respond_to_patient_question($1::uuid,$2,$3::uuid);
SELECT petita.decide_team_access_request($1::uuid,$2);
```

Essas chamadas devem ocorrer em transações **READ COMMITTED**. Outros níveis de isolamento são rejeitados com SQLSTATE 25000 para não reutilizar snapshots anteriores à revogação. O backend deve traduzir estados de forma segura: 42501→acesso negado, 22023→entrada inválida, P0001/23505→conflito. Não enviar mensagens brutas de SQL, payloads ou detalhes internos ao aplicativo. Transporte HTTPS, JWT/sessões e rotas HTTP permanecem na próxima PR de API/Auth.

## Validação, privacidade e integridade

- Texto da dúvida: 3–1500 caracteres após trim; categoria: 1–120. Risco somente low/medium/high, preservando o contrato existente sem reclassificar clinicamente. Sinais: array unidimensional, até 32 itens não nulos de 1–240 caracteres. Não foi alterado nenhum texto clínico nem catálogo de sinais.
- Ciência da expectativa de resposta é obrigatória. Risco high ou qualquer sinal exige urgência reconhecida. Flags nulas/malformadas são recusadas. Não fabricar aceites a partir de defaults.
- Código público é UUID aleatório com prefixo DUV, único, mas não é credencial. Mesmo conhecendo código ou ID de outra gestante, a leitura depende do vínculo privado atual.
- `patient_questions` não contém patient_id; o vínculo fica em `petita_private.question_patient_links`, inacessível ao runtime/equipe/admin por SQL direto. A fila é pseudonimizada: o texto livre pode identificar alguém, portanto não se promete anonimato irreversível.
- Respostas: 3–6000 caracteres; uma resposta final por pergunta, com autor e data registrados internamente. Não há edição destrutiva de resposta nem alteração de autoria por parâmetros.
- Pedidos profissionais são vinculados ao perfil por contexto, não por email/nome/papel do cliente. A aprovação atribui somente ubs_team e a UBS solicitada validada. Não concede acesso a planos completos. Cadastro de pessoas/equipes e verificação institucional da identidade profissional continuam necessários antes do uso real.

## Idempotência, concorrência e revogação

1. Envios usam chave única por paciente e hash SHA-256 privado do payload normalizado (trim de texto/categoria). Mesma chave e mesmo payload retornam a mesma dúvida; payload diferente produz conflito. Hash privado serve apenas à integridade da repetição, não é alegação de anonimização nem hash de registro INPI.
2. Dúvida, vínculo e evento submitted são criados na mesma transação. Não há INSERT remoto separado a ser feito pelo Flutter. Falha no vínculo ou no histórico reverte a operação inteira.
3. Resposta usa chave única por responsável e chave única de pergunta. Repetir a mesma operação retorna a resposta existente; outro texto/chave/autor para pergunta finalizada conflita. Advisory lock por pergunta serializa escritores; constraints são defesa adicional.
4. Pedido possui idempotência por solicitante e apenas um pedido pending por pessoa. Decisões serializam por ator alvo e bloqueiam a linha pendente. Segunda decisão, mesmo igual, não reaprova nem reabre o pedido. Aprovação/rejeição, vínculo, papel e evento são uma transação única.
5. Escritas usam lock de transação `hashtextextended('petita.actor:'||profile_uuid,0)`. Respostas e revogação usam o mesmo lock da equipe: a revogação espera uma resposta já aceita encerrar; uma resposta em fila, ao obter o lock depois da revogação, revalida e é negada. Depois de confirmado o commit da revogação, novas operações não usam o vínculo anterior, mesmo com token ainda válido.
6. Desativação de perfil ou UBS também é verificada nas consultas. Mudanças administrativas fora dessas funções não devem ignorar a disciplina de locks/contexto da API. Não há promessa de cancelar retroativamente operações confirmadas antes da revogação.

## RLS e roles técnicas

Seis tabelas novas: `petita.patient_questions`, `petita.ubs_answers`, `petita_private.question_patient_links`, `question_events`, `team_access_requests`, `team_access_events`. Todas têm ENABLE/FORCE RLS e FKs RESTRICT, preservando rastreabilidade. Os eventos são append-only para as roles de execução; o runtime não recebe SELECT/INSERT/UPDATE/DELETE nessas tabelas, apenas EXECUTE das oito operações públicas.

`petita_questions_executor` e `petita_access_executor` são NOLOGIN, NOINHERIT, sem superusuário, CREATEROLE, CREATEDB ou BYPASSRLS. Não são proprietárias das tabelas nem membros de outras roles. Só recebem privilégios necessários e policies específicas. O executor de dúvidas não lê perfis/identidades nem planos; helpers da fundação resolvem o ator. O executor de acesso pode modificar somente a coluna role e os campos de vínculo aprovados, sob RLS administrativa; nenhuma função permite promoção a admin. Nenhum executor lê `birth_plans`.

Funções SECURITY DEFINER têm donos técnicos restritos, search_path pg_catalog, referências qualificadas e EXECUTE revogado de PUBLIC. O runtime não pode assumir esses donos por SET ROLE. A migration alterna explicitamente entre roles de schema e authorizer para conceder permissões de helpers; isso foi testado com migrador não superusuário, sem recorrer ao owner para simular usuário final.

## Testes e reprodução

```bash
python3 tools/check_frozen_questionnaire.py
python3 tools/test_neon_foundation.py
python3 tools/test_neon_workflows.py
flutter analyze --no-pub
flutter test --no-pub
```

Containers descartáveis separados, PostgreSQL 17.6 por digest já fixado na fundação, sem rede/portas/mounts ou URL de banco, somente fixtures sintéticas. Setup administrativo cria dados; operações reais são exercitadas por login comum membro apenas de petita_runtime, sem owner/superuser/BYPASSRLS. O institucional informa 17.11; executar também em homologação Neon antes de promoção. Não foi acessado nenhum dado de paciente ou escrita institucional nesta execução.

Resultado local: **22 testes de fundação + 30 cenários novos**, além dos **79 testes Flutter** e análise estática aprovados. A nova suíte inclui duas gestantes/UBS, equipes aprovadas/não aprovadas/inativas, admins/autoaprovação, inputs/avisos, código público/IDs adulterados, escopo privado, idempotência e payload conflitante, decisões repetidas, paginação, revogação de vínculo/perfil/UBS, resposta/decisão simultâneas em conexões distintas, envio concorrente, encerramento real de conexão antes do commit, falha injetada no vínculo e no evento de resposta, rollback explícito e rollback/reaplicação vazios. Isolamento de snapshot incompatível é rejeitado.

Os 22 testes originais continuam em banco só com 001; a nova suíte compartilha apenas o bootstrap de fixtures e aplica 002/003 em outro container. O CI preserva ambas, mais Flutter/Web e hash byte a byte das 31 perguntas. O código Flutter não é alterado nesta PR.

## Rollback e atualização da base

- 003 down exige histórico exato 1,2,3 e nenhuma solicitação/evento de acesso. 002 down exige 1,2 e nenhuma dúvida/vínculo/resposta/evento. Ordem: 003 antes de 002. Sem CASCADE, exclusão de dados ou alteração de objetos legados. `row_security=off` impede interpretar linhas ocultas como base vazia.
- Se já houver histórico/dados, rollback destrutivo é recusado; preservar e criar migration corretiva. Roles NOLOGIN ficam no cluster para não afetar outro banco e são reutilizadas somente se atributos/memberships continuarem seguros.
- 001 e os relatórios históricos da PR #15 permanecem intactos. Após merge autorizado da #15, mudar a base da PR dependente para main, verificar merge-base/diff e executar novamente o CI se o código/base tiver mudado. Não executar merge automático.

Pendências separadas: autenticação Neon/HTTP e adapter Flutter, provisionamento da identidade profissional e bootstrap administrativo, migração histórica, rate limits da API, consentimentos versionados, criptografia local e sync seguro. Nenhum desses itens é declarado homologado por testes SQL.
