# Prompts prontos para o Codex Cloud — Petita

**Como iniciar:** no Codex, escolha o ambiente publicado da Petita e o repositório `petsaudemonitoramento-dev/petita-plano-parto`; use a branch `audit/codex-final-petita-20261104` como base (não `main`). Execute primeiro a **Janela A**. Quando retomar em outra janela de franquia, mantenha a mesma tarefa se possível; caso crie outra, a base deve ser a branch/PR que contém commits e HANDOFF, jamais simplesmente `main`.

**Nota:** a franquia de uso de cinco horas pode acabar antes do tempo; sua disponibilidade depende do saldo do plano. Não podemos agendar duas sessões como se fossem 10 horas garantidas.

**Se o seletor de branch do Codex não aparecer:** na primeira tarefa, peça que ele verifique a branch e execute `git fetch origin audit/codex-final-petita-20261104` seguido de checkout isolado dessa branch. Se o ambiente não permitir checkout/commits, **não trabalhe na `main`**: pare e reporte o bloqueio. Na segunda janela, priorize continuar a mesma tarefa/branch em vez de criar nova do zero.

---

## PROMPT A — janela 1: diagnóstico e segurança

Atue como **auditor de segurança de software de saúde, engenheiro Flutter sênior e revisor de supply chain**, com postura cética e baseada em evidências. Projeto: Petita 0.3.0, `petsaudemonitoramento-dev/petita-plano-parto`, branch de auditoria `audit/codex-final-petita-20261104`. Painel: Issue #21, etapa #22. Meta: auditar software existente antes de congela-lo para registro, evitando novas funcionalidades.

**Primeira ação:** leia `AGENTS.md`, `auditoria-final/PLANO_MESTRE.md`, `auditoria-final/PROGRESSO.md`, `auditoria-final/ACHADOS.md`; verifique `git status`, branch, commit, Flutter e CI. Registre imediatamente marco A0 e publique status no Codex; quando tiver acesso autorizado ao GitHub, publique também no Issue #21. Se não puder comentar, registre via arquivo/commit, sem solicitar credenciais ao usuário.

**Prioridades obrigatórias, nesta ordem:**
1. Faça mapa executável dos dados, autenticação e papéis (gestante/equipe de sua UBS/admin). Inspecione `lib/main.dart`, `SupabaseService`, `SupabaseConfig`, Neon/Auth planejado, `supabase/functions`, SQL/RLS/RPC e permissões da aplicação. Não presuma que Neon migrou o cliente Flutter. Identifique fluxos de alto risco, incluindo acesso cruzado de UBS, identificação indevida de gestantes, bypass de admin e uploads.
2. Identifique superfícies de PII/dados de saúde, armazenamento local e online, consentimento/termos, revogação e exclusão, vazamento de logs, segredos/keystore, autorizações e ataques de entrada. `verify_jwt=false` em endpoint não é automaticamente vulnerabilidade: verifique proteção efetiva e abuso plausível.
3. Faça testes adversariais com **dados sintéticos**: isolamento UBS A/UBS B; gestante A/B; permissões admin; perguntas deixadas em aberto; recuperação offline; PDF com texto longo/acentos; cards e teclado; falhas de rede; regressões de 31 perguntas. Use mocks locais se serviços online não estiverem autorizados. Marque claramente o que ficou sem prova.
4. Execute testes e análise pertinentes; não altere o questionário canônico, conteúdo médico ou production. Ordene achados P0/P1/P2 com reprodução, impacto e evidência `arquivo:linha`, anotando suspeitas como não verificadas.
5. Se houver P0 comprovado com correção local curta e teste reproduzível, prepare um patch isolado com teste que falha antes/passou depois. Não assuma que pode modificar RLS ou banco de produção. Pare antes de qualquer alteração irreversível.

**Relatório contínuo obrigatório:** logo após cada marco (A0–A4) atualize `auditoria-final/PROGRESSO.md` e `ACHADOS.md`, faça commit da documentação e, se a conexão permitir, comente em https://github.com/petsaudemonitoramento-dev/petita-plano-parto/issues/21. Use formato `[A1] feito | evidência | teste | bloqueio | próximo`; não espere o final da janela. Se o tempo/franquia estiver perto do fim, PARE o trabalho grande, finalize HANDOFF em PROGRESSO e deixe a **primeira ação exata da janela B**.

**Critério de saída:** inventário real, threat model, riscos classificados, testes/evidências, branch/commits/PR e HANDOFF. Se não completar tudo, informe explicitamente o alcance. Não publique APK, site, registro no INPI ou dados reais.

---

## PROMPT B — janela 2: correção, desempenho e parecer

Continue a auditoria **sem recomeçar do zero**. Repositório `petsaudemonitoramento-dev/petita-plano-parto`, branch/PR produzida na Janela A; issues #21 e #23. Primeiro leia `AGENTS.md`, `auditoria-final/PLANO_MESTRE.md`, `auditoria-final/ACHADOS.md` e, principalmente, a última seção **HANDOFF** de `auditoria-final/PROGRESSO.md`. Confirme commit/branch e os testes já executados, sem repetir desnecessariamente análises prontas. **Não confunda duas janelas de uso com dez horas garantidas.**

Objetivo: transformar os riscos comprovados em correções pequenas, verificadas e prontas para revisão humana, mantendo a Petita educacional offline-first e as 31 perguntas originais.

**Sequência obrigatória:**
1. Escolha os P0/P1 de maior dano real, explique patch e efeitos colaterais. Execute teste de regressão que demonstra defeito, patch mínimo, teste após patch. Commits/PRs pequenos com evidência; **sem deploy, banco produtivo, Google Cloud, assinatura/secret ou alteração direta na main**.
2. Faça benchmark repetível da geração de PDF (respostas sintéticas curtas e longas), número de páginas, cache, preview/compartilhamento; navegação de cards, uso de memória/cold start quando ferramenta permitir; compare bytes de APK ARM64 (ou classifique como "não medido") e latências online com stubs/mocks. Antes/depois devem ter mesmo dispositivo/ambiente/fixture.
3. Revise dependências, supply chain, permissões Android, RAG/FAQ, privacidade dos logs, fallback offline, consentimento e canais UBS. Cheque com precisão compatibilidade de atualizações Android, packageId, versionCode e assinaturas antigas; qualquer impedimento vira bloqueio explícito.
4. Rode `flutter analyze --no-pub`, `flutter test --no-pub`, build Web e Android debug com pipeline existente, conferindo se o questionário JSON permaneceu byte a byte. Não force testes a passar reduzindo cobertura.
5. Prepare `auditoria-final/PARECER_FINAL.md` com GO / GO-COM-RESSALVAS / NO-GO, tabela de riscos residuais, testes realizados/não realizados, compatibilidade e correções futuras. Prepare metadados de congelamento (commit, inventário, SBOM/licenças e forma de gerar hash SHA-256 do artefato representativo), mas **não envie registro** e não gere hash de material que ainda mudará.

**Acompanhamento:** após cada marco B0–B4, atualizar PROGRESSO + ACHADOS com commit e comentar no Issue #21 se disponível. Ao parar ou atingir limite, deixar HANDOFF completo. Priorize resolver falhas graves e validar em vez de deixar acabamento estético. Informe honestamente o que continuou fora de escopo e quais verificações ainda exigem aparelho Android real, revisão clínica, jurídico/LGPD e testes controlados de backend.

**Proibição absoluta:** publicar APK ou site, inserir chave de assinatura em texto/commits, alterar regras clínicas sem revisão, ativar Google/Neon sem projeto de autorização, apagar banco real ou afirmar "compliance" sem prova.
