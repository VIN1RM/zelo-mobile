# Rastreabilidade — implementação de desenvolvimento

Atualização: 7 de novembro de 2026. “Implementado” refere-se ao código e à
evidência indicada, não à aprovação de produção. Os gates estão no
[relatório do MVP](estado-mvp.md).

| Requisito | Estado / evidência | Aceite restante |
| --- | --- | --- |
| RF-001–002 | Auth, verificação, guards; testes e integração local | Entrega real de e-mail e conta real de teste |
| RF-003 | Recuperação, perfil e edição do nome | Fluxo real de recuperação |
| RF-004–007 | Preparação, contatos, prioridades e posição | Permissões e destinos em aparelho físico |
| RF-008–010 | Serviço nativo, sessões e SQLCipher; integração API 35 | Matriz de fabricantes, consumo e calibração |
| RF-011–013 | Alerta persistido, resolução e timeout; integração em segundo plano | Tela bloqueada e morte de processo em aparelhos físicos |
| RF-014–018 | SOS independente, GPS qualificado e compartilhamento assistido | GPS/destinos reais, sem afirmar entrega |
| RF-019–022 | Histórico, atualizações, notas, anexos e retenção | Galeria/câmera e revisão dos prazos no aparelho |
| RF-023 | Outbox, CAS, conflitos, tombstones; integração Auth/Firestore | Criar banco e publicar regras em produção |
| RF-024–026 | Interrupção, bateria e inatividade no serviço | Ensaios físicos prolongados |
| RF-027 | Demonstração isolada | Aceite de UX |
| RF-028 | Diagnóstico, permissões, sync, privacidade e licenças | Nome e contato públicos ainda indefinidos |
| RF-029–032 | Exclusão retomável, bloqueios e ciclo de vida | Revisão física e política final; marcador técnico retido por ADR |
| RNF-001–002 | API 26/36, baseline Flutter/Dart e Gradle | Matriz de compatibilidade física e release assinado |
| RNF-003 | Interface pt-BR/Karla/Material 3, teste de texto ampliado | Auditoria de acessibilidade completa |
| RNF-009–010 | Testes Dart, JVM, regras e duas integrações locais | CI remoto, regressão física e aceite do produto |
| RNF-017 | ADRs, lockfiles, instruções e relatório atualizados | Manutenção contínua das evidências |
| Demais RNFs | Mecanismos de offline, criptografia e privacidade implementados | Revisão de segurança, desempenho, consumo e privacidade de produção |

O banco físico usa envelope tipado, conforme ADR-002. A exclusão retém um
marcador pseudônimo para bloquear recriação. Ambas são decisões explícitas
em relação ao modelo original, sujeitas ao aceite do responsável.

Não há evidência de acurácia do detector, entrega de ajuda, funcionamento
ininterrupto ou homologação em trânsito. Os resultados dos emuladores não
permitem declarar esses critérios atendidos.
