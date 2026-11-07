# Prova técnica Android — acompanhamento

## Implementado neste ciclo

Em Ajustes → Diagnóstico do aparelho é possível consultar API Android,
presença de acelerômetro/giroscópio, permissão geral de notificações e isenção
de otimização de bateria. Ao voltar dos ajustes do sistema a consulta é refeita.
Falha de consulta gera estado de erro e nova tentativa, sem presumir capacidade.

Não há coleta de sensores, GPS, solicitação automática de permissões, serviço
de monitoramento, contagem de alerta ou armazenamento de dados nesta etapa.
Disponibilidade de sensores não comprova recebimento contínuo de amostras.

## Próximos experimentos

### Evidência do primeiro incremento

Em 7 de novembro de 2026:

- Flutter 3.41.4 / Dart 3.11.1 confirmados por execução do SDK.
- Resolução com `pub get --enforce-lockfile` aprovada, sem adicionar pacotes.
- Formatação e análise estática aprovadas; seis testes aprovados.
- `flutter build apk --debug --no-pub` aprovado com JDK 21 local.
- APK instalado e aberto no emulador `sdk_gphone64_x86_64`, Android 15/API 35.
- Logo/fonte conferidas visualmente; navegação Ajustes → Diagnóstico conferida
  pela árvore de acessibilidade do Android.
- Canal Kotlin retornou API 35, acelerômetro/giroscópio presentes, notificações
  não permitidas e otimização de bateria aplicada; tela apresentou esses valores.

Não há aparelho físico conectado nem aprovação da operação em segundo plano.
CI remoto e build com JDK 17 do runner ainda não executados nesta sessão.
O doctor indicou algumas licenças Android pendentes; não impediram este build
e não foram aceitas automaticamente.

| Item | Evidência exigida | Estado |
| --- | --- | --- |
| POC-01 | Leitura e timestamps de acelerômetro/giroscópio físicos | Pendente |
| POC-02 | Continuidade em serviço com tela apagada | Pendente |
| POC-03 | Troca de apps e restrições de bateria | Pendente |
| POC-04 | Interrupção e reconciliação operacional | Pendente |
| POC-05 | Alerta persistido de 30 s independente da tela | Pendente |
| POC-06 | Som, vibração e ações sob bloqueio | Pendente |
| POC-07 | GPS recente, antigo, impreciso e ausente | Pendente |
| POC-08 | SQLite protegido offline e recuperação | Pendente |
| POC-09 | Consumo e continuidade medidos por cenário | Pendente |
| POC-10 | Reboot sem reativação | Pendente |

Registrar aparelho, versão Android, perfil, duração, condições de energia,
amostras recebidas, lacunas e resultado. Não guardar stream bruto no histórico
do produto. Usar movimentos controlados e replay; não provocar acidentes.

O próximo incremento é uma ferramenta de ensaio isolada para leitura dos dois
sensores, seguida da escolha documentada do tipo de Foreground Service e teste
de coleta/alerta com tela bloqueada. Serviço só será integrado ao fluxo de
proteção após evidências físicas reproduzíveis.
