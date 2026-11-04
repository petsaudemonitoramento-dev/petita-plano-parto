# Prompts Codex Cloud v2 — Petita, auditoria final em duas janelas

Repositório: petsaudemonitoramento-dev/petita-plano-parto
Branch: audit/codex-final-petita-20261104
Acompanhamento: https://github.com/petsaudemonitoramento-dev/petita-plano-parto/issues/21
Janela A: issue #22; Janela B: issue #23.

Escolher o **ambiente publicado do Codex Cloud** da Petita; não o modo local/Remote Control. Uma franquia de cinco horas não garante cinco horas de execução; a prioridade é deixar resultados úteis e checkpoints frequentes. Preferir **continuar a mesma tarefa** e commits salvos ao usar outra janela de franquia. Não reproduzir tudo na segunda.

---

## PROMPT A — PRIMEIRA JANELA (colar integralmente no Codex Cloud)

Você é o auditor técnico sênior responsável pela última revisão do software **Petita** (Flutter Android/Web) antes de congelarmos a versão de código para encaminhamento ao NITT/INPI. Sua missão é **produzir o máximo de segurança comprovável e resultados verificáveis dentro da franquia**, não fazer uma refatoração geral, nem apenas dar opiniões.

**Execução:** SOMENTE Codex Cloud, ambiente publicado, repositório petsaudemonitoramento-dev/petita-plano-parto, branch audit/codex-final-petita-20261104. NÃO usar meu PC, VS Code local, emulador local, ADB local ou solicitar que eu ligue máquina. Você pode usar a VM do Codex e GitHub Actions em nuvem para testes. Se falta ferramenta, passe a outra tarefa útil e registre bloqueio; não transfira trabalho ao meu computador.

### Contrato de trabalho
1. Leia AGENTS.md e apenas as seções necessárias de auditoria-final/PLANO_MESTRE.md, PROGRESSO.md e ACHADOS.md. Confirme branch, HEAD, estado git e versão. Primeiro checkpoint: A0 com base e SHA-256 do questionário de 31 perguntas.
2. **Prioridade máxima — revisar ameaças reais**: autenticação/controle de permissões (gestante, equipe de uma UBS, admin), RLS e RPC, Edge Functions/RAG, isolamento UBS A versus B, anonimização de dúvidas, uploads, segredos, privacidade, consentimentos, exclusão e proteção de dados locais. Avalie **código de fato executável**. Atenção: o Flutter ainda inicializa Supabase legado; Neon/Auth planejado não equivale a login Google integrado. Identifique fluxos quebrados, não presuma que estão funcionais. Se não puder validar backend sem produção, marque NÃO VERIFICADO e proponha testes isolados — não invente resultados.
3. **Segundo foco — integridade offline**: retomar plano, persistência, 31 perguntas imutáveis, dúvidas reservadas para consulta sem resposta fictícia, PDF completo e declaração, anotações, teclado, rolagem para próximo card, escolha “Escrever minha resposta”, vozes locais e comportamento sem TTS, perda de conexão, recuperação após fechamento, telas pequenas e fontes maiores.
4. **Terceiro foco — qualidade técnica e supply chain**: dependências e licenças, permissões Android, arquitetura, tratamento de erros, logs de dados sensíveis, concorrência, scripts de CI/release, assinatura persistente, risco de atualização entre certificados. Prefira detectar e comprovar falhas P0/P1 antes de otimizar estética.
5. Para cada achado, registrar ID, impacto real, severidade P0/P1/P2, caminho/linha, passos com dados fictícios, evidência, hipótese versus confirmado, correção sugerida e teste de regressão. Se uma correção P0 simples for possível com segurança, implemente patch mínimo em branch/PR própria e teste; demais correções passam à Janela B.

### Protocolo ANTI-TRAVAMENTO (obrigatório)
- Toda execução com chance de bloquear tem deadline externo. Em Linux, use o comando timeout e limites orientativos: instalação/resolução de dependências até 300 s; teste focado 120–180 s; suíte completa até 480 s; build até 900 s. Nunca rodar espera infinita ou polling sem limite.
- Quando o comando não retorna ou excede o limite: encerrar processo, guardar as últimas linhas úteis de log, registrar TIMEOUT com comando/ambiente e **avançar imediatamente para outra prioridade**. UMA retentativa apenas se houver mudança concreta que possa resolver. Não consumir a janela tentando repetidamente instalar Flutter, abrir simulador ou executar o mesmo teste.
- Se o ambiente Cloud não tiver Android/Flutter adequado, usar somente workflows GitHub Actions que não publicam APK, com timeout. Se a rede impedir isso, manter auditoria estática. Nunca exigir meu computador.
- Teste que falha ou expira não é “aprovado”. Não esconder falhas, não eliminar testes para forçar verde e não fazer deploy para “ver se funciona”.
- Faça inspeções dirigidas e correções cirúrgicas; economize contexto e execuções. Só execute suíte inteira no gate adequado, não após cada pequeno ajuste.

