# Evidências para congelamento/registro do software

**Propósito:** preparar rastreabilidade técnica antes de entregar código-fonte representativo ao NITT/INPI. Esta lista não afirma que o código foi protocolado ou que há certificado.

## Checklist de rastreabilidade
- [ ] Definir escopo final: Petita app Flutter, configuração Android, funções/backend incluídos ou excluídos e motivo; não confundir com MAE APS ou Gestário APS.
- [ ] Identificar autores/contribuições e confirmar com o processo institucional. Diferenciar copyright de dependências abertas e componentes de terceiros.
- [ ] Registrar versão, tag e SHA **do commit congelado** após aprovação dos patches. A presença de `0.3.0+21` em `pubspec.yaml` não prova publicação do APK.
- [ ] Inventariar arquivos incluídos, linguagens e licenças. Documentar dependências Flutter/Dart, fontes/assets, biblioteca TTS, `pdf`, `printing`, `shared_preferences`, `supabase_flutter`, RAG/SDKs.
- [ ] Garantir exclusão de chaves privadas, keystores, arquivos de ambiente, dados reais, backups com PII e tokens. Revisar histórico acessível do GitHub e artefatos de CI antes de anexar código.
- [ ] Gerar arquivo representativo imutável **após o freeze**. Calcular SHA-256 sobre os bytes finais, registrar nome/tamanho/hash/caminho seguro. Se qualquer byte mudar, calcular novamente.
- [ ] Guardar documento de arquitetura, diagramas do fluxo e relatório de testes + pendências. Registrar que a auditoria por Codex não equivale à validação humana/LGPD/clínica.
- [ ] Confirmar com NITT qual formato, escopo e fluxo institucional exigido; não presumir que o hash enviado anteriormente é do novo pacote.
- [ ] Encaminhar à equipe/NITT somente após revisão e autorização expressa.

## Como reproduzir um SHA-256 **sem imprimir conteúdo**
```bash
# Exemplo: substituir pelo caminho do pacote representativo APROVADO.
sha256sum Petita_codigo_representativo_versao_aprovada.zip
stat -c '%n %s bytes' Petita_codigo_representativo_versao_aprovada.zip
```

**Dados a preencher:** arquivo, tamanho em bytes, SHA-256 exato, commit da origem, data UTC, responsável pela verificação. Não inventar hash nem reutilizar hash de outra versão.

## Risco especial: assinatura do Android
- Existe histórico de builds assinados com material temporário. Validar quem detém a chave persistente, o certificado SHA-256, as permissões e o processo seguro de renovação.
- Qualquer chave ou senha anteriormente anexada/compartilhada deve ter seu histórico de exposição avaliado. Se houver exposição além do círculo autorizado, executar rotação **antes** da release; não copiar segredo para Issues/PRs.
- A assinatura do APK e o hash do pacote de código representativo são **dois artefatos diferentes** e não devem ser confundidos.
