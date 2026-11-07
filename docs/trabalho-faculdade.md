# Meu Smartphone Inteligente — ZELO

Trabalho de Flutter/Dart, 8º período. Apresentação: 10/11/2026, até 15 minutos.
Este documento entrega funcionalidades e cenários de teste. Os slides serão
preparados na próxima etapa, após os comandos do responsável.

## Onde demonstrar

Entre com uma conta verificada e abra **Ajustes → Recursos do aparelho**.
Para um ensaio sem alertas operacionais, encerre antes a proteção no início.
A tela reúne os quatro critérios, sem exigir ocorrência ou contato cadastrado:

| Critério | Como demonstrar | Implementação |
| --- | --- | --- |
| Câmera — 2,5 | Tirar foto e mostrar a imagem na própria tela | `image_picker`, câmera real; prévia temporária |
| GPS — 2,5 | Obter coordenadas, ler Latitude/Longitude e abrir o mapa | `geolocator`, captura pontual com horário e precisão |
| Notificação — 2,0 | Agendar teste, aguardar 5 segundos e abrir a barra do Android | `MethodChannel`, canal Android e `NotificationCompat` |
| Acelerômetro — 2,0 | Inclinar suavemente e mostrar X, Y e Z mudando | `SensorManager` → `EventChannel` → `StreamBuilder` |
| Organização — 1,0 | Explicar arquivos, permissões e fluxo | Feature própria, gateway, modelo e tela em pt-BR |

O teste de notificação não aciona o detector, o contador de emergência ou os
contatos. O título contém **TESTE DO ZELO — possível acidente**. Ele usa um
canal e identificador separados das notificações da proteção. Som, vibração,
pop-up e conteúdo na tela bloqueada dependem das escolhas do Android/usuário;
a confirmação principal é encontrar a notificação na barra.

A câmera exibe a foto em memória. A cópia temporária criada no cache da câmera
é removida após a leitura quando está dentro do cache privado do aplicativo.
Foto e coordenadas desta tela não vão para histórico, Outbox ou Firebase.
Para salvar fotos em uma ocorrência, o fluxo do histórico continua disponível.

## Organização do código

- `lib/features/device_resources/domain/acceleration_reading.dart`: contrato
  dos três eixos; rejeita leituras incompletas, texto e números não finitos.
- `lib/features/device_resources/data/device_resources_gateway.dart`: câmera,
  localização, solicitação de notificações e comunicação com o Android.
- `lib/features/device_resources/presentation/screens/device_resources_screen.dart`:
  quatro blocos, prévia, coordenadas e atualização dos eixos.
- `android/app/src/main/kotlin/br/com/zelo/zelo_mobile/DeviceResourcesBridge.kt`:
  listener nativo, limitação de atualização visual e notificação de teste.
- `MainActivity.kt`: registra os canais e pausa/retoma o listener no ciclo de vida.
- `lib/app/router/app_router.dart`: rota protegida `/ajustes/recursos`.

