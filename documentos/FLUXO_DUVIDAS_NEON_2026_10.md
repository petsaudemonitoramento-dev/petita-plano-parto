# Petita — fluxo de dúvidas / UBS / administração (homologação)

## Escopo e status em 29/10/2026
- O Neon Auth (Managed Better Auth) foi ativado na branch principal e na branch de homologação do projeto `petita-plano-parto`. O provedor Google compartilhado é de desenvolvimento; **credenciais próprias do Google Cloud estão pendentes**.
- Banco de homologação `migracao-petita-homologacao-2026-10-28`: esquema `petita_atendimento` e `petita_privado` criados, com isolamento da autoria, RLS ativa e sem grants públicos.
- Migração versionada: `migrations/neon/20261029_duvidas_anonimas_ubs.sql`. **Não aplicar em `main` antes dos testes de API, permissão e revisão humana**.
- O app Flutter atual ainda usa `SupabaseService`; as alterações de textos e bloqueio de urgência desta branch **não conectam sozinhas o Neon Auth**.
- O APK de teste na Vercel não foi trocado. Não usar dados reais ou apresentar o canal como atendimento assistencial.

## Perfis e permissões

| Ação | Gestante | Equipe UBS | Admin |
| --- | --- | --- | --- |
| Construir plano offline / PDF | Sim | Não aplicável | Não aplicável |
| Entrar com Google | Sim | Sim | Sim |
| Vincular UBS de referência | Solicita/declara | Não | Confirma ou corrige |
| Enviar dúvida educativa não urgente | Somente à UBS confirmada | Não | Não |
| Ler dúvida anonimizada | Só as próprias | Somente da própria UBS | **Não** |
| Responder/encerrar | Não | Própria UBS, voluntário | Não |
| Solicitar acesso profissional | Não | Sim | Não |
| Aprovar/revogar vínculo profissional | Não | Não | Sim |
| Consultar métricas agregadas e auditoria operacional | Não | Própria UBS | Sim |

**Não é anonimato absoluto**: o servidor mantém uma ligação privada entre conta Google e dúvida para devolver uma eventual resposta; o corpo livre da mensagem pode conter informação que identifique a autora. O conteúdo exibido à equipe é pseudonimizado. CPF, nome, telefone, endereço e documentos não são campos solicitados e devem ser evitados no texto.

A vinculação com UBS **não pode ser considerada comprovada só porque a pessoa escolheu um item na lista**. Requer política de confirmação institucional antes de liberar o primeiro envio, sem disponibilizar a identidade aos profissionais na caixa de dúvidas.

## Jornada da gestante

1. Usa Petita e gera PDF offline sem criar conta.
2. Para enviar dúvida, precisa de internet e login Google concluído com Neon Auth.
3. Associa-se a **uma UBS confirmada**. Se a unidade não está disponível/confirmada, não encaminha.
4. Escreve **dúvida educativa, não urgente**, escolhe categoria e informa a autopercepção de risco.
5. Triagem mostra sinais de alerta. **Alto risco ou qualquer sinal selecionado impede o botão de enviar**; indicar atendimento presencial na UBS, maternidade, UPA ou urgência, conforme o caso.
6. Confirma separadamente: (a) não urgência, (b) possibilidade de não resposta, (c) limites da pseudonimização, (d) envio exclusivo à UBS vinculada.
7. O backend obtém a UBS da associação autorizada no servidor — **nunca aceita `ubs_code` arbitrário do cliente**. Grava a dúvida e a autoria privada na mesma transação.
8. Recebe código aleatório e acompanha `pendente`, `respondida` ou `encerrada_sem_resposta` em **Minhas dúvidas**.
9. Se a gestante não tiver internet, não enfileirar silenciosamente mensagens clínicas para envio automático; somente dados do plano continuam locais, sem sincronização.

## Aviso a exibir antes do envio

