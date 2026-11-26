# SEC-04 — plano compatível de cifragem (bloqueio P1)

Não implementado nesta janela: introduzir gestão de chaves e migração de dados de saúde sem testar upgrade/restauração em Android real e Web criaria risco de perda de dados. Dados existentes não foram apagados nem regravados nesta auditoria. Leitura legível em SharedPreferences permanece comprovada. Cifragem do disco/sandbox do SO não equivale a cifragem da aplicação.

## Arquitetura proposta
- Manter uso offline sem obrigar login nem mudar identidade local. Em Android, envelope versionado AES-256-GCM com nonce criptográfico único por gravação, autenticação de versão/ID de instalação/registro no AAD e formato explícito (versão, keyId, nonce, ciphertext, tag). Usar biblioteca auditada, sem criptografia própria.
- Chave aleatória de instalação protegida pelo Android Keystore por plugin mantido, avaliado para API24+, hardware quando disponível e comportamento documentado em bloqueio/troca de biometria. Não derivar chave de email/UUID nem embutir segredo no APK. Não exigir rede para abrir plano.
- Proteger respostas, perfil, notas, preferências e dados UBS legados. Preferir armazenamento transacional cifrado ou snapshots completos com escrita atômica; não presumir atomicidade de múltiplas chaves SharedPreferences. A fila atual só protege um isolate.
- Web exige decisão separada: chave no mesmo origin/IndexedDB não protege contra XSS ou usuário com perfil do navegador. WebCrypto pode proteger exportações com segredo externo informado pela usuária, mas introduz recuperação/usabilidade. Não prometer segurança equivalente ao Keystore. Não autorizar dados reais Web sem definir esse modelo.

## Migração em fases, sem destruição
1. Ler schema legado e inventariar somente chaves conhecidas. Se conteúdo for inválido, preservá-lo e informar recuperação; não sobrescrever com lista vazia. Não copiar PII para logs, analytics ou relatórios.
2. Criar chave e journal sem dados clínicos, estado PREPARING. Gravar snapshot cifrado em destino novo (staging), mantendo originais intocados.
3. Reabrir do backend, decifrar/autenticar e comparar conteúdo canônico com original, incluindo campos opcionais, Unicode, 31 respostas, pronome/opt-in e notas. Validar integridade sem registrar hash público de informação de baixa entropia.
4. Marcar SEALED/COMMITTED de forma atômica. App passa a ler novo formato somente após confirmação; escrita nova deve usar transação/snapshot e recarga verificada. Em crash retomar journal; nunca misturar metade de versões.
5. Não apagar legado no primeiro rollout. Durante validação controlada, mantê-lo sob proteção do SO deixa risco SEC-04 residual explícito. Exclusão posterior exige política aprovada, aceitação de upgrade/restauração e retenção mínima definida. Duplicação temporária também é risco, não solução definitiva.
6. Se envelope existe mas chave sumiu/cifragem falhou, bloquear sobrescrita, mostrar opção segura de recuperação e preservar bytes. Não voltar silenciosamente a um legado possivelmente antigo. Downgrade exige versão mínima e política explícita; reverter para APK que só lê plaintext pode perder alterações cifradas.

## Recuperação, exclusão e assinatura
- Não recomendar desinstalação: ela pode apagar dados/chave. Preservar applicationId/certificado durável na estratégia de update. Aparelhos com assinatura antiga incompatível exigem plano de exportação/transferência autorizado e cifrado; não extrair dados reais nesta auditoria.
- Excluir dados deve apagar snapshots/journal/chaves conforme política, além das chaves legadas. Definir escopo local/remoto claramente e não destruir chave compartilhada com dados institucionais. Testar falha parcial e feedback.
- Android backup/transferência precisam excluir banco e chaves ou usar formato de backup recuperável deliberadamente. Keystore pode não restaurar junto com arquivo cifrado. Não chamar backup automático de recuperação testada.

## Gates obrigatórios antes de implementar/promover
Fixtures sintéticas em instalações de versões antigas; updates in-place com mesmo certificado; interrupção em cada fase; escrita false/throw; disco cheio; kill/restart; arquivo/tag alterados; nonce nunca repetido; chave indisponível; reset do lock/biometria; restore/transferência; downgrade; revogação; perfis offline/online; múltiplas abas/isolates. Validar PDF e acessibilidade de mensagens de falha. Chave, plaintext e passphrase ausentes em logs/artefatos.

Revisar biblioteca/plugin e licenças, escolher esquema transacional, preparar ameaça/recuperação e aprovar política institucional. Depois testar em Cloud/Actions e aparelhos de homologação remotos. Não converter o SEC-04 em fechado sem esses gates. Resultado atual: P1 ABERTO; uso assistencial NO-GO.
