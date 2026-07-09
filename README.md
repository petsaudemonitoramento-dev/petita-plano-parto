# Plano de Parto PET Saúde — v4 offline-first

Aplicativo Flutter do **PET Saúde UFCG** com a assistente virtual **Petita**, criado para orientar gestantes e construir um Plano de Parto em formato PDF.

## Principais recursos desta versão

- Chatbot local com a Petita.
- Fluxo guiado de perguntas para montar o Plano de Parto.
- PDF em A4 de uma página, seguindo o modelo visual combinado.
- Correção dos ícones quebrados no PDF: o documento agora usa formas simples e compatíveis com o gerador PDF.
- Cadastro local/offline da paciente, preparado para login online futuro.
- Multi UBS preparado com códigos oficiais:
  - `UBS-EV-001` — UBS - Estação Velha
  - `UBS-AAV-002` — UBS - Antônio Aurélio Ventura (Cinza)
  - `UBS-RBF-003` — UBS - Romualdo Brito de Figueiredo
- Área Equipe UBS preparada, mas temporariamente indisponível até a implantação online.
- Área Administrador preparada para cadastrar UBS localmente e registrar documentos da base da Petita.
- Arquitetura preparada para Supabase, mantendo funcionamento offline das funções principais.

## Funcionamento offline-first

Mesmo sem internet, a gestante poderá:

- conversar com a Petita usando a base local;
- montar o Plano de Parto;
- editar respostas;
- visualizar o plano;
- gerar e compartilhar o PDF;
- ler termos e avisos de responsabilidade;
- salvar cadastro local no aparelho.

Funcionalidades que ficarão dependentes da versão online:

- login sincronizado;
- recuperação de conta;
- envio de dúvidas para equipe UBS;
- recebimento de respostas da UBS;
- upload real de documentos;
- busca aprofundada em documentos cadastrados;
- controle real de acesso por UBS.

## Backend recomendado

Como o fluxo do projeto já considera uso prévio de Supabase, a recomendação para a próxima etapa é:

- Supabase Auth para login;
- Supabase Postgres para perfis, UBS, planos, perguntas e respostas;
- Supabase Storage para documentos enviados pelo administrador;
- banco/local storage no app para manter o modo offline.

## Rodar no VS Code

```powershell
cd "C:\apppetita\plano_parto_pet_saude"
flutter pub get
flutter run -d chrome
```

## Gerar versão web local

```powershell
flutter build web
cd build\web
python -m http.server 8080 --bind 0.0.0.0
```

No PC: `http://localhost:8080`

No celular na mesma rede: `http://SEU-IP:8080`

## Gerar APK futuramente

Depois de configurar Android Studio/SDK:

```powershell
flutter build apk --release
```
