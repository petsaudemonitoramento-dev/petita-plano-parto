# SEC-02 — contenção e contrato de reativação
O fonte mantém RAG externo desativado por padrão (PETITA_RAG_ENABLED ausente/false). FAQ local/curada continua. Não configurar a flag em produção nesta auditoria.

Para eventual reativação isolada: chave publicável identifica aplicativo, não pessoa. Handler exige Bearer, getUser(token) remoto e perfil active===true derivado do ID verificado. Perfil ausente/inativo nega. user_metadata/body não definem autorização. Não equivale a Neon/Google integrado.

RPC obrigatório: consume_petita_rag_quota(p_user_id uuid) RETURNS boolean, chamado somente pelo service-role após verificação. Ausência, erro ou resposta não booleana retorna503 sem provedor. false retorna429. true autoriza uma unidade de consumo. **A RPC não foi criada/aplicada nem presumida existente**; a reativação está bloqueada até sua implementação/homologação com o backend escolhido, sem duplicar #15/#17/#19.

Contrato mínimo da implementação futura: operação atômica com quotas por identidade e global, janela definida pelo relógio servidor; limites/custos aprovados; concorrência entre instâncias; reserva antes do provedor, sem devolução explorável por falha; persistência restrita em schema privado; EXECUTE revogado de PUBLIC/anon/authenticated e concedido somente ao papel de runtime autorizado; sem usar parâmetro do cliente como ator; retenção/expiração limitadas e limpeza segura. Não usar contador em memória por instância como defesa suficiente.

Testar PostgreSQL descartável/homologação com dados fictícios: N aceita, N+1 recusa; concorrência não ultrapassa N; limite global resiste a múltiplas contas; falha/desconexão nega; tabela privada inacessível a usuário comum; estado não contém pergunta/PII desnecessária. Depois validar tokens inválidos/expirados, perfil revogado, isolamento e erros no serviço isolado. Somente então considerar flag, em revisão humana separada.

Fetch externo tem AbortSignal.timeout(8000) por chamada. FAQ tem orçamento de espera próprio. Limite do handler não substitui quota persistente, gateway ou orçamento financeiro. Nada foi implantado; fonte seguro por negação não atesta segurança do serviço remoto já existente.
