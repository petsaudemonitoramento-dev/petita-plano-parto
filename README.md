# Plano de Parto PET Saúde — Petita

Aplicativo Flutter offline-first para construção guiada do Plano de Parto com a assistente virtual Petita, integração Supabase, fluxo Multi UBS e envio de dúvidas anonimizadas para a Equipe UBS.

## Versão

`0.1.3-beta` / build `8` — V5.3

## Destaques da V5.3

- Painel Administrativo bloqueado até login confirmado com conta administradora.
- Interface administrativa tratada como área restrita, sem mensagens provisórias para a usuária.
- Equipe UBS entra com e-mail e senha; novas contas precisam ser liberadas pelo administrador.
- Administrador pode liberar uma conta como Equipe UBS e vincular à UBS correta.
- Fluxo de dúvida ajustado: Petita tenta responder primeiro pela base validada; se a resposta não resolver, a gestante pode encaminhar a dúvida de forma anônima para a UBS.
- PDF ajustado: rodapé sem caracteres especiais que geravam ícones quebrados, bloco de assinatura mais espaçado e aviso inferior sem símbolo quebrado.
- Texto sobre cordão umbilical/clampeamento mais simples para gestantes sem linguagem técnica pesada.
- Supabase conectado para cadastro/login por e-mail e senha.
- UBS manual permanece no Plano de Parto/PDF, mas dúvidas só são encaminhadas quando há UBS oficial vinculada.

## Autenticação

O app usa Supabase Auth para autenticação por e-mail e senha. O e-mail fica disponível no perfil online para identificação da conta e para uso futuro em avisos de resposta da UBS. As senhas são tratadas pelo Supabase Auth e não devem ser armazenadas em texto puro em tabelas públicas.

## SQL adicional obrigatório para V5.3

Depois de substituir os arquivos, execute no SQL Editor do Supabase:

`documentos/supabase_patch_v5_3_admin_acesso.sql`

Esse patch remove a liberação aberta de Equipe UBS e cria uma função restrita ao administrador para vincular uma conta existente à UBS correta.

## Rodar localmente

```powershell
cd "C:\apppetita\plano_parto_pet_saude"
flutter clean
flutter pub get
flutter run -d chrome --release
```

Se o debug do Chrome falhar, use:

```powershell
flutter build web --release
cd build\web
python -m http.server 8080 --bind 0.0.0.0
```

Depois abra `http://localhost:8080` no computador.

## Observação de segurança

A secret key/service role do Supabase nunca deve ser colocada no Flutter. O app cliente usa apenas a chave pública/publishable.
