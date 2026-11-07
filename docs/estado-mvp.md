# Estado do MVP — 7 de novembro de 2026

Implementação de desenvolvimento na branch `develop`, sem commit ou publicação.
O código cobre os fluxos do MVP. Isso não equivale à aprovação para uso real:
o detector é experimental e os gates de produção abaixo continuam abertos.

## Funcionalidades implementadas

- Conta Firebase por e-mail/senha, verificação, recuperação, edição do nome,
  reautenticação e exclusão retomável da conta.
- Preparação com permissões contextuais e diagnóstico; até três contatos,
  prioridades, edição, exclusão e abertura de mensagem de teste.
- Sessão iniciada manualmente, perfis Bolso/Suporte, serviço foreground Android,
  sensores locais e estados confirmados pelo serviço. Falha ou interrupção não
  aparece como proteção ativa. Não há reinício automático após reboot.
- Detector experimental de impacto, rotação e imobilidade; alerta persistido de
  30 segundos, cancelamento, pedido de ajuda e resolução por ausência de resposta.
  O relógio do alerta usa tempo monotônico enquanto o serviço está vivo.
- SOS manual inclusive sem sessão ou contato, GPS pontual opcional, mensagem
  qualificada e abertura assistida de WhatsApp/e-mail ou cópia. Não existe envio
  automático nem comprovação de entrega. SOS não espera sincronização.
- Histórico de sessões/ocorrências, filtros, atualização de condição sem apagar
  o resultado original, notas locais, preservação, exportação e exclusão.
- Fotos locais criptografadas, até dez por ocorrência e 10 MB por arquivo;
  retenção de registros encerrados não preservados por 90 dias.
- SQLite criptografado, isolamento por UID, Outbox transacional, revisões,
  conflitos explícitos, tombstones e sincronização de metadados com Firestore.
- Avisos de bateria/inatividade, demonstração isolada, diagnóstico local
  sanitizado, privacidade, licenças e telas de sincronização e conta.

## Arquitetura e decisões

Ver [ADR-002](adr/ADR-002-mvp-offline-e-servico-android.md). O núcleo compartilhado
está em `lib/core`; telas e adaptadores permanecem organizados por funcionalidade.
O serviço Kotlin opera sem depender do isolate Flutter. Seu journal privado,
criptografado pelo Android Keystore, entrega eventos duráveis ao SQLite e só os
remove após confirmação da transação local. Alertas e recibos são separados por UID.

SQLCipher usa senha aleatória de instalação guardada em armazenamento seguro.
Fotos usam AES-GCM com autenticação do UID, ocorrência e anexo. Backup Android
de dados do aplicativo está desabilitado. Não se armazenam amostras brutas dos
sensores nem rotas contínuas. Notas, fotos e tentativas de compartilhamento não
são sincronizadas. Logs locais têm códigos permitidos, limite e retenção curta.

O detector `experimental-v1` usa limiares iniciais diferentes por posição.
Testes sintéticos demonstram a máquina de estados; não medem sensibilidade,
especificidade, falsos positivos ou consumo em trânsito.

A exclusão exige reautenticação e confirmação remota. Um marcador mínimo em
`account_deletions/{uid}` permanece para impedir que tokens antigos recriem
dados. Essa exceção é informada na interface e precisa constar na política final.

## Evidências executadas localmente

- 44 testes Dart de domínio, repositório, controle, rotas, widgets, texto
  ampliado e acessibilidade aprovados; análise estática sem ocorrências.
- Oito testes das Firestore Rules em emulador: isolamento, verificação de e-mail,
  contatos, revisões, imutabilidade, exclusão e impedimento de recriação.
- Três testes JVM da máquina de detecção, sem sensores reais.
- Integração Android/API 35: SQLCipher e rejeição de chave incorreta, sensores,
  alerta persistido, aplicativo em segundo plano, timeout, encerramento e recibos.
- Integração com Auth/Firestore locais: e-mail verificado no emulador, Outbox,
  três contatos, reordenação, conflito, repetição idempotente, tombstone e exclusão.
- Auditoria npm das ferramentas de regras sem vulnerabilidades conhecidas na
  execução. Isso não substitui uma revisão de segurança independente.
- Compilação/minificação release executada com R8 compatível; empacotamento
  interrompido por ausência da chave própria. Não foi produzido release assinado.
  O lint das dependências ainda emite diagnóstico de metadados Kotlin 2.4;
  revisar a baseline das ferramentas antes da homologação de distribuição.

As integrações usam contas fictícias e emuladores. Nenhuma mensagem real foi
enviada. O CI foi configurado; sua execução remota depende de envio posterior.
Na repetição final, o teste Android também confirmou que limpar outro UID não
remove o alerta do proprietário. A integração Firebase revelou uma corrida do
adaptador ao propagar erros de transação; a classificação do erro de domínio
foi preservada e o mesmo teste passou após a correção.

O emulador tinha pouco espaço. Durante o ajuste inicial de ABI/versionamento,
o instalador Flutter reinstalou o pacote e limpou seus dados locais no emulador.
Não houve exclusão de contas de produção. Nas verificações seguintes foi usado
ajuste temporário da reserva de armazenamento, restaurado em `finally`, e os
pacotes foram padronizados no mesmo versionCode para evitar downgrade.

## Gates para lançamento

1. **Firestore de produção:** a consulta retornou API desativada/não utilizada.
   Ainda é necessário escolher a região, criar o banco e publicar as regras.
   Nenhuma dessas alterações foi executada em produção. A escolha de região
   deve ser deliberada; não é determinada pelo arquivo de configuração local.
2. **Aparelhos físicos:** testar API mínima/atual, tela bloqueada, economia de
   bateria, fabricantes, encerramento do processo, permissões, aquecimento e
   consumo. Calibrar e aceitar formalmente o detector com dados controlados.
3. **E-mail e compartilhamento reais:** validar entrega de verificação e
   recuperação, links e abertura dos aplicativos de destino com contas de teste.
4. **Privacidade:** nome/razão social e e-mail público ainda não definidos pelo
   responsável. A tela atual é informativa de desenvolvimento; não representa
   uma política pública final aprovada.
5. **Distribuição:** fornecer chave de assinatura própria, configurar
   `android/key.properties` a partir do exemplo e validar APK/AAB de produção.
   Release não usa assinatura debug. Preparar ficha e declarações da loja.

Não considerar o app “100% pronto para lançamento” antes desses aceites.

## Reproduzir verificações

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
python tools/check_secrets.py
cd android
./gradlew :app:testDebugUnitTest
```

No Windows, usar `gradlew.bat`. O Gradle requer JDK compatível; o emulador
Firestore atual requer Java 21. Para as regras, instalar dependências com
`npm ci` em `tools/firestore` e usar o comando do workflow. As integrações
Flutter exigem dispositivo Android; a integração Firebase também exige os
emuladores de Auth e Firestore, nunca o projeto de produção.

```sh
flutter test integration_test/android_runtime_test.dart -d emulator-5554
firebase emulators:exec --project demo-zelo --only auth,firestore "flutter test integration_test/firebase_sync_test.dart -d emulator-5554"
flutter build apk --debug --target-platform android-arm64
```

O APK debug é exclusivamente de desenvolvimento. Build de integração não deve
ser distribuído como aplicativo principal.

Pacotes principais gerados neste ciclo: `build/deliverables/zelo-development-arm64.apk`
e `build/deliverables/zelo-development-x86_64.apk`. São artefatos locais ignorados
pelo Git, com entrada `lib/main.dart`, sem commit ou publicação.
