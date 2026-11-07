# ZELO — diagnóstico e plano de implementação

## Atualização de execução — 7 de novembro de 2026

Segundo incremento: integração Firebase Android e telas T01–T06, cadastro/login,
recuperação, envio/reenvio da verificação, renovação do token e guards de acesso.
RF-003 permanece parcial porque edição de perfil ainda não foi implementada.
Não há SQLite/Outbox/Firestore neste incremento. A integração de autenticação
foi antecipada após o responsável configurar o projeto e o provedor no Firebase;
isso não aprova nem substitui a POC Android. Ver [integração Firebase](firebase-auth.md).

Primeiro incremento implementado: logo oficial e ícone adaptativo Android,
Karla local, baseline SDK versionada, min/target/compile SDK explícitos,
pipeline de checks e diagnóstico de recursos em Ajustes. O diagnóstico é parte
de RF-028; não encerra esse requisito nem aprova a POC de monitoramento.
Ver [ADR-001](adr/ADR-001-baseline-inicial.md),
[rastreabilidade](rastreabilidade.md) e [POC Android](poc-android.md).
O diagnóstico original abaixo é preservado como fotografia anterior à implementação.

Análise em 7 de novembro de 2026. Fonte de requisitos: leitura integral das
27 seções de `ZELO_Documentacao_Completa.docx`, incluindo tabelas, regras,
roadmap e matriz de rastreabilidade. Comparação com código Dart, testes,
dependências, configurações Android, README, CHANGELOG e paleta.

## Implementação na develop — terceiro incremento

O inventário e as etapas abaixo registram o diagnóstico anterior. Os fluxos
operacionais agora estão implementados em código, com SQLite/Outbox/Firestore,
serviço Kotlin, contatos, alerta, SOS, histórico, anexos e conta. Consulte o
[estado atual](estado-mvp.md) e a [ADR-002](adr/ADR-002-mvp-offline-e-servico-android.md).
O restante para lançamento envolve implantação Firestore, assinatura, política
com responsável definido, testes reais de e-mail e aceites físicos/calibração.
Não houve commit ou publicação neste incremento.

## 1. Entendimento do produto

O ZELO é um aplicativo Android de apoio experimental à segurança de
motociclistas. Uma pessoa autenticada, com e-mail verificado e pelo menos um
contato válido, inicia manualmente uma sessão com perfil Bolso ou Suporte.
Sensores são processados localmente. Um padrão suspeito inicia um alerta de
30 segundos; a pessoa pode cancelar ou pedir ajuda. Sem resposta, registra-se
uma emergência não confirmada e prepara-se ajuda assistida.

O aplicativo não envia mensagens automaticamente. Abrir WhatsApp, e-mail ou
copiar texto gera uma tentativa, sem comprovar envio ou entrega. SOS manual
funciona também fora de sessão e pode oferecer cópia ou escolha de destinatário
externo quando não houver contato cadastrado.

GPS é pontual, não uma rota: localização recente exige idade de até 60 segundos
e precisão estimada de até 100 metros. GPS ausente não impede detecção local.
Fotos permanecem locais. Firebase recebe somente os metadados previstos.
Operação crítica não depende de internet ou confirmação remota.

O documento contém 32 requisitos funcionais, 18 não funcionais, 34 regras de
negócio, 16 telas e 10 componentes/modais. Seus gates técnicos são condições
de aceite, não capacidades já comprovadas.

## 2. O que existe no repositório

| Área | Evidência | Avaliação |
| --- | --- | --- |
| Bootstrap | `lib/main.dart`, `lib/app/app.dart` | Flutter inicializado com ProviderScope e MaterialApp.router. |
| Navegação | `lib/app/router/` | Quatro abas com StatefulShellRoute.indexedStack; entrada direta em `/inicio`. |
| Identidade | `lib/app/theme/`, `paleta.md` | Cores, Material 3 claro, cards e botões alinhados à base visual. |
| Início T08 | `home_screen.dart` | Tela informativa; sem sessão, SOS operacional ou estados do serviço. |
| Contatos T11 | `contacts_screen.dart` | Placeholder; sem CRUD, prioridades ou persistência. |
| Histórico T13 | `history_screen.dart` | Placeholder; sem registros. |
| Ajustes T15 | `settings_screen.dart` | Placeholder; sem preferências, diagnóstico ou demo. |
| Estado | `pubspec.yaml`, `main.dart` | Riverpod instalado; não há providers de funcionalidades ou casos de uso. |
| Android | Manifest, Gradle e MainActivity | Estrutura Flutter; sem serviço, sensores, canais ou permissões do produto. |
| Testes | `test/widget_test.dart` | Dois testes de widget: aviso inicial e navegação ao histórico. |
| Documentação | README e CHANGELOG | Estado inicial explicado com transparência. |

