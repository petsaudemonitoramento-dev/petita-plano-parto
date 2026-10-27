# Validação Flutter da Petita

## Dependências

O commit `3400e64` (V6) acrescentou `file_picker: ^10.3.3` ao manifesto, mas não atualizou o lockfile, cuja última alteração era `e597917`. Dos cinco pacotes ausentes, somente `file_picker` é dependência direta do aplicativo.

| Pacote acrescentado | Versão resolvida | Origem |
| --- | --- | --- |
| file_picker | 10.3.10 | Dependência direta acrescentada na V6 |
| cross_file | 0.3.5+5 | Dependência direta de file_picker, constraint ^0.3.4+2 |
| dbus | 0.7.15 | Dependência direta de file_picker, constraint ^0.7.11 |
| flutter_plugin_android_lifecycle | 2.0.35 | Dependência direta de file_picker, constraint ^2.0.22 |
| win32 | 5.15.0 | Dependência direta de file_picker, constraint ^5.9.0 |

A resolução preservou todas as versões que já existiam no lockfile. A única nova dependência declarada para os testes é `flutter_test` do SDK; seus nove pacotes transitivos também foram registrados, sem upgrades das dependências existentes. Os hashes fornecidos pelo registro foram mantidos, com verificação TLS e integridade habilitadas.

## Revisão dos 34 apontamentos originais

As localizações abaixo se referem ao código anterior à correção. Não foram acrescentadas supressões de diagnóstico.

