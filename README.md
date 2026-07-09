# Plano de Parto PET Saúde

Aplicativo Flutter mobile-first para o PET Saúde UFCG, com chatbot educativo **Petita**, construção guiada do Plano de Parto, termos de uso, versão do sistema e protótipo local da área **Equipe UBS**.

## Como rodar no VS Code

1. Instale Flutter SDK e configure o VS Code com as extensões Flutter e Dart.
2. Abra esta pasta no VS Code.
3. No terminal, rode:

```bash
flutter pub get
flutter run -d chrome
```

## Para gerar APK Android

Se a pasta `android/` ainda não existir na sua máquina, rode uma única vez:

```bash
flutter create . --platforms=android,web
```

Depois:

```bash
flutter build apk --release
```

O APK será gerado em `build/app/outputs/flutter-apk/app-release.apk`.

## Observações

- A versão atual é **0.1.0-beta** e funciona offline/localmente.
- A área **Equipe UBS** está como protótipo local para demonstrar o fluxo de dúvidas não urgentes.
- A evolução online pode usar Firebase ou Supabase para sincronizar dúvidas, respostas, perfis e conteúdo validado.
- O app possui termos clicáveis e PDF de consentimento/isenção em `assets/legal/termo_consentimento_isencao.pdf`.