Não existem implementações de autenticação, banco, Outbox, Firestore Rules,
monitoramento, detecção, emergência, GPS, anexos, retenção ou exclusão de conta.
Também não existem CI versionado, ADRs ou testes de integração no inventário.

As quatro telas presentes são estruturas de apresentação. Nenhum dos 32 RFs
deve ser considerado integralmente entregue por essa presença. A fundação
visual pode ser reaproveitada; não é necessário refazer o projeto.

## 3. Divergências e decisões a registrar

1. **Documento desatualizado quanto ao início:** o Word diz desenvolvimento
   não iniciado; a fundação já existe. Atualizar essa descrição na próxima revisão.
2. **SDK:** o cache local declara Flutter 3.41.4 e Dart 3.11.1; o documento
   planeja Flutter 3.47.x, condicionado à validação. `sdk: ^3.9.2` no pubspec
   é uma restrição de compatibilidade do Dart, não um pin de Flutter.
   Validar a baseline e fixar a versão efetivamente aprovada antes de atualizar.
3. **Android:** minSdk, targetSdk e compileSdk herdam valores do Flutter.
   Não há comprovação explícita da baseline API 26/36/36. Registrar valores
   efetivos no build; validar JDK e compatibilidade com AGP 8.9.1,
   Kotlin 2.1.0 e Gradle 8.12. O Java 11 configurado para compilação não
   identifica, por si só, a versão do JDK que executa o Gradle.
4. **Identidade:** faltam Karla local e arte Guardian Shield. O escudo Material
   na tela não substitui a arte oficial. Incorporar a arte existente.
5. **Versões:** o Word usa releases 0.x antes de 1.0 estável; README e CHANGELOG
   adotam linha de desenvolvimento 1.0.0, e pubspec contém 1.0.0+1.
   Recomendação: alinhar os documentos por ADR; usar os marcos abaixo como
   etapas até resolver a numeração, sem renumerar silenciosamente.
6. **Ordem do roadmap:** SQLite aparece no marco de histórico e Outbox no
   de sincronização. Antecipar banco e enfileiramento transacional para a
   primeira escrita de dados; implementar transporte remoto depois.
7. **Lacunas de especificação:** definir metas mensuráveis de bateria, latência
   e falsos positivos após a POC; política offline de autenticação expirada;
   recuperação de chaves; precedência de exclusão de sessões com incidentes
   preservados; preservação de sessões, cuja coluna não está explícita no
   esquema; limite/formato de fotos; projeção remota de notas e tentativas.
   Não enviar dados à nuvem por ausência de uma decisão explícita.

## 4. Sequência proposta

### Etapa 1 — Consolidar ambiente e engenharia

- Fixar SDK validado, baseline Android, lockfile e processo de build.
- Configurar CI para formatação, análise, testes e build Android.
- Adicionar fonte e identidade oficial quando os arquivos estiverem disponíveis.
- Registrar ADRs iniciais e matriz de requisitos com status e evidência.
- Criar camadas e mecanismos compartilhados somente quando usados.

**Aceite:** checkout reproduzível compila; checks passam; baseline e
divergências ficam documentadas. Sem adicionar todas as bibliotecas de uma vez.

### Etapa 2 — Provar operação Android e armazenamento protegido

Executar uma POC pequena antes de completar o catálogo de telas:

- Acelerômetro e giroscópio em aparelho real, com tela ligada e apagada.
- Serviço em primeiro plano com tipo adequado, início manual, confirmação
  operacional e tratamento de interrupção; comparar plugin com Kotlin se necessário.
