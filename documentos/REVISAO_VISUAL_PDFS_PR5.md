# PR #5 — correção tipográfica dos PDFs

**Aprovação visual do usuário pendente. Não realizar merge ou deploy.**

Esta revisão substitui as evidências tipográficas do commit `5b5bd22`. Os dados sintéticos foram preservados integralmente; somente a apresentação dos PDFs e sua validação foram alteradas. Questionário, conteúdo clínico, banco, autenticação e demais funcionalidades permanecem intactos.

## Diagnóstico confirmado

Antes da correção, `pdffonts` encontrou Helvetica e Helvetica-Bold não incorporadas (`emb=no`, `uni=no`), misturadas com DejaVu Sans incorporada somente como fallback. `pdffonts -subst` confirmou substituição das Helvetica por NimbusSans-Regular e NimbusSans-Bold no Poppler. A aparência dependia das fontes do leitor e alguns caracteres trocavam de família no mesmo parágrafo. O fallback Regular também não garantia peso Bold consistente.

Os cartões usavam corpo de 7,15 pt, os números de seção 6,4 pt e a declaração podia diminuir até 8 pt. A justificação da declaração ampliava espaços conforme a linha. A revisão anterior corrigia glifos ausentes, mas não garantia uniformidade tipográfica.

A pasta `evidencias/pr5-pdfs/comparacao/` conserva relatórios de fontes anteriores e primeiras páginas renderizadas novamente a 240 dpi. A comparação usa a mesma resolução e os mesmos dados, sem edição das imagens.

## Correção

- Uma família em todos os textos: **DejaVu Sans Regular (Book) e Bold**, ambas incorporadas e com mapas Unicode. Nos documentos verificados não há Helvetica, fallback externo ou substituição pelo leitor.
- Pesos explicitamente configurados no tema. Acentos, cedilhas, aspas curvas e travessões usam a mesma família do parágrafo.
- Espaçamento natural: `letterSpacing=0` e `wordSpacing=1`. No pacote Dart `pdf`, `wordSpacing` é multiplicador; zero eliminaria espaços. A declaração usa alinhamento à esquerda, sem expansão irregular por justificação.
- Declaração com **corpo fixo de 10 pt**, sem reduzir a fonte para caber. Continua em uma página A4; se exceder a área útil, mantém a orientação para resumir ou usar o registro completo.
- Cartões e dados do resumo com **9 pt**; assinaturas com 9 pt; números de seção com 8 pt; linha institucional e rodapé com 8,5 pt.
- Registro completo com perguntas Bold e respostas Regular de **11 pt**, com espaçamento entre linhas de 1,5 pt.
- As prévias são medidas com a fonte incorporada no tamanho final. Quando necessário, são abreviadas com indicação para o registro completo, sem recorte ou redução da fonte. A primeira página mostra até quatro itens por cartão; todas as escolhas permanecem nas páginas seguintes.
- Cores, títulos, logotipos, mascote, assinaturas e estrutura dos cartões preservados. A fonte da interface Flutter não foi modificada.

## Fontes, licença e pubspec

| Arquivo | Variante | SHA-256 |
| --- | --- | --- |
| `assets/fonts/DejaVuSans.ttf` | Book / Regular | `57f73e11f51999432bf7ab22ce55b6f945d5eca1bf824404cfa9ec2e3718c84e` |
| `assets/fonts/DejaVuSans-Bold.ttf` | Bold | `a4c5bc453ca281d90ea079e596da7ae0dfeb5777497c29ec254e76d97ff6f890` |

As fontes não sofreram alterações binárias. A licença compartilhada `DejaVuSans-LICENSE.txt` contém a permissão Bitstream Vera para os arquivos de fonte e informa que as alterações DejaVu são de domínio público. A seção GPL do aviso refere-se ao empacotamento `debian/*`, não aos TrueType utilizados.

