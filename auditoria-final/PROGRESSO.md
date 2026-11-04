# Progresso auditável — Petita / Codex

**Status global:** PREPARADO — Codex NÃO iniciado por este registro.
**Data da preparação:** 2026-11-04.
**Repositório:** `petsaudemonitoramento-dev/petita-plano-parto`.
**Branch inicial:** `audit/codex-final-petita-20261104` (isolada de `main`).
**Base de release:** `0.3.0+21` no `pubspec.yaml`.
**Painéis:** #21 central; #22 janela A; #23 janela B.

## Quadro resumido

| Marco | Estado | Última evidência | Próxima ação |
|---|---|---|---|
| A0 — baseline/ambiente | PENDENTE | Repositório inspecionado na preparação; Codex ainda não executou comandos | Executar verificação e registrar SHA do baseline |
| A1 — segurança/ameaças | PENDENTE | Possíveis prioridades identificadas, sem verificação | Revisar auth, RLS, isolamento UBS, endpoints, admin e segredos |
| A2 — dados/privacidade | PENDENTE | SharedPreferences identificado no código | Mapear dados sensíveis, retenção, consentimento e exclusão |
| A3 — testes adversariais | PENDENTE | Suite Flutter existente, novos testes ainda não executados pelo Codex | Rodar testes e criar fixtures de UBS distintas |
| A4 — relatório riscos | PENDENTE | Documento inicial de riscos em `ACHADOS.md` | Classificar P0/P1/P2 somente após provas |
| B0 — retomada | AGUARDANDO A | — | Ler HANDOFF |
| B1 — correções | AGUARDANDO A | — | Priorizar P0/P1 |
| B2 — benchmarks | AGUARDANDO A | — | Baseline PDF/APK/startup |
| B3 — hardening/CI | AGUARDANDO A | — | Validar patches |
| B4 — parecer/congelamento | AGUARDANDO A | — | Redigir relatório final |

## Pontos de inspeção levantados na preparação (NÃO equivalem a vulnerabilidade confirmada)
- **INSP-01:** cliente `lib/main.dart` inicializa Supabase legado; projeto Neon/Auth existe separadamente. Confirmar o estado efetivo da migração sem chamar serviços reais.
- **INSP-02:** `lib/services/storage_service.dart` usa SharedPreferences com dados de gestação e consultas; verificar modelo de ameaças/criptografia/backup.
- **INSP-03:** `supabase/config.toml` marca `ask-petita-rag` com `verify_jwt=false`; verificar controle complementar, rate limiting, autorização e custo.
- **INSP-04:** telas admin/UBS, SQL/RPCs e Edge Functions ainda dependem de serviço remoto; isolamento de UBS e anonimato só podem ser confirmados por testes de autorização.
- **INSP-05:** `README.md` e `lib/config/app_info.dart` citam versão anterior; analisar inconsistência de documentação.
- **INSP-06:** APKs anteriores tinham assinaturas temporárias; verificar estratégia de update e origem/proteção da chave futura, inclusive potenciais exposições históricas.
- **INSP-07:** CI valida Flutter e APK debug; avaliar cobertura real de segurança, builds de release e revisão dos scripts de publicação.

## Modelo de atualização — completar imediatamente após marco
```text
[2026-.. ..:.. BRT] MARCO A1 — EM ANDAMENTO / CONCLUÍDO / BLOQUEADO
Branch / commit:
O que foi feito:
Arquivos:linhas:
Comando e resultado (sem segredos):
P0/P1 descobertos:
Próximo passo exato:
Possível bloqueio/manual:
Comentário postado em #21: [link/ID ou "sem permissão"]
```

## HANDOFF obrigatório — manter este bloco atualizado
- Janela atual: ainda não iniciada.
- Último commit da auditoria: a preencher ao iniciar Codex.
- Último marco concluído: nenhum.
- Working tree e commits pendentes: a verificar.
- Evidência de testes: ainda não executados pelo Codex.
- Riscos P0/P1 confirmados: nenhum confirmado nesta preparação.
- Pendências: diagnóstico, correção, build e avaliação manual.
- **Primeira ação na retomada:** abrir `AGENTS.md` + `auditoria-final/PLANO_MESTRE.md`, verificar git SHA e iniciar A0.
