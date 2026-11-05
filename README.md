# ZELO

O ZELO é um aplicativo Android em desenvolvimento para motociclistas. Seu
objetivo é oferecer uma camada auxiliar e experimental de segurança: monitorar
movimentos do celular durante uma sessão iniciada pelo usuário, identificar
padrões compatíveis com possíveis acidentes e facilitar um pedido de ajuda
assistido.

> **Estado do projeto:** desenvolvimento inicial. A versão `1.0.0` é a meta do
> MVP, não um lançamento estável. O app ainda não monitora trajetos, detecta
> acidentes nem envia pedidos de ajuda.

## Proposta do MVP

O escopo planejado para a primeira versão inclui:

- Cadastro e acesso com e-mail, verificação de endereço e recuperação de senha.
- Até três contatos de emergência, com prioridade configurável.
- Monitoramento voluntário, iniciado e encerrado manualmente, com perfis
  “Bolso” e “Suporte”.
- Análise experimental local dos sensores do Android e alerta com contagem de
  30 segundos.
- SOS manual e preparação de mensagens para compartilhamento pelo usuário.
- Histórico local de sessões e ocorrências, com atualizações e fotos mantidas
  no dispositivo.
- Armazenamento local offline-first e sincronização de metadados quando
  disponível.

Esses itens descrevem o produto planejado; ainda precisam ser implementados e,
quando aplicável, validados em aparelhos Android reais.

## Segurança e limitações

O ZELO é uma ferramenta auxiliar e experimental. Não substitui capacete,
direção defensiva, serviços de emergência ou o apoio de outras pessoas. O app
não promete detectar todos os acidentes nem funcionar continuamente em todos
os aparelhos e condições.

Mensagens de WhatsApp ou e-mail exigirão uma ação do usuário. Abrir outro
aplicativo ou copiar uma mensagem não comprova envio ou entrega. O produto não
inclui chamada automática para serviços de emergência nem rastreamento GPS
contínuo.

## Estado da implementação

A base atual contém:

- Inicialização Flutter com Riverpod.
- Navegação principal entre Início, Contatos, Histórico e Ajustes.
- Tema Material 3 baseado na [paleta da aplicação](./paleta.md).
- Telas iniciais que identificam explicitamente as funcionalidades ainda não
  disponíveis.

Contatos, histórico e ajustes ainda são telas informativas. A proteção não
pode ser ativada nesta versão.

## Tecnologias e organização

- **Plataforma do MVP:** Android.
- **Interface:** Flutter e Dart.
- **Estado e rotas:** Riverpod e GoRouter.
- **Arquitetura planejada:** Feature-First com Clean Architecture pragmática.
- **Persistência e serviços planejados:** SQLite local, Outbox e Firebase
  Authentication/Cloud Firestore, sujeitos aos gates técnicos da documentação.

```text
lib/
  app/
    router/                 # Rotas e navegação principal
    theme/                  # Cores e tema Material 3
  features/
    home/                   # Início
    contacts/               # Contatos de emergência
    history/                # Histórico
    settings/               # Ajustes
  shared/
    widgets/                # Componentes compartilhados
  main.dart                 # Inicialização do app
test/                       # Testes de widgets
```

Quando uma funcionalidade for implementada, sua feature deverá receber as
camadas necessárias de apresentação, aplicação, domínio e dados. Não é
necessário criar diretórios vazios para partes ainda não iniciadas.

## Requisitos para desenvolvimento

- Flutter compatível com a restrição Dart definida em `pubspec.yaml`.
- Android SDK e um emulador ou dispositivo Android para executar o app.

O projeto também contém diretórios de plataforma gerados pelo Flutter, mas o
escopo atual do produto é Android.

## Executar

Na raiz do projeto:

```sh
flutter pub get
flutter run -d <android-device>
```

Para listar os dispositivos disponíveis:

```sh
flutter devices
```

## Verificações

```sh
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
```

## Versionamento e histórico

O projeto inicia a linha de versão `1.0.0` para o MVP. A numeração não indica
que o app esteja pronto ou lançado: a versão estável só deverá ser considerada
após a implementação e aprovação dos critérios de operação, segurança,
privacidade, testes e validação física descritos no planejamento.

As mudanças relevantes são registradas no [CHANGELOG](./CHANGELOG.md), seguindo
o formato do [Keep a Changelog](https://keepachangelog.com/pt-BR/0.3.0/).
