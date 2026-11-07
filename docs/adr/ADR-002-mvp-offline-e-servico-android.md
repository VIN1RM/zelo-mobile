# ADR-002 — Persistência offline, serviço Android e exclusão

Data: 7 de novembro de 2026. Estado: implementado em desenvolvimento;
aceite físico e implantação de produção pendentes.

## Contexto

O MVP precisa operar sem rede, manter alertas enquanto a interface está em
segundo plano e não confundir sincronização, compartilhamento ou sensores
disponíveis com proteção confirmada. O modelo lógico do Word é mantido, com
as decisões físicas a seguir explicitadas.

## Decisão

Usar SQLCipher e uma tabela `records` com envelope tipado e payload JSON por
entidade. UID, tipo e ID formam a chave; revisões, tombstones, prioridade,
slot, estado operacional e parentesco são colunas indexadas. Há validação de
JSON, vínculo de pai no mesmo UID, unicidade parcial de contatos/prioridades
e uma sessão operacional local. A tabela física não reproduz as tabelas
nomeadas no documento: reduz migrações do payload, exigindo validações de
domínio no repositório e testes de integridade. Outbox, anexos, preferências,
tentativas, diagnósticos e recibos possuem armazenamento próprio.

Tombstones de registros removem nome/canais de contato, localização e notas.
Mantêm IDs, revisões e campos estruturais de data/resultado para reconciliação
e imutabilidade. O contato excluído usa canal técnico `deleted@zelo.invalid`
no payload tipado, sem destinatário real. Não aparece na lista de contatos.
Excluir registros não equivale a apagar esses marcadores; exclusão da conta
remove os dados de domínio e mantém somente a barreira de exclusão descrita abaixo.

Gravar alteração e Outbox na mesma transação; confirmar remotamente com
transações Firestore, revisões e comparação estrutural para repetição após
perda da confirmação. Contatos são enviados/recebidos em lote para respeitar
reordenação e unicidade. Conflitos não sobrescrevem silenciosamente o registro
local. Tombstones impedem ressurreição. Sincronização automática publica a fila;
leituras remotas completas são espaçadas e também estão disponíveis manualmente.

Executar sensores e contagem no serviço foreground Kotlin, com journal
AtomicFile/AES-GCM e recibos confirmados após commit SQL. O serviço não reinicia
sozinho. Falta de amostras recentes produz estado limitado; perda do serviço
interrompe a sessão. A heurística inicial permanece explicitamente experimental.

Manter fotos AES-GCM e notas apenas no aparelho. GPS é captura pontual opcional.
Interface de ajuda apenas abre destinos e registra tentativas, nunca “enviado”.

Exclusão de conta mantém marcador mínimo pseudônimo por UID fora de `users`.
Ele bloqueia escritas de tokens ainda válidos, inclusive durante exclusão parcial.
Dados de domínio, anexos locais e usuário Auth são removidos no fluxo retomável.
Essa retenção técnica é uma exceção à exclusão integral de todos os metadados,
precisa de transparência na política e futura revisão de prazo pelo responsável.

## Consequências

Kotlin 2.4.21 é mantido da baseline Firebase. R8 foi explicitamente alinhado
a 9.1.29 no gerenciamento de plugins, usando o repositório oficial de releases,
pois o R8 incluído originalmente no AGP 8.9.1 não suporta esses metadados.
Fontes: [matriz Android](https://developer.android.com/build/kotlin-support)
e [distribuição oficial R8](https://r8.googlesource.com/r8/+/refs/heads/main/README.md).
Builds Flutter devem regenerar os registros de plugins para o modo solicitado;
não reutilizar registro gerado por integração/debug em uma compilação release.

O app oferece operação local e recuperação durável, mas não garante execução
contínua em todo Android. Keystore perdido ou desinstalação tornam dados locais
irrecuperáveis; fotos não têm restauração remota. O backend exige regras
publicadas e região escolhida antes de uso real. Os testes em emulador não
substituem calibração, ensaios físicos ou aprovação de privacidade.
