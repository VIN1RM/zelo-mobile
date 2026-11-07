# ADR-001 — Baseline inicial de implementação

Data: 2026-11-07. Estado: adotado para o primeiro ciclo; validação física pendente.

## Contexto

O planejamento menciona Flutter 3.47.x condicionado à instalação e validação.
O ambiente disponível executa Flutter 3.41.4 e Dart 3.11.1. A navegação já usa
Riverpod e GoRouter, com lockfile resolvido nesse ambiente. A aplicação está
na linha de desenvolvimento 1.0.0+1 conforme README e CHANGELOG.

## Decisão

- Fixar Flutter 3.41.4 em `.flutter-version` e fazer CI ler esse arquivo.
  Atualizações futuras devem trazer evidência de compatibilidade e revisão deste ADR.
- Manter versão do produto 1.0.0+1 como desenvolvimento não lançado; as
  etapas do plano não são tags de releases publicadas. Não declarar estabilidade.
- Fixar Android minSdk 26, compileSdk 36 e targetSdk 36. CI usa JDK 17;
  ambiente local usa JDK 21 do Android Studio. Compatibilidade exige build.
- Reaproveitar arquitetura existente e adicionar camadas conforme necessidade.
- Incorporar a arte original sem redesenho e Karla local com licença OFL.
- Diagnóstico consulta disponibilidade de recursos por MethodChannel; não
  coleta amostras, não inicia serviço e não declara prontidão operacional.
- Desabilitar Android Auto Backup desde a fundação. Dados e chaves futuros
  exigirão revisão também das regras de transferência entre dispositivos.

## Consequências

A baseline é reproduzível sem antecipar uma migração de SDK. O diagnóstico
permite iniciar inspeção no aparelho, mas não aprova os POC-01–10. Serviço em
segundo plano, criptografia, contagem persistida e calibração continuam pendentes.
A pipeline versionada só estará aprovada no GitHub após sua execução remota.
