# ZELO

Aplicativo Android para apoio experimental à segurança de motociclistas.

## Estado atual

Esta versão inicia a fundação do aplicativo: tema baseado em `paleta.md`,
navegação principal e estrutura inicial organizada por funcionalidades. As
telas de contatos, histórico e ajustes são marcadas como em desenvolvimento.
O app ainda não monitora trajetos nem envia pedidos de ajuda.

## Estrutura Flutter

```text
lib/
  app/
    router/      # Rotas e navegação principal
    theme/       # Cores e tema Material 3
  features/
    home/        # Início
    contacts/    # Contatos de emergência
    history/     # Histórico
    settings/    # Ajustes
  shared/
    widgets/     # Componentes compartilhados
  main.dart      # Inicialização do app e Riverpod
test/
```

Novos módulos devem seguir a organização por feature da documentação do
projeto, acrescentando camadas de domínio, aplicação e dados quando suas
funcionalidades forem implementadas.

## Executar

Com o Flutter instalado:

```sh
flutter pub get
flutter run -d <android-device>
```

## Validar

```sh
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```