O `pubspec.yaml` declara Regular, Bold e o aviso de licença. Os três arquivos foram conferidos em `build/web/assets/assets/fonts/`. Dependências Dart e lockfile não foram alterados; não há download de fontes ao gerar o documento.

## Evidências atuais

**[Abrir comparação antes/depois, galeria completa e PDFs](evidencias/pr5-pdfs/README.md).**

| Documento sintético | Páginas | Resultado |
| --- | ---: | --- |
| Declaração | 1 | 31 respostas, local/data, assinaturas e rodapé preservados |
| Resumo visual e registro completo | 4 | Primeira página visual e 31 respostas integrais |
| Registro completo extenso | 6 | Todas as opções múltiplas e relato longo até seu marcador final |

Os onze PNGs foram renderizados por `pdftoppm -r 240 -png` e inspecionados. Todas as folhas são A4 (595,276 × 841,890 pt), com as palavras dentro dos limites da página. Os dados de entrada são idênticos aos anteriores; foram conferidas as 31 respostas, acentuação, pontuação e o fim do relato extenso. Não foram observados caracteres quebrados, quadrados, sobreposições ou cortes nos exemplos corrigidos.

Os arquivos `*-fontes.txt` registram `emb=yes` e `uni=yes` para Regular e Bold; a lista de substituições está vazia. `manifesto.json` registra páginas, resolução e hashes dos PDFs e PNGs. Não se certifica suporte universal a todo Unicode ou emoji; os caracteres dos cenários sintéticos foram efetivamente conferidos.

O cenário extenso é um teste técnico, inclusive com alternativas mutuamente incompatíveis. Não é orientação clínica ou plano para uso assistencial. Impressão física e experiência real no navegador permanecem fora desta validação.

## Testes e alteração necessária no CI

Os **67 casos atuais foram preservados**. O leitor de teste anterior tratava streams como Latin-1 e não interpretava corretamente glyph IDs/ToUnicode de TrueType incorporadas. Foi substituído por `pdftotext`, preservando verificações de conteúdo e acrescentando conferência de incorporação, Unicode e ausência de Helvetica com `pdffonts`.

Por isso, o workflow de verificação garante `pdftotext` e `pdffonts`, instalando `poppler-utils` somente se necessário. É uma dependência de testes, não do aplicativo Web. Gatilhos, permissões e workflow de publicação não foram alterados; não há deploy nessa etapa.

| Verificação local | Resultado |
| --- | --- |
| `flutter pub get --enforce-lockfile` | Aprovado, lockfile preservado |
| `flutter analyze` | Nenhum apontamento |
| `flutter test --no-pub --concurrency 4 --reporter expanded` | 67 aprovados, sem falhas/skips |
| `flutter build web --release` | Aprovado em 73,2 s, incluindo Wasm dry run |
| `pdffonts` nos três PDFs | Somente Regular/Bold incorporadas, Unicode presente, sem substituições |
| Renderização e integridade | Onze páginas A4 em 240 dpi; 31 respostas preservadas |

A aprovação remota deve corresponder ao HEAD atual da PR #5 e é registrada na descrição da própria PR. **CI verde não substitui a aprovação visual do usuário. A PR deve permanecer sem merge até essa aprovação.**

## Reprodução

Com Poppler instalado:

```bash
flutter pub get --enforce-lockfile
flutter analyze
flutter test --no-pub
flutter build web --release
pdffonts build/test_artifacts/pr5_visual/declaracao.pdf
pdffonts build/test_artifacts/pr5_visual/resumoVisual.pdf
pdftoppm -r 240 -png build/test_artifacts/pr5_visual/declaracao.pdf declaracao
pdftoppm -r 240 -png build/test_artifacts/pr5_visual/resumoVisual.pdf resumoVisual
pdftoppm -r 240 -png build/test_artifacts/pr5_visual/resumoVisual-longo.pdf resumoVisual-longo
```

Não houve navegador, alteração de proteções, acesso a produção, migração Neon, alteração do Diário da Gestante, merge ou deploy.
