# Android permanente e APK interno

Branch independente `feat/android-plataforma-permanente`, originada da main `784271a`; não depende da PR #15, schemas Neon ou migrations. A PR #6 demonstrou build debug com scaffold temporário; esta entrega persiste a plataforma oficial Flutter e passa a compilá-la diretamente.

## Identidade, toolchain e arte

- Nome exibido: **Petita**. Identificador institucional **proposto**, ainda sujeito à aprovação: `br.edu.ufcg.petsaude.petita`. Não publicar/reservar como identidade definitiva por esta PR.
- Debug interno: `br.edu.ufcg.petsaude.petita.internal`, versionName `0.2.0-internal`, versionCode 20, para separar instalações futuras. Release de verificação: `.releasecheck`, `0.2.0-unsigned-test`, sem assinatura, portanto não instalável/distribuível.
- Flutter 3.44.0 / Dart 3.12.0; Java 17, Gradle 9.1.0 com checksum, AGP 9.0.1, Kotlin 2.3.20, compile/target SDK 36, mínimo 24 (Android 7). Combinação gerada pelo template oficial desta versão Flutter. Wrapper, scripts e jar versionados, sem local.properties ou chaves.
- Ícones launcher mdpi–xxxhdpi, adaptativo API26+, monocromático API33+ e splash antigo/API31+ são derivados somente de `assets/branding/Petita_icone_android_1024.png`. Sem redesenho ou troca de cores da arte original. A versão temática usa alpha derivado da luminância; não utiliza uma foto colorida como máscara opaca.
- [Preview estático de máscaras](evidencias/android/branding-preview.png). Não é captura de aparelho. O foreground mantém o desenho centralizado dentro da zona segura, com padding e fundo rosa; originais de Flutter e o PNG-fonte permanecem intactos.
- Reproduzir recursos: `python3 tools/generate_android_branding.py` (Pillow 12.3.0). Builds usam PNGs já versionados, sem instalar gerador na execução do app. Hash da arte oficial conferido pelo gerador e pelo inspetor.

## Segurança e permissões

Manifest principal pede apenas INTERNET; não pede câmera, microfone, contatos, localização, notificações ou armazenamento amplo. O manifest mesclado também é inspecionado; AndroidX pode adicionar somente a permissão de receptor privado com proteção de assinatura.

Cleartext HTTP e CAs instaladas pelo usuário são bloqueados; somente trust store do sistema. Nenhuma orientação fixa: o Flutter continua responsivo para orientação, teclado, fonte e telas diferentes. AllowBackup=false, regras de cloud backup e transferência excluem arquivos, preferências, bancos e armazenamento externo do app. Verificar transferência também em aparelhos/fabricantes reais antes de liberar dados sensíveis; esse recurso não cifra o SharedPreferences atual.

O plugin printing 5.15.0 fornece FileProvider não exportado, authority por applicationId e URIs temporárias para cache/share. O inspetor verifica esses atributos no APK. Não é concedida leitura global de armazenamento. O plugin pode manter temporários em cache; destinatários externos controlam as cópias compartilhadas. Revogação local não pode apagar PDFs enviados a outros aplicativos.

Não há credenciais Postgres, chave administrativa ou signing key no código. A configuração Supabase legada contém referência pública, não senha; não é tratada como identidade de pessoa. Em builds internos `PETITA_INTERNAL_TEST=true` **não inicializa o backend**, e a UI mostra TESTE INTERNO. Não usar contas ou informações reais. Public key não substitui autorização e a migração Neon permanece em PRs próprias.

## Inicialização offline

A inicialização opcional online não pode bloquear indefinidamente runApp: há timeout de três segundos e fallback sem registrar payload de erro. Getter de sessão retorna ausência de login se o backend não foi inicializado. Na Web normal, o Supabase é mantido; no APK interno é desabilitado por define de compilação.