| Localização original | Tipo | Correção pontual |
| --- | --- | --- |
| `lib/main.dart:10:5` | info | Usar o argumento publishableKey; a mesma configuração pública é encaminhada ao cliente. |
| `lib/screens/admin/admin_screen.dart:405:132` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/admin/admin_screen.dart:436:9` | info | Usar initialValue, com a mesma variável e callback; o construtor anterior já tratava value como valor inicial. |
| `lib/screens/admin/admin_screen.dart:524:114` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:172:12` | warning | Remover método privado sem referências; nenhum caminho executável foi removido. |
| `lib/screens/chat/chat_screen.dart:626:51` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:635:194` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:687:51` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:776:92` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:777:53` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:885:63` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:963:65` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/chat/chat_screen.dart:972:15` | info | Usar initialValue, com a mesma variável e callback; o construtor anterior já tratava value como valor inicial. |
| `lib/screens/chat/chat_screen.dart:985:49` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/chat/chat_screen.dart:985:68` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/chat/chat_screen.dart:986:52` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/chat/chat_screen.dart:986:71` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/chat/chat_screen.dart:987:50` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/chat/chat_screen.dart:987:69` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/home/home_screen.dart:4:8` | warning | Remover o import não utilizado. |
| `lib/screens/home/home_screen.dart:6:8` | warning | Remover o import não utilizado. |
| `lib/screens/home/home_screen.dart:76:70` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/home/home_screen.dart:81:89` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/home/home_screen.dart:83:89` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/home/home_screen.dart:87:86` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/home/home_screen.dart:102:72` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/profile/profile_screen.dart:225:21` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/profile/profile_screen.dart:229:21` | info | Mover a seleção e seu callback para RadioGroup; valores, textos e regras de classificação permanecem iguais. |
| `lib/screens/profile/profile_screen.dart:255:67` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/questions/my_questions_screen.dart:94:108` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/screens/ubs/ubs_team_screen.dart:167:7` | info | Usar initialValue, com a mesma variável e callback; o construtor anterior já tratava value como valor inicial. |
| `lib/services/pdf_service.dart:469:13` | warning | Remover método privado sem referências; nenhum caminho executável foi removido. |
| `lib/widgets/petita_animated_mascot.dart:74:43` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |
| `lib/widgets/petita_animated_mascot.dart:108:61` | info | Usar withAlpha com o mesmo arredondamento de 8 bits: (255 * opacity).round(); aparência preservada. |

## Testes novos e correções verificadas

A ausência de `test/` foi confirmada antes desta tarefa. Agora há 16 testes em quatro arquivos:

- Questionário: carregamento real do asset, IDs únicos, conteúdo e opções válidas, defaults de entradas antigas. Opções vazias são permitidas para respostas livres, como a DPP; o conteúdo clínico não foi alterado.
- Armazenamento: respostas persistidas e removidas, perfil sintético, aceite completo, rejeição individual de cada aceite ausente, versão antiga, registro malformado, aceite legado e revogação dos dados locais.
- Widget de consentimento: nenhum acesso à rota protegida antes dos cinco aceites; abertura após salvar e abertura com consentimento atual já persistido.
- Widget de perfil: troca de UBS por radio buttons e persistência local da seleção.

Os testes não chamam `main`, não inicializam o Supabase e usam SharedPreferences em memória e perfil sintético com domínio `.invalid`. Não dependem de servidor, credencial ou dado real.

Dois problemas debug foram expostos e corrigidos com mudanças locais:

1. O callback de setState do consentimento devolvia Future pela atribuição em expressão. O Flutter rejeitava o retorno em debug e a tela mostrava falha mesmo após gravar os aceites. Um bloco sem retorno preserva a regra de consentimento e permite a transição esperada.
2. RadioListTile no cartão de perfil tinha um DecoratedBox opaco entre ele e o Material, gerando uma asserção em debug. Um Material transparente apenas em torno do grupo corrige o ancestral de pintura, preservando o cartão e a seleção.

## Reprodução

Versão validada: Flutter 3.44.0, commit oficial `559ffa3f75e7402d65a8def9c28389a9b2e6fe42`, Dart 3.12.0. O lockfile já exige Flutter >=3.44.0 e Dart >=3.12.0. O workflow de verificação de PR fixa essa versão e executa instalação estrita, análise, testes e build web.

Na máquina cloud, ative o SDK e os diretórios graváveis em cada shell:

```bash
export PATH=/workspace/.cloud-tools/flutter/bin:$PATH
export PUB_CACHE=/workspace/.cloud-tools/pub-cache
export XDG_CONFIG_HOME=/workspace/.cloud-tools/config
export XDG_CACHE_HOME=/workspace/.cloud-tools/cache
export ANALYZER_STATE_LOCATION_OVERRIDE=/workspace/.cloud-tools/analyzer-state
export FLUTTER_SUPPRESS_ANALYTICS=true
export DASH__SUPPRESS_ANALYTICS=true
export CHROME_EXECUTABLE=/usr/bin/chromium
cd /workspace/petita-plano-parto
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --release
```

O Dart também usa `/home/agent/.dart-tool`, que nesta máquina é um link para `/workspace/.cloud-tools/dart-state`. Preserve o link e os dados existentes. Caso uma nova máquina restrinja a criação desse estado, use o fluxo suportado de autorização para criar somente esse link ausente; não altere HOME nem permissões globais.

O desenvolvimento web pode iniciar com `flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --no-pub`. Processos precisam ser iniciados novamente em novas tarefas. Use os checkouts existentes; cada tarefa já é isolada e não requer worktree. Antes de qualquer execução em navegador, bloqueie requisições externas para impedir acesso ao Supabase de produção. Não inicie o app completo sem essa proteção nesta tarefa.

## Limitações separadas

- Chromium é detectado pelo doctor, mas a execução com sandbox está bloqueada pelo helper SUID da imagem (proprietário nobody, modo 4755; o Chromium exige root). O sandbox não foi desativado e as permissões não foram alteradas. A infraestrutura precisa fornecer um navegador compatível. Fluxos visuais em navegador permanecem não executados.
- Os testes de widget executam no runner Flutter e não substituem testes end-to-end no navegador.
- Login, sincronização, RAG, envio de dúvidas e operações administrativas remotas não foram testados; nenhum banco de produção foi acessado.
- Android/iOS e Linux desktop não fazem parte desta validação web. O doctor ainda aponta a ausência das toolchains Android/Linux desktop e avisos sobre o SDK fixado por tag.
- `flutter_markdown` está descontinuado e existem versões mais recentes de outros pacotes. Migração e upgrades foram mantidos fora desta tarefa para preservar o comportamento.
- A reprodução desta correção depende da branch da PR até sua revisão e merge. `main` não foi alterada. O rascunho de ambiente salvo não representa publicação nem validação em uma nova máquina.

## Resultados executados nesta branch

| Verificação | Resultado |
| --- | --- |
| install_script da Petita, incluindo flutter pub get --enforce-lockfile | Passou; repetição sem alterações de lockfile |
| flutter analyze | Passou: nenhum apontamento |
| flutter test | Passou: 16 testes, zero falhas, nenhum skip |
| flutter build web --release | Passou após as correções, 48,9 s; Wasm dry run aprovado (não é execução Wasm) |
| flutter run -d web-server --release + HTTP local | Servidor iniciou; index, bootstrap e main.dart.js retornaram HTTP 200 com conteúdo |
| git diff --check | Passou |
| Comparação com lockfile anterior | Nenhuma versão previamente resolvida foi alterada |

O script de instalação e as instruções de inicialização são salvos no rascunho do ambiente, com escopo Petita. O Diário não foi modificado nem reinstalado nesta tarefa. O CI remoto deve ser conferido na PR; execução local não implica execução aprovada no GitHub Actions.