### Atualização contínua — NÃO esperar terminar a janela
Concluiu um marco ou encontrou bloqueio grave? Atualize IMEDIATAMENTE auditoria-final/PROGRESSO.md e ACHADOS.md, faça commit e publique comentário curto na issue #21 se tiver acesso GitHub. Formato: [A0/A1/A2/A3/A4] FEITO/BLOQUEADO | evidência e comando | testes e resultados | riscos | próxima ação. Faça checkpoint também antes de partir para uma tarefa longa. NÃO prometa trabalho posterior sem registrá-lo em commit.

### Definição de entrega da Janela A
- Mapa de arquitetura e dados confiável; ranking dos riscos; regressões reproduzidas; testes executados com limites e resultado.
- Evidências em PROGRESSO.md, ACHADOS.md e commits/PRs pequenos. Nenhum acesso a dados reais.
- HANDOFF muito claro para Janela B: último commit/branch, o que foi corrigido, o que NÃO foi testado, 3 riscos mais urgentes, comandos de reprodução e **primeira ação concreta para retomar**.
- Se o limite se aproximar, encerre análise nova e salve HANDOFF. Uma entrega parcial verificável é melhor do que auditoria extensa não salva.
- NÃO alterar main, publicar APK/site, migrar banco produtivo, enviar dados ao NITT/INPI nem mudar conteúdo clínico. Nenhuma afirmação absoluta de segurança ou conformidade LGPD.

---

## PROMPT B — SEGUNDA JANELA (colar ao retomar após Janela A)

Continue a auditoria da Petita **do último checkpoint, sem reiniciar do zero**. Use somente o ambiente Codex Cloud e a branch/PR com os commits da Janela A. **Não use ou solicite meu computador local.** Primeiro leia AGENTS.md e o HANDOFF mais recente de auditoria-final/PROGRESSO.md, depois ACHADOS.md e PROMPTS_CODEX.md. Confira HEAD/branch; se o workspace da tarefa foi recriado, busque os commits remotos antes de agir. Issues #21 e #23.

### Objetivo prioritário
1. Comece pelos P0 comprovados e P1 de maior impacto. Para cada correção: bug reproduzido → teste negativo/falha antes → patch mínimo → teste passando depois → commit/PR separada → atualização imediata do progresso. Não tente migrar todo o backend nem reescrever arquitetura em uma janela. O que depender do serviço produtivo fica como NO-GO/pendência com plano testável.
2. Em seguida, otimize **gargalos medidos**, especialmente tempo para gerar/mostrar PDF, cache de fontes/imagens, navegação dos cards, arranque do app, uso offline, tamanho do APK ARM64 e uso de memória. Meça antes/depois com mesmas fixtures e ambiente; se impossível medir, registre NÃO MEDIDO em vez de prometer melhoria. Evite dependência paga, modelos de voz embutidos ou crescimento desnecessário do APK.
3. Execute regressão e hardening: flutter analyze; testes Flutter (31 perguntas, PDF, UBS, admin, consentimento, offline, acessibilidade); build Android/Web em nuvem ou GitHub Actions **sem publicar**; dependências/licenças, assinatura/versionCode/package ID e risco de perda de dados na atualização. Nunca alterar o questionário JSON, as garantias de privacidade ou textos clínicos sem revisão.
4. Prepare o pacote de evidências para **congelamento do código**: commits, inventário de arquivos, dependências/licenças, mudanças, relatório de testes, limitações e procedimento para gerar hash SHA-256 do **arquivo representativo exato que será enviado**. Não inventar hash, não reutilizar hash antigo e não submeter ao NITT/INPI por conta própria.
5. Produza auditoria-final/PARECER_FINAL.md com GO / GO COM RESSALVAS / NO-GO, por módulo e global, distinguindo: código offline de testes fictícios, funcionalidades online não homologadas, segurança backend e adequação assistencial. Um registro de software não equivale a autorização de uso clínico.

### Anti-travamento e checkpoints
Valem os mesmos limites da Janela A: 300 s dependências, 120–180 s teste focado, 480 s suíte, 900 s build; no máximo uma retentativa justificada. TIMEOUT é bloqueio documentado, não motivo para paralisar o trabalho. Prefira teste focalizado e CI remoto, sem ambiente local. Após cada marco B0–B4, atualizar PROGRESSO.md/ACHADOS.md, fazer commit e comentar #21 se possível. Sempre deixar HANDOFF recuperável antes de interromper; não repetir tarefas já comprovadas.

### Critério de fim
Entregar ao menos: PRs revisáveis, testes/resultados reais, melhorias com métricas, lista de riscos residuais e parecer final. Se houver P0 aberto, resultado necessariamente NO-GO para uso que exponha dados reais, mesmo que o software possa ser documentado para registro. Não publicar APK, modificar produção, fazer merge nem encaminhar material ao NITT/INPI sem minha autorização.

---

## Uso no Codex

1. Iniciar **nova tarefa Codex Cloud**, selecionando o ambiente Petita e branch de auditoria; colar Prompt A.
2. Monitorar issue #21 + arquivo PROGRESSO.md; não é necessário deixar nenhum PC ligado.
3. Na janela seguinte, **continuar a mesma tarefa** se possível ou nova a partir dos commits guardados, colando Prompt B.
4. Para revisar o estado sem desperdiçar uma execução grande, pedir somente: “Mostre o HANDOFF, últimos commits, achados P0/P1 e próxima ação. Não rode testes.”
