# Política de Privacidade

Esta versão do aplicativo **Petita — Plano de Parto PET Saúde** foi pensada como **offline-first**, mantendo as principais funcionalidades disponíveis mesmo sem internet.

## Dados utilizados

O aplicativo pode registrar localmente informações como nome da gestante, e-mail, DPP, UBS de referência, preferências do Plano de Parto, aceite dos termos e respostas fornecidas durante a conversa com a Petita.

Quando a usuária decide criar uma conta online, o sistema usa **e-mail e senha** para autenticação via Supabase Auth. O e-mail também fica disponível no perfil online para uso futuro, por exemplo, envio de aviso de resposta da UBS ou comunicação relacionada à conta.

## Senhas

Na versão conectada ao Supabase, a senha é processada pelo sistema de autenticação do Supabase. O aplicativo não precisa exibir a senha para a Equipe UBS nem para a gestante depois do cadastro.

## Armazenamento

As informações principais do Plano de Parto podem ficar armazenadas localmente no dispositivo. Quando houver login e internet, algumas informações podem ser sincronizadas com o banco Supabase para permitir funcionalidades online, como recuperação de plano, envio de dúvidas à UBS e resposta da Equipe UBS.

## Dados sensíveis

Informações relacionadas à saúde exigem cuidado especial. Por isso, o aplicativo evita solicitar CPF, cartão SUS, endereço completo e outros dados diretamente identificáveis nesta fase.

## Dúvidas enviadas à UBS

As dúvidas enviadas pelas gestantes à Equipe UBS são exibidas aos profissionais de forma anonimizada, sem nome, e-mail, telefone, CPF, cartão SUS ou plano completo da paciente. O sistema mantém internamente apenas um identificador técnico para entregar a resposta ao perfil correto.

A usuária deve evitar escrever no campo da dúvida informações que a identifiquem diretamente, como nome completo, telefone, endereço, CPF ou cartão SUS.
