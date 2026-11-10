# ZELO

Aplicativo Android de apoio à segurança de motociclistas, desenvolvido em Flutter e Kotlin.
O usuário inicia a proteção, recebe alertas de movimentos suspeitos e escolhe como pedir ajuda.

A detecção é experimental. O aplicativo não confirma acidentes nem envia mensagens automaticamente.

## Funcionalidades

- Cadastro, login, verificação de e-mail, recuperação de senha e gerenciamento da conta.
- Até três contatos de confiança, com contato principal, edição e teste dos canais.
- Checklist de contatos, sensores e permissões antes do trajeto.
- Monitoramento Android com posições Bolso/Suporte, alerta de 30 segundos e SOS manual.
- Ajuda assistida por WhatsApp, e-mail ou cópia, com localização pontual quando disponível.
- Histórico com busca, filtros por tipo e período, condição atual, observações, fotos e exportação.
- Lembretes opcionais por dias e horários, salvos neste aparelho.
- Dados locais protegidos e sincronização de metadados com Firebase.
- Tema claro/escuro automático, diagnóstico do aparelho, demonstração e licenças.

Fotos e observações permanecem no aparelho. Os lembretes não iniciam a proteção e podem
sofrer atrasos pelas restrições de bateria do Android.

## Executar

Requisitos: Flutter na versão de [.flutter-version](.flutter-version), Android SDK,
JDK compatível e aparelho ou emulador Android API 26+.

1. Configure Firebase Authentication com e-mail/senha e Cloud Firestore para o pacote `br.com.zelo.zelo_mobile`.
2. Coloque a configuração Android em `android/app/google-services.json`.
3. Configure o backend com [firestore.rules](firestore.rules) e [firestore.indexes.json](firestore.indexes.json).
4. Execute:

```sh
flutter pub get
flutter run -d <android-device>
```

## Validar e gerar APK

```sh
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

O APK fica em `build/app/outputs/flutter-apk/app-debug.apk`.
Para os testes nativos, execute `./gradlew :app:testDebugUnitTest` em `android`
(`gradlew.bat :app:testDebugUnitTest` no Windows).

Release exige assinatura própria, conforme [android/key.properties.example](android/key.properties.example).
Não versione credenciais de assinatura ou keystores.

## Estrutura

- `lib/app`: inicialização, navegação e temas.
- `lib/core`: banco local, controle da aplicação e sincronização.
- `lib/features`: telas e regras por funcionalidade.
- `lib/shared`: componentes reutilizáveis.
- `android/app/src/main/kotlin`: monitoramento, sensores e lembretes nativos.
- `test` e `integration_test`: testes automatizados.

Mudanças em [CHANGELOG.md](CHANGELOG.md).
