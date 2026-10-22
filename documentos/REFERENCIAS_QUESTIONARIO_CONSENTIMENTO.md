# Referências do roteiro do Plano de Parto e da ciência inicial

Data da revisão: 21/10/2026.

## Fonte principal

Documento fornecido pela equipe do projeto: **Possíveis Perguntas e Respostas do Chatbot.docx** (o conteúdo de trabalho está na conversa de planejamento do projeto). O arquivo traz a introdução sobre a natureza do plano de parto, grupos de perguntas e opções sobre:

1. identificação, contexto gestacional e preferências;
2. acompanhante, doula e comunicação;
3. movimento, conforto e alívio da dor;
4. período expulsivo, intervenções e nascimento;
5. cuidados com bebê, amamentação e pós-parto;
6. ambiente, privacidade e preferências culturais.

O fluxo em `assets/data/birth_plan_flow.json` foi alinhado à linguagem das perguntas e ampliado **de 17 para 31 itens**. A seleção não reproduz todas as questões do documento: evita coletar histórico clínico detalhado que não será apresentado no PDF, e mantém a experiência conversacional mais curta. Conteúdo adicional depende de avaliação clínica da equipe PET Saúde.

## Ciência obrigatória antes de preencher

- Acesso ao chat, ao perfil da gestante, ao resumo/PDF e a "Minhas dúvidas" é condicionado ao registro de ciência.
- O termo usa cinco confirmações não marcadas por padrão: ciência sobre plano de parto; termos de uso; leitura da privacidade; uso local de dados pessoais e de saúde; limites educativos e ausência de atendimento de urgência.
- O botão de avanço fica desativado até a confirmação completa.
- A data e a versão dos textos são armazenadas **localmente**. Aceites legados sem versão não valem para a nova regra.
- A equipe UBS e a administração continuam com suas próprias entradas.
- Há uma ação para retirar a ciência e limpar dados **locais**; isso não remove dados que já tenham sido sincronizados online.

**Importante:** a ciência de uso do aplicativo não é consentimento para procedimento obstétrico, não elimina a autonomia da gestante e não substitui a conversa com profissionais.

## Documento final

O PDF continua em uma página como **síntese** das escolhas prioritárias. O resumo do aplicativo guarda o conjunto de respostas. Sem respostas, não deve ser criado um PDF com informações fictícias. Revisão de legibilidade e da exportação precisa ocorrer em dispositivo real.

## Referências jurídicas e técnicas listadas na fonte

- Ministério da Saúde. Diretrizes Nacionais de Assistência ao Parto Normal. Portaria SAS/MS nº 353/2017. https://www.gov.br/saude/pt-br/assuntos/pcdt/a/assistencia-ao-parto-normal-diretriz-nacional/view
- Ministério da Saúde. Caderneta da Gestante (edição 2026, conforme identificação no documento da equipe).
- BRASIL. Lei nº 11.108/2005.
- CAMPINA GRANDE. Lei Ordinária nº 9.754/2025.
- BRASIL. Lei nº 13.709/2018 (LGPD), especialmente artigo 11, para o tratamento de dados pessoais sensíveis.

## Revisões necessárias para produção

- Revisão do texto de ciência e da política por responsável institucional/LGPD.
- Testes de responsividade e rolagem da tela de ciência.
- Testes de geração do PDF de uma página com respostas longas, em diferentes dispositivos.
- Definição do ciclo de vida de dados sincronizados e estratégia de migração de backend Supabase para Neon, separada desta alteração.