Os eixos são mostrados em m/s², incluindo gravidade; por isso um aparelho parado
pode apresentar cerca de 9,8 em um dos eixos. A visualização é limitada a até
dez atualizações por segundo e não grava amostras. Ao sair da tela ou colocá-la
em segundo plano, o listener da demonstração para. O serviço de monitoramento
operacional é separado e não é iniciado/encerrado pela demonstração.
Referência: [sensores de movimento Android](https://developer.android.com/develop/sensors-and-location/sensors/sensors_motion).

## Permissões

- **Câmera:** declarada no manifesto; `image_picker` solicita o acesso ao tirar
  foto e abre a interface de captura do aparelho. Câmera é hardware opcional.
- **Localização:** acesso durante o uso, solicitado no botão de coordenadas;
  é necessário ativar também a localização do Android. Acesso aproximado pode
  resultar em precisão menor, informada na tela.
- **Notificações:** solicitadas no botão de teste; o canal de testes também
  precisa estar habilitado. [Referência Android](https://developer.android.com/develop/ui/views/notifications/notification-permission).
- **Acelerômetro:** leitura normal, sem permissão perigosa de sensores corporais.
  Aparelho sem sensor recebe aviso e opção de nova tentativa, nunca números fictícios.

## Cenários para testar no celular

Registre modelo, Android, versão do APK, data e resultado observado. O responsável
relatou testes no **Redmi Note 9, MIUI Global 13.0.2, Android 12
(SP1A.210812.016)**: câmera com confirmação/cancelamento/nova foto, coordenadas
com mapa e cópia, notificação em primeiro plano/segundo plano/tela bloqueada e
acelerômetro ao vivo. Relatou funcionamento online e offline.

Isso confirma os fluxos principais de CT02, CT03, CT05, CT06, CT08, CT09, CT11
e CT14 nesse aparelho, com base no relato do responsável. Os demais cenários
continuam disponíveis para completar o aceite; não presumir que permissões
negadas e recuperação foram testadas apenas porque o fluxo permitido funcionou.
Não arremesse, derrube ou bata o celular; inclinações suaves bastam para os eixos.

| Caso | Passos | Resultado esperado |
| --- | --- | --- |
| CT01 — Entrada | Entrar com conta verificada; abrir Ajustes → Recursos do aparelho | Quatro blocos em português; nenhuma sessão/emergência criada pelo acesso |
| CT02 — Captura | Tocar Tirar foto; permitir câmera; capturar e confirmar | A foto aparece na tela e é possível tirar outra |
| CT03 — Cancelamento | Com foto exibida, abrir câmera e voltar sem confirmar | Sem travamento; prévia anterior preservada e cancelamento informado |
| CT04 — Câmera negada | Negar câmera; tentar novamente; autorizar nos ajustes e repetir | Mensagem compreensível; ação continua disponível; captura funciona após autorização |
| CT05 — Coordenadas | Ativar localização; obter coordenadas e autorizar acesso | Latitude e Longitude numéricas, precisão e horário; mapa aponta para o local aproximado |
| CT06 — Copiar GPS | Tocar Copiar coordenadas e colar em um campo de texto | Coordenadas e link do mapa disponíveis; nenhuma mensagem enviada automaticamente |
| CT07 — GPS indisponível | Desativar localização ou negar permissão; solicitar coordenadas | Orientação para ativar/autorizar, sem inventar posição; câmera e demais recursos continuam disponíveis |
| CT08 — Notificação | Permitir notificações; tocar Testar notificação em 5 segundos; aguardar | Aviso identificado como TESTE na barra; sem emergência e sem mensagem para contato |
| CT09 — Tela bloqueada | Agendar teste e bloquear antes de 5 segundos | Aviso disponível na barra/tela conforme configurações de bloqueio; tocar reabre o ZELO |
| CT10 — Notificação negada | Bloquear notificações ou canal de testes e tentar | Orientação em português; nenhum sucesso falso; ao reautorizar é possível repetir |
| CT11 — Três eixos | Rolar ao acelerômetro; inclinar suavemente para os lados e para frente | X, Y e Z atualizam em tempo real; unidade m/s²; gravidade não é tratada como erro |
| CT12 — Ciclo de vida | Ver eixos; minimizar/bloquear; retornar à tela | Leitura visual pausa em segundo plano e recebe dados novos ao voltar |
| CT13 — Temporários | Capturar foto e coordenadas; sair e reabrir Recursos do aparelho | Nova demonstração sem reutilizar prévia/coordenadas antigas; nada adicionado ao histórico pela tela |
| CT14 — Sem rede | Com a conta já acessível, desligar Wi-Fi/dados e testar câmera, notificação e eixos | Esses recursos locais funcionam; GPS depende de conseguir uma posição, podendo exigir local aberto/tempo para fixação |
| CT15 — Legibilidade | Aumentar texto do Android; percorrer blocos e ações | Conteúdo rolável, rótulos legíveis e controles acessíveis |

Se negar uma permissão e o Android não perguntar novamente, abra **Permissões
do aplicativo** no fim da tela. Não apague os dados nem reinstale para corrigir
permissões, pois isso pode remover registros locais do ZELO.

## Verificação automatizada

Análise estática sem problemas e 69 testes Flutter aprovados no incremento.
Os testes de câmera/GPS da interface usam adaptadores substitutos: comprovam
estados e apresentação, não substituem os ensaios físicos de permissões e hardware.
A revisão de layout cobre a nova tela em tamanho normal e texto em 200%.

```sh
flutter analyze
flutter test
flutter test integration_test/device_resources_test.dart -d emulator-5554
flutter build apk --debug --target-platform android-arm64
```

O teste de integração Android usa o sensor real do emulador e uma notificação
local real; não faz login, não acessa Firestore, não abre a câmera e não envia
e-mail/WhatsApp. Sua notificação é removida ao terminar. O emulador deve ter
acelerômetro e permissão de notificações habilitados.

Resultado deste incremento: integração aprovada no emulador Android API 35.
Foram recebidas três leituras finitas, confirmada a pausa nativa do sensor em
segundo plano e verificada a notificação ativa no Android após o prazo. A
notificação de teste foi removida ao concluir. A captura de foto e a obtenção
de coordenadas no celular foram posteriormente confirmadas pelo responsável,
conforme registro acima. Negação de permissões e recuperação ainda não têm
confirmação física registrada.

Os slides e o ensaio final de até 15 minutos são a etapa seguinte. Não é
necessário concluir assinatura de loja ou homologação comercial para demonstrar
os quatro critérios acadêmicos, mas o APK deve ser testado no aparelho escolhido.
