# Interface e experiência do ZELO

Atualização de 7 de novembro de 2026, em desenvolvimento na `develop`.

## Direção visual

Paleta oficial preservada, com azul-marinho e petróleo na proteção, vermelho
no SOS e tons claros nos cartões informativos. Karla local, hierarquia de
títulos, espaçamento consistente, campos com foco visível e alvos de toque
confortáveis. As telas se limitam a 720 px em janelas largas e continuam
roláveis quando o texto é ampliado.

O início apresenta estado real da proteção, ação de iniciar/encerrar, SOS,
posição do celular e atalhos. O alerta usa contagem circular e ações fixas no
rodapé. Contatos explicam prioridade e reordenação. Histórico tem filtros que
se acomodam em mais de uma linha. Ajustes foram divididos por finalidade.

## Componentes compartilhados

- `lib/shared/presentation/app_icons.dart`: catálogo único de ícones Material.
- `lib/shared/widgets/app_components.dart`: cartões, seções, estados vazios,
  ícones com fundo, avisos, rodapé de ações e contagem do alerta.
- `lib/shared/presentation/app_labels.dart`: traduções de estados, entidades,
  canais, erros de sincronização e diagnósticos, com fallback em português.
- `lib/core/formatting/date_format.dart`: datas no formato brasileiro.
- `PhonePositionSelector`: escolha adaptável entre Bolso e Suporte.

Os identificadores internos do banco e Firebase permanecem iguais. A tradução
acontece na apresentação. `pocket`, `DENIED`, `PENDING` e códigos de erro não
são mostrados como rótulos. Mensagens de ajuda e resumos exportados também usam
datas e descrições legíveis. Componentes padrão do Flutter usam localização
pt-BR, incluindo os controles de licenças.

Nenhum envio pendente não significa que uma mensagem de emergência foi entregue.
A interface mantém essa distinção. A sincronização explica que é automática
com app em execução e internet; o botão manual mostra progresso e evita toques
repetidos durante a tentativa.

## Verificação

Análise estática limpa e 69 testes Flutter aprovados. Vinte verificações
de apresentação exercitam dez telas em 390 × 844 e 320 × 700, a segunda com
texto em 200%. Incluem rolagem, traduções e exceções de layout. As prévias
visuais foram geradas com Karla e ícones reais, usando somente dados fictícios.

O cadastro de contatos mostra erros junto aos campos e compartilha as regras
de nome e e-mail com o domínio. Os campos permanecem montados durante a rolagem
para validar o formulário inteiro. O teclado oferece avanço entre campos.
Mensagens de feedback substituem o aviso anterior em vez de formar uma fila.

```sh
flutter test test/presentation/ui_experience_test.dart --dart-define=ZELO_UI_PREVIEW=true
```

As imagens ficam em `build/ui-preview/`, fora do Git. Os testes não enviam
mensagens nem acessam o Firebase de produção. A revisão visual em celular
físico com a nova interface ainda faz parte do aceite do produto.