- Contagem de 30 segundos independente do widget, notificação e ações com
  telefone bloqueado, som/vibração e restrições de bateria.
- Estado persistido e recuperação após queda do processo; reboot sem reativação.
- GPS recente, antigo, impreciso e indisponível, sem atrasar alerta.
- Escrita offline durável; validar SQLite criptografado, chave no Keystore e
  exclusões de backup. Medir continuidade, reação e consumo de bateria.

**Aceite:** evidências dos POC-01 a POC-10, aparelhos/versões, resultados e
limitações registrados; decisão Go/No-Go. Cobrir Android 14–16 e amostra de
anteriores conforme disponibilidade, incluindo políticas OEM distintas.
Não simular acidentes de trânsito ou quedas de motocicleta.

Android exige classificação apropriada para Foreground Services; nenhum plugin
resolve essa decisão por si só. Referência: [tipos de serviço Android](https://developer.android.com/develop/background-work/services/fgs/service-types).

### Etapa 3 — Fundação de dados e acesso

- SQLite com migrações, isolamento por UID, integridade e repositórios.
- Transação entidade + SyncOperation; transporte remoto ainda desacoplado.
- Firebase Auth: cadastro, login, recuperação, verificação e atualização do token.
- Telas T01–T06 e guards para autenticação, verificação e preparação.
- Cache mínimo de perfil; saída/troca de conta sem exposição de dados anteriores.

**Aceite:** RF-001–003; senha e e-mail validados; usuário não verificado não
acessa funções protegidas; troca de UID não revela banco ou arquivos alheios.
Falhas de rede têm comportamento explícito e testado.

### Etapa 4 — Contatos e preparação

- T07, T11 e T12: cadastrar, editar, excluir e reordenar até três contatos.
- Normalizar canais, validar nome e duplicatas; manter prioridades únicas.
- Persistir localmente e enfileirar mudanças; lembrar Bolso/Suporte.
- Solicitar permissões progressivamente e indicar sensores indisponíveis.
- Bloquear início sem contato/notificações e impedir exclusão do último contato
  durante sessão ativa, adotando essa alternativa já permitida pelo documento.

**Aceite:** RF-004–007; quarto contato e contato sem canal são rejeitados;
operações sobrevivem à reabertura offline; GPS negado aparece como limitação.

### Etapa 5 — Sessão operacional

- T08 funcional, integrado ao serviço aprovado na POC.
- Estados INACTIVE, PREPARING, ACTIVE, LIMITED, COMPLETED e INTERRUPTED.
- Uma sessão operacional local por UID; só exibir ativa após confirmação.
- Início/fim manuais, localização inicial pontual, duração e perfil efetivo.
- Avisos de bateria em 20%/10% e inatividade de 15 minutos por episódio.
- Reconciliar interrupções; encerrar sessão sem descartar emergência em curso.

**Aceite:** RF-008–010, RF-024–026, RF-030–032; sem falsa proteção ativa,
reinício automático ou encerramento automático por inatividade/bateria.

### Etapa 6 — Emergência e detecção experimental

Primeiro integrar o fluxo de alerta com eventos controlados; depois conectar
o detector calibrado. Assim é possível verificar resposta sem depender de
um algoritmo ainda não validado.

- T09/T10, alerta único e prazo persistido, com resolução atômica de corridas.
- CANCELLED, HELP_REQUESTED e TIMED_OUT sem reescrever resultado original.
- SOS manual com sessionId opcional, GPS qualificado e mensagem contextual.
- WhatsApp/e-mail/cópia com fallback e registro de tentativa sem entrega inferida.
- Motor de janelas de sensores isolado, perfis versionados e replay de amostras.
- Demo em ambiente separado, sem histórico, Outbox ou mensagens reais.

**Aceite:** RF-011–018 e RF-027; contagem sobrevive à reconstrução da tela;
GPS lento não bloqueia evento; SOS funciona fora de sessão; demo não produz
efeitos reais. Calibração e limites físicos precisam de evidência própria.

### Etapa 7 — Histórico, anexos e retenção

- T13/T14 com filtros, detalhes, condição atual e linha do tempo append-only.
- Observações, fotos locais criptografadas e exportação explícita.
- Preservação padrão de SOS/emergências não canceladas; retenção de 90 dias
  para registros comuns elegíveis, respeitando dependências preservadas.
- Exclusões locais com tombstone, limpeza de arquivos e pendência remota.

**Aceite:** RF-019–022; atualizações não apagam origem; retenção não elimina
emergências preservadas; fotos não entram em payloads de sincronização.

### Etapa 8 — Sincronização e privacidade completas

- Worker Outbox com IDs estáveis, revisões, backoff, confirmação do servidor
  e tratamento distinto de falhas temporárias, autorização e autenticação.
- Firestore Rules com UID/e-mail verificado, campos permitidos e testes no emulador.
- Conflitos de contatos/perfil explícitos; tombstones prevalecem sobre dados antigos.
- Reidratação e concorrência entre aparelhos sem prometer sessão global exclusiva.
- T15/T16: permissões, diagnóstico sanitizado, armazenamento, perfil e privacidade.
- Exclusão remota paginada e retomável; reautenticação; limpeza local e Auth
  somente na ordem que preserve capacidade de concluir o procedimento.

**Aceite:** RF-023, RF-028–029; escrita no cache Firebase não conta como confirmação
remota; conta excluída não deixa subcoleções esquecidas; falha parcial não vira sucesso.
Prototipar exclusão já na primeira integração Firestore, sem esperar esta etapa
para descobrir inviabilidade sob as restrições de infraestrutura.

Excluir documento pai não exclui subcoleções automaticamente: [documentação Firebase](https://firebase.google.com/docs/firestore/manage-data/delete-data).

### Etapa 9 — Integração e candidato a lançamento

- E2E de cadastro até ocorrência/histórico/exclusão, inclusive caminhos negativos.
- Migrações, criptografia, reinstalação, backup, perda de chave e isolamento de UID.
- Acessibilidade, texto ampliado, TalkBack, contraste e fluxo sob tela bloqueada.
- Campo controlado por aparelho/perfil; bateria, latência, falsos positivos e
  cenários simulados não detectados, com critérios registrados antes da aprovação.
- Revisão de dependências, segurança, privacidade e documentação; distribuição interna.

**Aceite:** regras críticas testadas, CI aprovado, evidência física e ausência
dos bloqueios de lançamento definidos na seção 24. Meta de cobertura de 80%
do Dart testável acompanha a qualidade; não substitui testes de comportamento.

## 5. Primeiro ciclo concreto de trabalho

1. Registrar baseline, divergências documentais e ADR de versionamento.
2. Fazer build reproduzível e configurar checks automáticos.
3. Executar POC Android com sensores, serviço, alerta persistido e armazenamento.
4. Registrar Go/No-Go e limites do conjunto de aparelhos suportado.
5. Implementar dados por UID + autenticação; depois contatos/preparação.

Não é necessário concluir Firebase ou todas as telas para provar o risco
central de execução Android. Também não é adequado implementar sessões reais
com persistência temporária apenas em memória.

Não há estimativa de prazo fechada: a POC determina a extensão de integração
nativa necessária. Após ela, decompor cada etapa em PRs pequenos e estimar com
base no ambiente e aparelhos disponíveis.

## 6. Verificação desta análise

- Código de aplicação e testes existentes lidos integralmente.
- `dart analyze lib test`: informou `No issues found!`; processo terminou com
  código 1 por acesso negado à telemetria fora do workspace. Não equivale a
  check integral aprovado no ambiente.
- `flutter --version`: não concluiu e foi interrompido; versões locais acima
  vieram de `C:/flutter/bin/cache/flutter.version.json`.
- Testes de widget, build Android, Firebase e testes físicos não executados.
- Nenhuma funcionalidade do aplicativo foi implementada nesta análise.
- O Word apareceu como arquivo não rastreado pelo Git. Durante a inspeção,
  `pubspec.lock` também apareceu modificado; essa alteração não foi revertida
  nem incorporada ao plano como atualização aprovada de dependências.
