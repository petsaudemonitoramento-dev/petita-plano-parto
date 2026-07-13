# Política de Privacidade

O aplicativo **Petita — Plano de Parto PET Saúde** foi desenvolvido com funcionamento offline-first, mantendo as funções essenciais do Plano de Parto disponíveis mesmo sem internet.

## Dados utilizados

O aplicativo pode registrar localmente informações como nome da gestante, e-mail, DPP, UBS de referência, preferências do Plano de Parto, aceite dos termos e respostas fornecidas durante a conversa.

Quando a usuária cria uma conta online, o sistema utiliza e-mail e senha para autenticação via Supabase Auth. O e-mail permanece associado ao perfil online e poderá ser usado futuramente para avisos relacionados à conta ou a respostas da UBS.

## Senhas

A senha é processada pelo sistema de autenticação do Supabase. Ela não é exibida para a Equipe UBS nem armazenada em texto puro nas tabelas públicas do aplicativo.

## Armazenamento e sincronização

As informações principais do Plano de Parto podem permanecer no dispositivo. Quando houver login e internet, algumas informações podem ser sincronizadas com o Supabase para permitir recuperação de dados, envio de dúvidas, consulta de respostas e outras funcionalidades online.

## Respostas da Petita e RAG documental

A Petita pode consultar semanticamente documentos de apoio cadastrados por administradores. Para isso:

- arquivos PDF com texto selecionável e DOCX podem ser armazenados no Supabase Storage;
- o conteúdo pode ser processado por serviços de computação em nuvem para conversão em texto e geração de representações semânticas;
- as perguntas digitadas pela gestante podem ser enviadas a esses serviços para localizar trechos relacionados e elaborar uma resposta baseada nas referências cadastradas;
- a Petita não realiza busca livre na internet durante esse processo.

A usuária deve evitar incluir informações diretamente identificáveis no campo de conversa, como nome completo, telefone, endereço, CPF ou cartão SUS.

## Dúvidas enviadas à UBS

As dúvidas encaminhadas à Equipe UBS são exibidas aos profissionais de forma anonimizada. A equipe não recebe nome, e-mail, telefone, CPF, cartão SUS ou Plano de Parto completo. O sistema mantém internamente um vínculo técnico privado para entregar a resposta à conta correta.

## Documentos administrativos

Somente contas administradoras podem anexar ou remover documentos de apoio. A remoção apaga o arquivo armazenado e os trechos semânticos associados, impedindo seu uso em novas respostas.

## Segurança e limitações

Informações relacionadas à saúde exigem cuidado especial. A Petita pode cometer erros, e informações importantes devem ser confirmadas com a equipe de saúde. O aplicativo não substitui atendimento profissional ou de urgência.