> Este canal é educativo, não funciona como atendimento, plantão ou triagem de urgência. Para dúvidas urgentes ou sinais de alerta, procure presencialmente sua UBS, maternidade, UPA ou serviço de urgência. A equipe não assume compromisso ou prazo de resposta por este canal. Suas informações cadastrais não são exibidas à equipe, mas evite dados pessoais no texto. A dúvida será disponibilizada somente à UBS vinculada à sua conta.

A ausência de compromisso por **este canal opcional** não elimina obrigações profissionais ou institucionais aplicáveis fora dele. O texto deve passar por revisão da professora/orientação clínica e área de privacidade antes de uso com pessoas reais.

## Caixa de entrada profissional
- O backend consulta o vínculo profissional ativo e filtra por `ubs_codigo` do servidor.
- Recebimento: código público, data, categoria, texto e situação; **nunca** `usuario_id`, nome, e-mail, CPF, plano, DPP, dados de outras UBS ou tabela de autoria.
- Filtros: pendentes / respondidas / encerradas; `Atualizar` manual. Sem promessa de alertas, plantão ou notificação.
- Ações: responder facultativamente; encerrar sem resposta; nenhuma ação em UBS alheia.
- Gravar auditoria de ações profissionais sem armazenar o texto no log.

## Administrador
- Conta administrativa só via promoção manual, auditada, de um usuário Google **previamente autenticado**. Nunca criar admin porque o e-mail termina com certo domínio.
- Ver solicitações de profissionais, confirmar elegibilidade institucional e UBS, aprovar/recusar, revogar acesso, consultar cadastros de UBS e indicadores agregados.
- Administrador não precisa ver conteúdo de dúvida nem a associação autora↔dúvida. **Evitar painel geral de mensagens clínicas**.
- UBS confirmada da gestante deve ser verificada por processo administrativo apropriado; nem equipes nem administradores devem descobrir qual pergunta pertence a uma pessoa.

## Contrato de API pendente de integração
`Authorization: Bearer <Neon JWT>` (somente HTTPS); servidor valida assinatura JWKS, emissor, expiração, papel, estado ativo e UBS.

- `GET /api/ubs`: catálogo oficial ativo (público).
- `GET /api/me`: papel/UBS vinculada, sem entregar qualquer dado clínico.
- `POST /api/patient/ubs-request`: solicita confirmação de UBS.
- `POST /api/questions`: somente gestante + UBS confirmada; validar termos, conteúdo, urgência, limites e gravar dúvida/autoria atomicamente.
- `GET /api/questions/mine`: somente autora autenticada.
- `GET /api/team/queue`: equipe aprovada, restrita à própria UBS, DTO sem identidade.
- `POST /api/team/questions/:id/answer` ou `/close`: só equipe daquela UBS, situação pendente e ação auditada.
- `POST /api/team/access-request`: pedido de acesso profissional; sem acesso enquanto pendente.
- `GET /api/admin/access-requests`, `POST /api/admin/access-requests/:id/approve|reject`: admin somente.
- `GET /api/admin/overview`: quantidades agregadas, sem conteúdo das perguntas.

A API **não está publicada nem deve ser chamada pelo app** até ter testes de autorização negativos. Usar `DATABASE_URL` somente no servidor, nunca no APK ou no JavaScript do navegador.

## Gatilhos antes do APK otimizado no site
1. Credenciais próprias Google Cloud no Neon, domínio/retorno OAuth do Android e sessão testada.
2. API HTTPS hospedada em plano gratuito compatível, secrets no servidor e validação de JWT verificada.
3. Validar vínculo de UBS real por procedimento aprovado, separação da autoria e impossibilidade de acesso cruzado.
4. UI Flutter trocada de `SupabaseService` para o backend Neon; logout, sessão restaurada e mensagens de falha.
5. Testes de rede ruim, offline, troca de conta, sinal de alerta, 403 entre UBS, admin sem acesso à autoria, respostas opcionais, PDFs locais.
6. Revisão clínica/institucional e testes em Android ARM64 real; assinatura de atualização estável antes de substituir o APK divulgado.
