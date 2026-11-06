# PETITA — preparação de fonte para encaminhamento ao NITT/UFCG

**Finalidade deste arquivo:** acompanhar o código-fonte da Petita para **revisão interna do NITT**; não constitui declaração definitiva de autoria, titularidade ou conformidade assistencial.

## Identificação técnica
- **Nome proposto:** Petita — Plano de Parto PET Saúde.
- **Instituição/projeto mencionado no aplicativo:** PET Saúde / Universidade Federal de Campina Grande (UFCG). Isso **não prova titularidade patrimonial**.
- **Versão do fonte:** 0.3.0 (build 21), commit de código `d34f4a33e8e9e098ec87730a08feff28218661da`. A documentação de auditoria posterior não muda esse código.
- **Tecnologias:** Flutter/Dart, Edge Functions TypeScript e configuração de backend, com dados/termos locais em JSON/Markdown.
- **Validações na auditoria:** 104 testes Flutter, 31 testes Node, Web release e Android debug aprovados em ambiente de teste. Ver PR #24 e o parecer final.
- **Estado de utilização:** GO COM RESSALVAS para documentação técnica; NO-GO para uso assistencial/dados reais. JWT/RLS/isolamento entre UBS e cifragem local não homologados.

## Autores, contribuições e titularidade — preenchimento humano obrigatório
- **Crédito visível no aplicativo:** “Lucca Araújo” (`lib/config/app_info.dart`). Confirmar nome civil completo, vínculo e declaração de contribuição no formulário de Autores do NITT.
- **Possíveis coautores:** NÃO DETERMINADOS SOMENTE PELO REPOSITÓRIO. Confirmar com coordenação/orientação e histórico de desenvolvimento antes de preencher ou excluir qualquer pessoa.
- **Titular(es) dos direitos patrimoniais:** A CONFIRMAR PELO NITT/UFCG, conforme vínculo, normas institucionais, instrumentos de projeto, cessões/contratos e eventuais parcerias. Não confundir autoria intelectual, conta GitHub, universidade associada ou financiamento com titularidade.
- **Participação de ferramentas de IA:** identificar responsabilidades humanas, direitos de componentes e política institucional. Não registrar IA como autora automaticamente.
- **Marcas/identidades institucionais:** logos PET Saúde/UFCG e mascote têm origem e autorização de uso a validar antes de incluí-los no material depositado.

## Dependências e licenças
- Pacotes Flutter/Dart não são integralmente de autoria da equipe. `pubspec.yaml` e `pubspec.lock` identificam dependências; inventário da auditoria aponta cerca de 100 pacotes e referências de licenças, cuja compatibilidade e avisos exigidos devem ser conferidos.
- Fonte DejaVu (incluída na distribuição completa da aplicação) é de terceiros e tem arquivo de licença. Os binários TTF **não entram na documentação de código-fonte entregue por este fluxo**.
- Bibliotecas, logos, fontes e demais recursos de terceiros não devem ser declarados como código original do software.
- Não foi encontrada licença de distribuição própria (`LICENSE`/`AUTHORS.md`) no snapshot consultado. Ausência de licença pública não confirma quem detém os direitos; submeter análise ao NITT.

## Conteúdo e limites do pacote preparado
- **PDF principal:** reprodução legível de arquivos-fontes do commit identificado: Dart, TypeScript, SQL e JSON do fluxo, configuração Flutter, textos legais, com numeração de linhas e identificação de arquivos.
- **ZIP complementar:** arquivos-fonte editáveis, testes pertinentes, inventário de dependências, lista de arquivos e estas notas.
- **Excluídos do ZIP deliberadamente:** `.git/`, `.env`, chaves/senhas, `supabase/.temp/` (metadados locais de conexão), caches, builds, backups/dados pessoais, binários de fontes, ícones/logos institucionais e imagens que exigem confirmação de direitos.
- Assim, o ZIP é **material representativo de código**, não uma distribuição do aplicativo pronta para compilar sem os recursos excluídos.
- Nenhum hash do PDF/ZIP deve ser gerado nesta etapa; nenhuma migração de banco, merge, assinatura ou publicação está autorizada.

## Instruções de encaminhamento
O NITT/UFCG informa em sua página de formulários de Registro de Software:
1. Formulário de Solicitação de Registro de Software;
2. Complementos de Autores e Titulares quando necessários;
3. **Código-fonte em PDF**;
4. Termo de derivação e contrato/convenio de PI, quando aplicáveis.

Contato institucional divulgado: **nitt@ufcg.edu.br**.
Fonte: https://nitt.ufcg.edu.br/formularios-de-solicitacao-de-registros/

**Pendente antes do envio:** assinatura/preenchimento dos formulários por pessoas competentes, confirmação de autoria/coautoria, titularidade, licenças/arte, escolha e autorização institucional do escopo de registro, e revisão do PDF final pelo responsável. A exigência do NITT e as etapas posteriores de registro INPI são distintas; o INPI não recebe o código-fonte integral como anexo do formulário e-Software.

Nenhum envio foi feito por esta preparação.