Termos, questionário, DPP, explicações, preferências de tratamento, persistência e PDFs continuam locais. Nenhum texto clínico ou legal foi alterado. Pronomes continuam opcionais e sua inclusão no PDF exige opt-in separado. Não há login obrigatório para essas funções.

Não está resolvido por esta PR: armazenamento cifrado, isolamento de contas, sincronização resiliente, exclusão remota, autenticação Neon/API e revisão clínica humana. Portanto build interno só com dados fictícios, mesmo que debug instale e os testes passem.

## Build no GitHub Actions

Workflow `android_interno.yml`, acionado por PR/main ou manualmente, sem deploy:

1. Flutter/Java/Android SDK fixados, `flutter pub get --enforce-lockfile` e confirmação de lockfile.
2. Análise estática e toda suíte Flutter; testes específicos de sucesso, falha e timeout de inicialização.
3. SHA-256 e 31 IDs canônicos intactos, hash da arte e verificações do scaffold.
4. `flutter build apk --debug --no-pub --dart-define=PETITA_INTERNAL_TEST=true`.
5. `flutter build apk --release --no-pub --dart-define=PETITA_INTERNAL_TEST=true`, **sem chave nem fallback para debug**.
6. APKs inspecionados por apkanalyzer/aapt/apksigner: versão/ID, SDK, permissões/componentes exportados, backup/cleartext, FileProvider e ausência de padrões conhecidos de segredos. Esse scan não é prova matemática de ausência de todo segredo.
7. Artifact `petita-android-internal-RUN_ID`, retido por sete dias: debug APK, release não assinada e `test-build-provenance.json` com commit realmente compilado, tree, head da PR, run, ferramentas e SHA-256 separado de cada APK. São hashes de teste, não hashes definitivos para INPI.
8. Emulador Android 35: Wi-Fi/dados desligados, build interno, inicialização, cinco aceites, 31 respostas canônicas (incluindo idade estimada), pronomes opcionais, persistência nativa e bytes dos dois PDFs; invocação do compartilhador Android sem selecionar destino/rede. Capturas com dados sintéticos e resultados agregados em artifact próprio.

O commit efetivo de PR pode ser merge ref do GitHub; o manifesto registra `git rev-parse HEAD` e o head da PR separadamente. Uma compilação aprovada não prova distribuição funcional. Capturas e testes de emulador não são homologação física.

## Assinatura institucional futura

O build release só usa assinatura quando `PETITA_INSTITUTIONAL_SIGNING=true`; nesse caso exige `PETITA_KEYSTORE_PATH`, `PETITA_STORE_PASSWORD`, `PETITA_KEY_ALIAS` e `PETITA_KEY_PASSWORD`, vindos de secrets/cofre por workflow protegido e autorizado. Não há arquivo key.properties versionado e não foi criada chave institucional. Se a flag for ativada sem valores, o Gradle falha; não recorre a assinatura debug.

Este workflow não lê esses secrets nem publica uma release assinada. Antes de criar esse fluxo: aprovar applicationId e responsável pela chave, armazenamento/backup, ambiente de aprovação, certificados/validade, versionCode monotônico, política de atualização e eventual Play App Signing. Não reaproveitar a chave debug efêmera como chave definitiva.

## Gates restantes para uso real

- Homologar Auth/API e autorização institucional; proteção local cifrada e comportamento de logout/troca de conta/sync.
- Revisão clínica humana das explicações e revisão institucional de privacidade/titularidade.
- Instalação, atualização e reinstalação em aparelho físico, Android mínimo/atual, modo avião e redes intermitentes, backup/restauração e acesso a PDFs por destinatários reais.
- Validar acessibilidade, ícones/splash em launchers e máscaras reais, tamanhos de tela e teclado.
- Aprovar identidade e signing institucional, congelar versão/commit só depois da homologação e preparar dossiê NITT/INPI com hashes definitivos separados.

Nenhuma etapa desta PR altera Neon, habilita Auth, remove Supabase, publica Web, executa merge, distribui APK para uso real ou gera hash definitivo de registro.
