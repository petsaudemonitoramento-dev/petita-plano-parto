# Modelo de parecer final — Petita 0.3.0

**Estado:** MODELO; não representa avaliação concluída. Preencher com dados reais da auditoria, nenhuma aprovação presumida.

## Decisão
- **Resultado geral:** PENDENTE (GO / GO-COM-RESSALVAS / NO-GO).
- **Escopo:** código da Petita 0.3.0+21; APK/Web, backend legado e Neon Auth em estados distintos, conforme evidências.
- **Auditor(es) / sessões:** PENDENTE.
- **Branch e commit final:** PENDENTE.
- **Última verificação CI:** PENDENTE.

## Segurança por superfície

| Superfície | Status (GO/RESSALVAS/NO-GO/NÃO VERIFICADO) | Evidência | Ação |
|---|---|---|---|
| Consentimento inicial e privacidade | NÃO VERIFICADO | — | — |
| Armazenamento offline / exclusão | NÃO VERIFICADO | — | — |
| Gestante: sessão e acesso próprio | NÃO VERIFICADO | — | — |
| UBS: anonimato e isolamento entre unidades | NÃO VERIFICADO | — | — |
| Admin: autorização do servidor | NÃO VERIFICADO | — | — |
| RLS, RPC, Supabase legado e eventual Neon Auth | NÃO VERIFICADO | — | — |
| Edge Functions/RAG e upload | NÃO VERIFICADO | — | — |
| Chaves, CI/CD, assinatura e atualização APK | NÃO VERIFICADO | — | — |
| PDF e compartilhamento | NÃO VERIFICADO | — | — |
| Perguntas, modo consulta e voz local | NÃO VERIFICADO | — | — |

## Testes e medições (preencher)
| Procedimento | Ambiente | Comando/versão | Resultado | Link de evidência |
|---|---|---|---|---|
| flutter analyze | — | — | NÃO EXECUTADO | — |
| flutter test (total, falhas) | — | — | NÃO EXECUTADO | — |
| Build Web | — | — | NÃO EXECUTADO | — |
| Build Android debug | — | — | NÃO EXECUTADO | — |
| Verificação pergunta JSON SHA | — | — | NÃO EXECUTADO | — |
| Teste offline e bateria/teclado/rotação | — | — | NÃO EXECUTADO | — |
| PDF com texto longo e impressão | — | — | NÃO EXECUTADO | — |
| Teste RLS com UBS A/B sintéticas | — | — | NÃO EXECUTADO | — |
| Certificado Android e upgrade legado | — | — | NÃO EXECUTADO | — |
| Bench PDF antes/depois (ms, mediana, n) | — | — | NÃO MEDIDO | — |
| APK ARM64 tamanho antes/depois (bytes) | — | — | NÃO MEDIDO | — |

## Achados
Listar cada P0/P1 aberto e fechado com links para `ACHADOS.md`, PR/commit e falhas reproduzidas; zeros só se comprovados.

## Riscos residuais e validação externa
- Revisão da equipe de saúde dos textos e alertas clínicos: PENDENTE.
- Testes reais em aparelhos Android representativos: PENDENTE.
- Teste end-to-end de Neon/Google/RLS em ambiente isolado e autorizado: PENDENTE.
- Revisão jurídica/LGPD e política de privacidade: PENDENTE.
- Recuperação/backup de arquivos locais e atualização desde APKs com certificados diferentes: PENDENTE.

## Congelamento do pacote representativo
- Autor(es) e atribuições aprovadas: PENDENTE.
- Lista de arquivos/fonte e exclusões de tokens/segredos/dados pessoais: PENDENTE.
- Versão/commit imutável + tag: PENDENTE.
- Hash SHA-256 do arquivo **exatamente submetido**, com nome/tamanho: PENDENTE.
- Dependências/licenças/SBOM: PENDENTE.
- Conciliação do hash e arquivo com NITT/INPI (conforme processo): PENDENTE.
- Parecer de release distinto do registro: PENDENTE.

**Não concluir que registro de software, CI aprovado ou auditoria por IA equivale a aprovação clínica ou conformidade LGPD.**
