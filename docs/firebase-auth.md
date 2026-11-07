# Firebase Authentication — implementação Android

## Configuração

O responsável criou o projeto `zelo-mobile-73335`, cadastrou o aplicativo
`br.com.zelo.zelo_mobile`, forneceu `android/app/google-services.json` e
habilitou o provedor E-mail/senha no console.

O arquivo é consumido pelo plugin Gradle Google Services 4.5.0. O bootstrap
inicializa `Firebase.initializeApp()` usando os recursos nativos Android;
não há configuração web/iOS nem instalação global do FlutterFire CLI.
Falha de inicialização mantém uma tela de erro com nova tentativa, sem abrir
as áreas protegidas. E-mails são solicitados em português brasileiro.

Dependências resolvidas: `firebase_core` 5.1.0 e `firebase_auth` 7.0.1.
Kotlin foi atualizado de 2.1.0 para 2.4.21 após o primeiro build identificar
metadados 2.4 no Firebase Auth Android 25.0.0. A configuração do compilador
migrou de `kotlinOptions` para `compilerOptions`.

Referências: [Firebase Android](https://firebase.google.com/docs/android/setup),
[acesso por senha](https://firebase.google.com/docs/auth/flutter/password-auth),
[gerenciamento de usuários](https://firebase.google.com/docs/auth/flutter/manage-users),
[compatibilidade Kotlin/Gradle](https://kotlinlang.org/docs/gradle-configure-project.html).

## Comportamento entregue

- Abertura com restauração da sessão e roteamento; erro de stream bloqueia acesso.
- Boas-vindas explicando capacidades planejadas e limites atuais.
- Cadastro com nome, e-mail, senha e confirmação.
- Senha com 8 caracteres mínimos, maiúscula, minúscula, número e símbolo.
- Login por e-mail/senha; campos ficam desabilitados durante solicitações.
- Recuperação com confirmação neutra para conta existente, inexistente ou desabilitada.
- Verificação por link; envio inicial após cadastro e reenvio com intervalo local
  de 60 segundos por UID, além dos limites aplicados pelo Firebase.
- “Já verifiquei” consulta o SDK e força renovação do token; não altera flag local.
- Rotas diretas e navegação protegidas para contas autenticadas e verificadas.
- Nome/e-mail em Ajustes e saída com confirmação.

Se a criação de conta terminar e o envio de e-mail falhar, a conta não é
recriada. A tela de verificação permite solicitar novo envio. Se a atualização
do nome falhar depois da criação, o usuário permanece autenticado e não
verificado; edição posterior de perfil ainda será implementada.

Senhas/tokens não são gravados pelo código de aplicação ou exibidos nos logs.
A persistência da sessão é gerenciada pelo SDK Firebase. Ainda não há dados
locais de contatos/histórico para migrar ou isolar neste incremento.

## Testes automatizados

Validação em 7 de novembro de 2026: 22 testes aprovados, formatação e análise
estática sem problemas, build debug universal e por arquitetura aprovados.
O APK x86_64 foi instalado no emulador Android 15/API 35; bootstrap Firebase,
boas-vindas, cadastro e entrada foram conferidos. A tentativa de instalar o
APK universal falhou por espaço insuficiente; a variante menor instalou com
sucesso, preservando os dados. Nenhum dado de conta foi enviado no smoke test.

Cobrem validação, cadastro inválido sem efeito remoto, normalização, intervalo
de reenvio por UID, falha parcial, verificação consultada, renovação do token,
mensagens de credenciais, recuperação neutra, formulários e bloqueio de rotas
após logout. Usam repositórios/adaptadores substitutos e não criam contas reais
nem enviam mensagens a destinatários de produção.

## Roteiro de aceite com uma conta do responsável

1. Abrir o aplicativo Android e cadastrar uma conta com um e-mail acessível.
2. Conferir o registro no Firebase Authentication e a chegada do e-mail.
3. Confirmar que abas protegidas não aparecem antes da verificação.
4. Abrir o link recebido, voltar ao app e tocar “Já verifiquei”.
5. Confirmar entrada na tela inicial; monitoramento/SOS permanecem indisponíveis.
6. Conferir nome/e-mail em Ajustes, sair e entrar novamente.
7. Solicitar recuperação de senha e concluir pelo link recebido.
8. Verificar erros de credenciais/rede, reenvio e restauração após fechar o app.

Esse roteiro ainda depende de execução com uma caixa postal real do responsável.
Não há conta de teste criada automaticamente no projeto remoto.

## Próximas partes

Persistência protegida por UID, contatos, preparação e edição de perfil.
Firestore e regras de acesso não foram adicionados. A prova física de sensores,
serviço e contagem independente continua pendente. Publicação em release exige
validar também shrinking/R8, assinatura e gates de segurança do planejamento.
