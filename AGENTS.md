# AGENTS.md — Petita / auditoria final controlada

Este repositório contém a **Petita**, aplicativo Flutter de Plano de Parto para o PET Saúde/UFCG. Sua finalidade é educativa; informações relacionadas à gestação são sensíveis. **Prioridade:** segurança e privacidade > integridade de dados > confiabilidade e acessibilidade > desempenho > mudanças estéticas. Não adicione funcionalidades novas durante a auditoria sem necessidade demonstrada.

## Missão atual
Ler `auditoria-final/PLANO_MESTRE.md` e `auditoria-final/PROMPTS_CODEX.md`. Há duas janelas planejadas, com controle em `auditoria-final/PROGRESSO.md`. Painel GitHub: issue #21; janela A issue #22; janela B issue #23.
A auditoria **não está concluída por haver este arquivo**. Inspecione o código, reproduza as hipóteses, corrija apenas achados comprovados e registre resultados verificáveis.

## Limites inegociáveis
1. Trabalhar somente na branch de auditoria ou em sub-branches dela. Abrir PRs pequenas; **não alterar diretamente `main`**, não fazer merge sem revisão, não publicar APK/Web/Play Store, não disparar workflows de release.
2. **Não acessar nem modificar ambientes reais** Neon/Supabase/Google Cloud, dados reais, pacientes, autenticação produtiva, RLS produtiva, contas, backups ou segredos sem autorização explícita e mecanismo seguro. Testes offline com dados sintéticos e mocks.
3. Não imprimir, copiar, commitar ou expor chaves, tokens, senhas, keystores, arquivos `.env`, sessões, CPF/e-mail/identidade de gestantes. Se detectar possível vazamento: descreva **tipo e caminho**, não o valor; proponha rotação segura.
4. `assets/data/birth_plan_flow.json`: **31 perguntas e textos canônicos imutáveis byte a byte**, salvo autorização separada. Registrar SHA-256 antes/depois. Não modificar orientações médicas, termos, política de privacidade ou textos de urgência sem revisão especializada.
5. As perguntas reservadas para consulta permanecem sem resposta até decisão da gestante; notas são offline; dúvidas online devem obedecer à UBS designada, permanecer anônimas para a equipe, sem expectativa ou obrigação de resposta, com alerta de urgência. Não confundir anonimato para profissionais com ausência de identidade no servidor.
6. Preservar compatibilidade de dados locais, especialmente `SharedPreferences`, consentimentos, PDF de uma página na declaração e compatibilidade com versões Android previamente instaladas. Se alteração requer migração de dados ou assinatura, registrar como bloqueio.
7. Diferenciar estado real e intenção: o código de produção ainda inicializa `supabase_flutter`, enquanto o Neon é o destino planejado/ativado para Auth e dados. **Não afirmar que o login Google/Neon funciona antes de prova ponta-a-ponta.**
8. Nunca declarar "seguro", "LGPD conforme" ou "pronto para uso assistencial" apenas por testes automatizados. Relatar limite de cobertura e riscos residuais.

## Ciclo de trabalho obrigatório
- Antes: registrar em `auditoria-final/PROGRESSO.md` o baseline (branch, commit, comando, escopo).
- Para cada marco: (a) investigar (b) listar arquivos e evidências reproduzíveis (c) realizar mudança mínima, caso autorizada (d) executar teste relevante (e) atualizar **imediatamente** PROGRESSO, criar commit/PR, e comentar no issue #21 se houver permissão. Não aguardar o fim da janela para informar.
- Cada atualização deve conter: `Marco [ID] | status | evidência | teste | próximo passo | bloqueio`. Atualizações úteis por conclusão de subetapa, não por cada linha lida.
- Antes de qualquer limite, interrupção ou final de turno, deixar **HANDOFF**: último commit, alterações não commitadas, riscos P0/P1, testes executados, pendências e primeira ação exata na retomada. Se a limitação chegar abruptamente, checkpoints anteriores preservam o estado.
- Não inventar testes, tempos, medição de APK nem evidências. Classificar hipóteses como "não verificado" até reproduzir. No final, declarar `GO / GO-COM-RESSALVAS / NO-GO` por funcionalidade e globalmente, sujeito a revisão humana.

## Comandos base (preferir o CI existente)
```bash
flutter --version
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
# Flutter Web quando apropriado:
flutter build web --release --no-wasm-dry-run --no-pub
```
O Android é gerado nos workflows; não assumir que a pasta `android/` existe no checkout. Para teste local, seguir `.github/workflows/validar_apk_tts.yml`. Use compilação `--debug` não publicada. Evite remover `test/`, snapshots ou arquivos de evidência para fazer o CI passar.

## Relatório de severidade
- **P0**: acesso indevido a dados de saúde, exposição de segredos, privilégio administrativo sem servidor, vazamento entre UBS, perda irrecuperável silenciosa, orientação de urgência insegura.
- **P1**: falha funcional relevante, falha offline, perda de dado após upgrade, quebra de PDF, falha persistente/performance degradada.
- **P2**: UX, acessibilidade, otimização de custo/latência, documentação ou manutenção sem risco imediato.
Cada achado: ID, requisito, risco, `arquivo:linha`, reprodução, evidência, correção, teste e risco residual.

## Registro de software
Ao congelar o conteúdo, registrar commit, conjunto representativo de arquivos, hash SHA-256 do **arquivo efetivamente entregue**, dependências/licenças, autoria e changelog. Não modificar artefato depois de calcular hash nem afirmar que o registro implica homologação clínica. Sem upload ao NITT/INPI sem aprovação explícita.
