# Changelog

Mudanças relevantes do ZELO. A versão `1.0.0+1` permanece em desenvolvimento, sem lançamento estável.

## [Não lançado]

### Adicionado

- Foto opcional de contatos por câmera/galeria, com prévia, remoção, redução e cache no banco local protegido.
- Sincronização de miniaturas privadas de até 64 KB em documentos separados no Firestore, sem dependência de Firebase Storage.
- Regras de miniaturas por conta verificada, limite de tamanho/formato, exclusão de imagens antigas e bloqueio de gravação durante exclusão da conta.

- Autenticação por e-mail/senha, cadastro, verificação de e-mail e recuperação de senha.
- Perfil com alteração de nome, saída e exclusão retomável da conta e dos dados.
- Rede de apoio com até três contatos, prioridade, máscara de WhatsApp e teste assistido dos canais.
- Checklist com requisitos e recomendações de contatos, notificações, sensores, localização e bateria.
- Monitoramento voluntário em serviço Android, com perfis Bolso/Suporte, alerta de 30 segundos e SOS manual.
- Pedido de ajuda assistido por WhatsApp, e-mail ou cópia, com localização pontual quando disponível.
- Histórico com busca textual, filtros por tipo e período e agrupamento por dia.
- Detalhes de registros com atualizações de condição, observações, fotos locais, preservação e exportação.
- Lembretes opcionais com até três horários e seleção dos dias da semana, isolados por conta no aparelho.
- Reagendamento dos lembretes após reinício ou mudança de horário/fuso e cancelamento ao sair da conta.
- Proteção contra perda de edições e botão de salvar habilitado apenas quando há alterações pendentes.
- Tema escuro automático conforme o sistema, cabeçalho compartilhado e componentes responsivos.
- Diagnóstico do aparelho, demonstração de alerta e tela de recursos com câmera, GPS, notificação de teste e acelerômetro.
- Modal Sobre e tela de licenças com busca por componente e leitura dos textos originais.
- Banco local SQLCipher, journal nativo protegido, fotos locais criptografadas e sincronização de metadados via Firestore.
- Fila de sincronização, revisões, resolução de conflitos e exclusões com confirmação do servidor.
- Testes de domínio, repositórios, widgets, regras de acesso, integrações e agendamento Android.

### Alterado

- Fotos de contatos usam miniaturas PNG reduzidas, cache local protegido e documentos privados do Firestore; os bytes ficam sem indexação.
- Referências e fotos locais da implementação anterior são compatíveis com a migração para miniaturas no Firestore.

- Cartões de contatos com identificação do principal, canais separados, ações de editar/testar e menu de prioridade/exclusão.
- Filtros do histórico centralizados e seleção de período com resumo do intervalo aplicado.
- Organização da condição atual nos detalhes, com ações responsivas e acesso destacado ao pedido de ajuda.
- Compartilhamento organizado em cartões por canal, com disponibilidade, destinatário e carregamento individual.
- Seleção dos dias da semana em grade adaptável, atalhos de dias úteis/todos os dias e cartões de horários.
- Confirmações com largura limitada, espaçamento compacto e botões adaptáveis ao tamanho da tela e do texto.
- Formulários com validação, carregamento e bloqueio de salvamento sem mudanças ou após restaurar os valores originais.
- README simplificado para funcionalidades atuais, execução, validação e geração do APK.

### Corrigido

- Formulários de acesso exibem erros somente após tentativa de envio; focar ou digitar no e-mail não valida a senha vazia.
- Entrada aguarda a busca inicial dos dados da conta antes de apresentar o conteúdo; contatos restaurados não provocam redirecionamento indevido ao checklist.
- Falhas de conexão preservam o cache local e oferecem acesso à sincronização, sem tratar a conta como vazia.

- Ocorrências antigas pendentes não redirecionam o usuário para Pedir ajuda ao entrar; alertas ativos mantêm seu fluxo.
- Seleção e alinhamento das opções Bolso/Suporte na tela inicial.
- Formatação de WhatsApp durante digitação, edição e visualização.
- Contraste e tipografia dos filtros e estados no tema escuro.
- Atualizações de condição preservam o resultado original do alerta.

### Removido

- Pasta de apresentação local, incluindo arquivos auxiliares e artefatos de slides.
- Pasta `docs`, paleta em Markdown e demais arquivos `.md`, preservando apenas README e changelog da raiz.

### Validação

- Cobertura de layouts em celular estreito, orientação horizontal, texto ampliado e temas claro/escuro.
- Testes de confirmação de descarte, mudanças pendentes, filtros por período e configuração dos lembretes.
- Testes Android de seleção do próximo horário, dias da semana e fuso.
- A detecção permanece experimental; notificações e atividade em segundo plano dependem das permissões e restrições do aparelho.
