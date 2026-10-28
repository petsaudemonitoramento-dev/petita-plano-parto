# Identidade visual Android — Petita

Este diretório guarda a arte de lançamento do aplicativo Android. A mascote original do aplicativo permanece em `assets/images/petita.png` e não deve ser substituída sem aprovação.

## Ícone aprovado para incorporação

Arte enviada à conversa em 28/10/2026, baseada no ícone criado no Canva: robô Petita em close-up, laço e antena em formato de coração, fundo rosa-claro. A imagem original recebida possui 1264 × 1264 px, JPEG.

Arquivo mestre adicionado neste diretório: [`Petita_icone_android_1024.png`](./Petita_icone_android_1024.png) (1024 × 1024 px, PNG RGB). SHA-256 verificado contra o arquivo preparado:

`bea39885f9277a0d059a1a100c4821320617a56ff21c5d4178ad45cb8429ceb9`

> **Status:** imagem incorporada à branch `feat/icon-canva-petita`. O ícone ainda **não** foi aplicado ao launcher do Android, pois a estrutura nativa `android/` precisa ser incorporada ao repositório.

## Integração Android posterior

- Manter o nome exibido **Petita** e gerar ícones PNG em múltiplas densidades `mipmap-*`.
- Gerar ícone adaptativo (foreground com área segura e background) e variante monocromática para Android 13+.
- Verificar visualização em máscara circular e arredondada, bem como tamanhos pequenos.
- Incorporar `android/` permanentemente e auditar app ID, versão, permissões e assinatura release.
- Não alterar o questionário de 31 perguntas, dados, autenticação, migração Neon ou informações clínicas.
- Não gerar novo APK release nem fazer merge sem revisão visual e testes de CI.

O arquivo neste diretório é insumo de identidade visual, não um comprovante de prontidão para publicação ou registro no INPI.
