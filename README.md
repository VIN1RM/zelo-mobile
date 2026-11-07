# ZELO

Aplicativo Android de apoio experimental à segurança de motociclistas.
Uma sessão iniciada pelo usuário analisa movimentos localmente, apresenta
alerta de 30 segundos diante de padrão suspeito e facilita ajuda assistida.

**Estado: MVP de desenvolvimento, ainda sem aceite para lançamento.** A versão
`1.0.0+1` é a meta do produto. O detector não foi calibrado em aparelhos físicos.
Consulte o [relatório atual e os gates de produção](docs/estado-mvp.md).

## Implementado

- Conta por e-mail/senha, verificação, recuperação, perfil e exclusão retomável.
- Preparação, diagnóstico e até três contatos com prioridade e teste assistido.
- Serviço Android foreground, perfis Bolso/Suporte, sensores e alerta durável.
- SOS manual, GPS pontual opcional e abertura de WhatsApp/e-mail ou cópia.
- Histórico, atualizações, notas, preservação, fotos locais e exportação.
- SQLCipher, Outbox, sincronização de metadados, conflitos e tombstones.
- Avisos operacionais, demonstração isolada, ajustes, privacidade e licenças.

Abrir um destino não comprova envio ou entrega. Não há chamada automática,
GPS contínuo ou garantia de detecção. O ZELO é uma ferramenta auxiliar e
experimental; não substitui equipamentos e práticas de segurança.

Fotos e notas ficam no aparelho. Firestore recebe metadados autorizados pelas
regras. A exclusão mantém um marcador mínimo por UID para impedir recriação
por tokens antigos, conforme [ADR-002](docs/adr/ADR-002-mvp-offline-e-servico-android.md).

## Desenvolvimento

Baseline Flutter **3.41.4**, Dart **3.11.1**, Android API 26+, compile/target 36.
Riverpod/GoRouter, Firebase Auth/Firestore, SQLCipher e serviço Kotlin.
O escopo suportado neste ciclo é Android.

```sh
flutter pub get
flutter run -d <android-device>
```

`android/app/google-services.json` corresponde ao pacote
`br.com.zelo.zelo_mobile`. Authentication por e-mail/senha foi habilitado pelo
responsável. **Firestore de produção ainda precisa de região, banco e regras.**
Os testes locais de backend usam exclusivamente o projeto demo dos emuladores.

```text
lib/app/        bootstrap, tema, rotas e coordenação de alertas
lib/core/       banco, repositório, controle, plataforma e sincronização
lib/features/   autenticação, contatos, monitoramento, emergência,
                histórico, preparação, perfil e ajustes
android/app/src/main/kotlin/   serviço, detector e journal criptografado
test/           domínio, repositório, controle, widgets e acessibilidade
integration_test/             Android e Firebase em emuladores
tools/firestore/              testes das regras
```

## Verificações

```sh
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze
flutter test
python tools/check_secrets.py
flutter build apk --debug --target-platform android-arm64
```

Com JDK configurado, executar `gradlew.bat :app:testDebugUnitTest` em `android`
(Linux: `./gradlew`). Regras e integrações: [instruções e evidências](docs/estado-mvp.md).
O CI em `.github/workflows/flutter.yml` cobre checks Flutter, build debug,
testes JVM e regras em emulador. Execução remota depende de envio posterior.

Release exige chave própria em `android/key.properties`, conforme o exemplo.
Não versionar esse arquivo nem o keystore. Não há fallback para assinatura debug.

## Antes de lançar

Ainda faltam implantação Firestore, calibração e ensaios físicos, aceites de
e-mail/compartilhamento reais, identidade e contato na política de privacidade
e assinatura de distribuição. Ver [estado do MVP](docs/estado-mvp.md),
[POC Android](docs/poc-android.md), [planejamento](docs/plano-implementacao.md)
e [rastreabilidade](docs/rastreabilidade.md).

Mudanças no [CHANGELOG](CHANGELOG.md). Paleta em [paleta.md](paleta.md).
