# Changelog

Todas as mudanças notáveis deste projeto serão documentadas neste arquivo.

O formato segue o [Keep a Changelog](https://keepachangelog.com/pt-BR/0.3.0/),
e o projeto inicia a linha de desenvolvimento da versão `1.0.0`.

> `1.0.0` é a meta do MVP e ainda não representa um lançamento estável. Os
> critérios de lançamento definidos no planejamento precisam ser atendidos
> antes da publicação.

## [Não lançado]

### Adicionado

- MVP operacional de desenvolvimento: contatos, preparação, sessões Android,
  detector experimental, alerta persistido e SOS com compartilhamento assistido.
- SQLCipher, journal nativo criptografado, GPS pontual e fotos locais AES-GCM.
- Histórico, preservação, retenção, notas, anexos, exportação e tombstones.
- Outbox, sincronização Firestore com revisões e conflitos explícitos, Rules
  e testes locais de isolamento, idempotência e exclusão.
- Perfil, exclusão retomável com bloqueio de recriação, privacidade, demo e logs.
- Integrações Android/Firebase em emuladores, testes JVM e acessibilidade.
- Assinatura release própria obrigatória e exemplo de configuração sem segredos.
- ADR-002 e relatório do MVP com gates de produção ainda pendentes.

- Firebase Core/Auth e configuração Google Services para Android.
- Telas de boas-vindas, cadastro, entrada, recuperação e verificação de e-mail.
- Guards de autenticação/verificação, atualização do token e saída da conta.
- Validação de senha e intervalo de reenvio; tratamento seguro de erros de acesso.

- Logo oficial no aplicativo e no ícone adaptativo Android.
- Fonte Karla local com licença e tema de formulários.
- Diagnóstico Android de sensores, notificações e otimização de bateria.
- Baseline Flutter versionada e pipeline de formatação, análise, testes e APK.
- ADR inicial e acompanhamento da prova técnica Android.

- Estrutura inicial Flutter organizada por funcionalidades.
- Navegação principal para Início, Contatos, Histórico e Ajustes.
- Tema Material 3 com as cores definidas em `paleta.md`.
- Telas operacionais com estado confirmado pelo Android e SOS assistido.
- Testes de widgets para a tela inicial e navegação.
- README com visão geral, escopo planejado, limitações e instruções de
  desenvolvimento.

### Alterado

- Kotlin atualizado para 2.4.21, necessário para os metadados do Firebase Auth atual.
- Configuração Kotlin migrada para `compilerOptions`.
