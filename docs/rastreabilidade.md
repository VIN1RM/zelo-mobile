# Rastreabilidade — implementação

Atualização: 7 de novembro de 2026. Estados referentes ao comportamento
implementado, não à presença de telas ou dependências.

| Requisito | Estado | Evidência / próximo aceite |
| --- | --- | --- |
| RF-001 | Implementado; validação real pendente | Cadastro Firebase, nome, senha forte e confirmação; testes de regras. |
| RF-002 | Implementado; validação real pendente | Login, verificação e guards; renovação de token testada com adaptador substituto. |
| RF-003 | Parcial | Recuperação e exibição de nome/e-mail; edição de perfil ainda pendente. |
| RF-004–007 | Pendente | Preparação, contatos e perfil. |
| RF-008–010 | Pendente | Serviço, sessões e dados offline. |
| RF-011–013 | Pendente | Alerta persistido de 30 segundos. |
| RF-014–018 | Pendente | SOS, GPS e compartilhamento assistido. |
| RF-019–022 | Pendente | Histórico, atualizações, anexos e retenção. |
| RF-023 | Pendente | Outbox e confirmação remota. |
| RF-024–026 | Pendente | Interrupção, bateria e inatividade. |
| RF-027 | Pendente | Demo isolada. |
| RF-028 | Parcial | Consulta Android de sensores/notificações/bateria, erro, retry manual e atualização ao retomar; demais ajustes pendentes. |
| RF-029–032 | Pendente | Exclusão e ciclo de vida operacional. |
| RNF-001 | Implementado em configuração | minSdk 26, compileSdk/targetSdk 36; compatibilidade física pendente. |
| RNF-002 | Baseline ajustada por ADR | Flutter 3.41.4 / Dart 3.11.1 neste ciclo. |
| RNF-003 | Parcial | Interface pt-BR, Karla local, tema claro Material 3; telas futuras pendentes. |
| RNF-009–010 | Parcial | Testes de domínio, adaptador, widgets e rotas; integração/campo e execução remota do CI pendentes. |
| RNF-017 | Parcial | Lockfile, SDK e ADR; restante da documentação evolui por incremento. |
| Demais RNFs | Pendente de implementação/validação | Não inferir atendimento a segurança e privacidade pela fundação visual. |

Critérios de aceite de produção continuam pendentes de validação integral.
Esta matriz deve ganhar evidências conforme cada fluxo for entregue.
O diagnóstico não grava nem transmite dados pessoais; autenticação usa o
Firebase configurado pelo responsável pelo projeto.
