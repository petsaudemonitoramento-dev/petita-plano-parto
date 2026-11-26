# Petita — regras permanentes para agentes Codex

Projeto: Flutter Android/Web, plano de parto e orientação educativa; dados sobre gestação são sensíveis. Fonte canônica: petsaudemonitoramento-dev/petita-plano-parto. Auditoria final: issue #21, etapas #22/#23, branch audit/codex-final-petita-20261104, plano em auditoria-final/PLANO_MESTRE.md.

## Execução estritamente remota
- **Codex Cloud no ambiente publicado. Nunca usar computador/IDE/VS Code/terminal/ADB local do usuário.** Se faltar ferramenta, usar apenas o ambiente Cloud ou **GitHub Actions**; se ambos falharem, registrar bloqueio, continuar com análise estática e não solicitar PC local.
- Não refazer o aplicativo nem criar recursos novos. Ordem: **segurança e privacidade > integridade offline > correção > acessibilidade > desempenho > manutenção**.
- Evitar respostas intermináveis e releitura integral dos mesmos arquivos. Fazer inspeção dirigida, buscas seletivas e pequenos patches. Um problema por commit/PR.

## Limites de segurança
- Somente branch de auditoria/PR. **Sem push na main, merge, releases, publicação de APK/site ou operação em banco/contas de produção.**
- Usar apenas fixtures fictícias e mocks para fluxos que envolvam gestantes/UBS; não conectar Neon/Supabase/Google produtivos sem autorização separada. Não registrar, exibir ou copiar chaves privadas, senhas, tokens, sessões, respostas reais ou PII; achou exposição? Indicar caminho/tipo, não valor.
- O arquivo assets/data/birth_plan_flow.json (31 perguntas) é imutável byte a byte. Registrar SHA-256 inicial e final. Proteger avisos de urgência, direito de não responder, consentimentos e políticas; textos clínicos só mudam com revisão humana.
- Isolamento entre UBS, anonimato perante profissionais, autorização admin **do lado servidor**, dúvidas urgentes direcionadas à unidade/serviço de saúde e ausência de obrigação de resposta são invariantes. Dúvidas para consulta permanecem offline e **não equivalem a respostas**.
- A arquitetura Flutter ainda usa supabase_flutter; Neon foi provisionado separadamente. **Não alegar migração/login Google concluídos** nem criar autenticação improvisada.
- Preservar dados de instalações anteriores, geração de PDF e acessibilidade de cards. APK antigo pode ter assinatura diferente: tratar upgrade como risco, não recomendar desinstalação automática.
- Nenhum CI verde prova LGPD/segurança remota/homologação clínica. Distinguir **confirmado / suspeito / não testado**.

## Anti-travamento obrigatório
- Use preferencialmente o executor versionado: bash tool/run_bounded_audit.sh NOME SEGUNDOS comando argumentos. Ele mata testes pendurados, limita saída e guarda log em /tmp (não commitar logs). Ex.: bash tool/run_bounded_audit.sh tests 480 flutter test --no-pub.
- Cada comando externo potencialmente lento deve ter limite de execução (timeout -k 15s SEGUNDOS comando, quando disponível). Ex.: dependências 300 s; teste focado 120–180 s; suíte 480 s; build 900 s. Reduza ainda mais quando não houver progresso.
- **Um teste pendurado nunca pode monopolizar a tarefa.** Interromper, coletar trecho útil do log e classificar como TIMEOUT/BLOQUEADO. Retentar **uma vez somente** se houver correção concreta e limitada; depois continuar a próxima prioridade.
- Nunca usar loops de polling infinitos, sleep longo, espera sem deadline, download sem limites, nem ficar repetindo o mesmo comando com o mesmo erro. Não esconder testes falhos nem remover cobertura só para gerar verde.
- Primeiro testar o escopo modificado; suíte completa e build no gate final. Se faltar Flutter/Android no Cloud, usar CI remoto existente; não gastar a franquia com instalação repetida de SDK.
- Se um comando não produzir saída, observar apenas até seu prazo explícito; registrar estado e migrar de tarefa. Nunca depender de retorno de uma ferramenta específica para continuar toda a auditoria.

## Checkpoints recuperáveis
- Ao iniciar: branch, commit, estado do repo, hash do questionário, próximos 2 marcos.
- Depois de cada marco útil **e sempre após encontrar P0**: atualizar auditoria-final/PROGRESSO.md + ACHADOS.md; commit; comentário no issue #21 se a conexão permitir. Mensagem: [marco] feito / teste e resultado / risco / próximo / bloqueio.
- Antes de interrupção: HANDOFF contendo branch, último SHA, testes e comandos **com duração/resultado**, alterações não commitadas, achados e **primeiro comando da retomada**. Commits importam mais que memória do chat; nunca presumir persistência de workspace.
- Entrega final: auditoria-final/PARECER_FINAL.md com **GO / GO COM RESSALVAS / NO-GO** e evidências/limites. Rastreabilidade do registro: commit congelado e SHA-256 **do pacote exatamente submetido**; sem submissão ao NITT/INPI sem autorização.

Leia o plano mestre apenas para o marco em execução; o prompt específico da janela está em auditoria-final/PROMPTS_CODEX.md.