# ZELO

Aplicativo Android de apoio experimental à segurança de motociclistas.
Uma sessão iniciada pelo usuário analisa movimentos localmente, apresenta
alerta de 30 segundos diante de padrão suspeito e facilita ajuda assistida.

**Estado: MVP de desenvolvimento, ainda sem aceite para lançamento.** A versão
`1.0.0+1` é a meta do produto. O detector não foi calibrado em aparelhos físicos.
Consulte o [relatório atual e os gates de produção](docs/estado-mvp.md).

Para a atividade **Meu Smartphone Inteligente**, os quatro recursos obrigatórios
estão implementados. O responsável confirmou seu funcionamento no Redmi Note 9,
MIUI Global 13.0.2, Android 12, online e offline. Isso valida os fluxos principais
nesse aparelho; não representa calibração do detector ou homologação comercial.

## Implementado

- Conta por e-mail/senha, verificação, recuperação, perfil e exclusão retomável.
- Preparação, diagnóstico e até três contatos com prioridade e teste assistido.
- Serviço Android foreground, perfis Bolso/Suporte, sensores e alerta durável.
- SOS manual, GPS pontual opcional e abertura de WhatsApp/e-mail ou cópia.
- Histórico, atualizações, notas, preservação, fotos locais e exportação.
- SQLCipher, Outbox, sincronização de metadados, conflitos e tombstones.
- Avisos operacionais, demonstração isolada, ajustes, privacidade e licenças.
- Recursos do aparelho: câmera com prévia, latitude/longitude, notificação local
  de teste e acelerômetro X/Y/Z ao vivo para a atividade acadêmica.

Roteiro dos quatro critérios e testes no celular: [trabalho da faculdade](docs/trabalho-faculdade.md).

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
responsável. O responsável também criou o Firestore, publicou as regras e
confirmou sincronização com registros visíveis no console. A homologação
completa de produção continua separada dos testes acadêmicos.
Os testes locais de backend usam exclusivamente o projeto demo dos emuladores.

```text
lib/app/        bootstrap, tema, rotas e coordenação de alertas
lib/core/       banco, repositório, controle, plataforma e sincronização
lib/features/   autenticação, contatos, monitoramento, emergência,
                histórico, preparação, perfil, ajustes e recursos do aparelho
lib/shared/     ícones, rótulos pt-BR e componentes reutilizáveis
android/app/src/main/kotlin/   serviço, detector, journal e canais de recursos
test/           domínio, repositório, controle, widgets e acessibilidade
integration_test/             Android e Firebase em emuladores
tools/firestore/              testes das regras
```

## Verificações

Última execução de implementação: análise estática limpa, **69 testes Flutter**
aprovados e integração de recursos nativos aprovada no emulador Android API 35.
Os testes automatizados de câmera/GPS usam adaptadores substitutos; a confirmação
física desses recursos foi relatada pelo responsável no aparelho abaixo.

| Recurso | Resultado informado pelo responsável no Redmi Note 9 |
| --- | --- |
| Câmera | Captura, confirmação, cancelamento e nova foto funcionando |
| GPS | Coordenadas, localização no mapa e cópia funcionando |
| Notificação local | Funcionando em primeiro plano, segundo plano e tela bloqueada |
| Acelerômetro | X, Y e Z atualizando ao movimentar o aparelho |
| Rede | Quatro recursos relatados como funcionando online e offline |

Permissões negadas e sua recuperação ainda precisam de confirmação no aparelho.
O [roteiro de testes](docs/trabalho-faculdade.md) distingue esses casos dos fluxos
já confirmados. Slides e ensaio de até 15 minutos são a próxima etapa acadêmica.

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

## APK para testar no celular

Para o Redmi Note 9 usado nos testes, gere o pacote **ARM64**:

```sh
flutter build apk --debug --target-platform android-arm64
```

O resultado fica em `build/app/outputs/flutter-apk/app-debug.apk`. O pacote de
entrega deste incremento também está em `build/deliverables/zelo-faculdade-arm64.apk`,
quando disponível no workspace. Arquivos de `build/` não são versionados.

Ao gerar depois um APK `android-x64` para emulador, o caminho padrão
`app-debug.apk` é sobrescrito pelo pacote do emulador. Confira a arquitetura
ou gere ARM64 novamente antes de copiar para o celular. O comando sem `--debug`
gera release e exige a chave de produção configurada.

## Antes de lançar

Ainda faltam calibração e ensaios físicos abrangentes, homologação dos fluxos
de conta e compartilhamento, identidade e contato na política de privacidade
e assinatura de distribuição. Ver [estado do MVP](docs/estado-mvp.md),
[POC Android](docs/poc-android.md), [planejamento](docs/plano-implementacao.md)
e [rastreabilidade](docs/rastreabilidade.md).

Mudanças no [CHANGELOG](CHANGELOG.md). Paleta em [paleta.md](paleta.md).
