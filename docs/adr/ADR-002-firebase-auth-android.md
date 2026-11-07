# ADR-002 — Integração inicial de autenticação Firebase

Data: 2026-11-07. Estado: implementado; aceite com e-mail real pendente.

## Contexto

O responsável configurou o projeto Firebase, o aplicativo Android e o provedor
E-mail/senha. A autenticação pode ser integrada antes da POC física, sem alterar
as condições de aceite de monitoramento e detecção.

## Decisão

- Usar os SDKs oficiais Firebase Core/Auth com versões resolvidas no lockfile.
- Inicializar com recursos Android gerados a partir de `google-services.json`;
  não habilitar outras plataformas ou produtos Firebase neste incremento.
- Isolar Firebase em um adaptador do contrato AuthRepository. Regras de entrada
  e reenvio ficam na aplicação/domínio; widgets coordenam formulários e estado.
- Manter a mesma instância do GoRouter e atualizá-la pelo stream de sessão,
  sem reconstruir o roteador a cada mudança de autenticação.
- Consultar verificação no SDK e renovar o token; não usar preferência local
  para liberar acesso. Sessão desconhecida, com erro ou sem e-mail verificado
  não acessa as abas protegidas. Invalidade detectada encerra a sessão SDK.
- Aplicar intervalo local de 60 segundos por UID para reenvio; os limites reais
  do provedor continuam obrigatórios e não dependem desse contador.
- Preservar uma conta criada quando uma etapa posterior falhar, permitindo
  reenvio em vez de repetir criação ou anunciar sucesso integral.
- Atualizar Kotlin para 2.4.21, pois Firebase Auth Android 25.0.0 falhou com o
  compilador 2.1.0 por incompatibilidade de metadados. Migrar compilerOptions.

## Limites

Não há Firestore, cache SQLite, edição/exclusão de perfil, exclusão de conta ou
prova física de sensores nesta alteração. Antes de lançar, validar o conjunto
Android também em release com shrinking e assinatura própria, e executar o
roteiro de e-mail real. Testes automatizados não usam contas de produção.
