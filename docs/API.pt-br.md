[English](API.md)

# Referência da API do BlockText

Apresentação puramente client-side. Toda função aqui cria, anima ou destrói parts decorativas -- nada é
replicado, nada tem autoridade do servidor, e os cubos nunca colidem, bloqueiam raycast, disparam eventos de
toque, pesam nada nem projetam sombra.

```lua
local BlockText = require(ReplicatedStorage.Packages.BlockText)
```

- [Funções do módulo](#funções-do-módulo)
- [Options](#options)
- [Handle](#handle)
- [Tipos](#tipos)
- [Font](#font)

## Funções do módulo

| Membro | Assinatura |
| --- | --- |
| `BlockText.Create` | `(anchor: Anchor, text: string, options: Options?) -> Handle` |
| `BlockText.Preset` | `(name: string, overrides: Options?) -> Options` |
| `BlockText.Presets` | `{ [string]: Options }` |
| `BlockText.RebuildStyles` | `{ RebuildStyle }` |
| `BlockText.SetReducedMotion` | `(provider: (() -> boolean)?) -> ()` |
| `BlockText.Font` | o módulo [`Font`](#font) |

### BlockText.Create(anchor, text, options?) -> Handle

Monta uma palavra e começa a animá-la. Devolve um [`Handle`](#handle) que é seu: nada mais vai destruí-lo, a não
ser que uma âncora do tipo Attachment saia do DataModel ou que a opção `Lifetime` termine.

A palavra ganha uma Folder própria chamada `BlockText`, colocada dentro do `Parent` das opções (a Workspace, por
padrão), com um Model por cubo. Os cubos nascem minúsculos já no frame da âncora e crescem na mola.

Se `options.Preset` estiver definido, o pacote com aquele nome em `BlockText.Presets` é usado como base e todos
os outros campos que você passou entram por cima:

```lua
-- Hologram, mas com cubos menores.
BlockText.Create(attachment, "HELLO", { Preset = "Hologram", CubeSize = 0.3 })
```

### BlockText.Preset(name, overrides?) -> Options

Uma cópia rasa do preset com esse nome, com `overrides` aplicados por cima. Um nome desconhecido devolve só os
overrides. Equivale a passar `{ Preset = name, ... }` direto para o `Create`, mas é útil quando você quer guardar
a tabela de opções resultante.

```lua
local style = BlockText.Preset("Arcade", { CubeSize = 0.4 })
local a = BlockText.Create(attachmentA, "READY", style)
local b = BlockText.Create(attachmentB, "GO", style)
```

### BlockText.Presets

A tabela de pacotes de opções prontos, indexada por nome.

| Preset | O que define |
| --- | --- |
| `Hologram` | `FollowCamera = true`, `Outline = false`, `ToneVariation = 0.1`, `FloatHeight = 0.3`, `MoveFrequency = 6`, um `Gradient` ciano-para-azul. |
| `Arcade` | `PlayerInteraction = true`, `ToneVariation = 0.16`, `RebuildStyle = "Typewriter"`, um `Gradient` magenta-para-ciano. |
| `Toon` | `Color` amarelo-ouro, `Outline = true`, `ToneVariation = 0.12`, `RebuildStyle = "Relocate"`. |
| `Ghost` | `Color` azul-esbranquiçado, `Outline = false`, `ToneVariation = 0.08`, `FloatHeight = 0.5`, `FloatSpeed = 1.6`, `MoveFrequency = 4`, `MoveDamping = 0.9`. |
| `Rainbow` | `Rainbow = true`, `GradientSpeed = 0.15`, `RainbowSpan = 1`, `FollowCamera = true`, `ToneVariation = 0.08`. |
| `Confetti` | `PlayerInteraction = true`, `ToneVariation = 0.2`, `RebuildStyle = "Scatter"`, um `Gradient` de quatro paradas: vermelho / amarelo / verde / azul. |

A tabela é a de verdade, então você pode acrescentar seus próprios pacotes nela:

```lua
BlockText.Presets.Warning = { Color = Color3.fromRGB(255, 80, 60), RebuildStyle = "Rise" }
```

### BlockText.RebuildStyles

Um array com todos os valores válidos de [`RebuildStyle`](#rebuildstyle), na ordem:
`{ "Relocate", "Shuffle", "Rebuild", "Scatter", "Rise", "Typewriter" }`. Útil para montar um seletor de debug ou
validar entrada.

### BlockText.SetReducedMotion(provider?)

Instala uma checagem global de "reduzir movimento", consultada a cada quadro por todas as palavras. Enquanto ela
retornar `true`, cada palavra abre mão da flutuação, do balanço, da interação por toque e da animação de
transição, e vai direto para a pose de repouso -- o texto continua totalmente legível, só para de se mexer. As
cores animadas também congelam.

```lua
BlockText.SetReducedMotion(function()
	return Settings.Get("ReduceMotion") == true
end)
```

Passe `nil` para limpar. Uma palavra que traz sua própria opção `ReducedMotion` usa aquela no lugar da global.

### BlockText.Font

O módulo [`Font`](#font), reexportado para você não precisar dar `require` separado -- principalmente por causa
de `Font.ARROW` e `Font.SetGlyph`.

## Options

Todos os campos são opcionais. Os padrões abaixo são o que o módulo usa quando o campo não vem (e nenhum preset
o fornece).

### Preset

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `Preset` | `string` | nenhum | Parte de um pacote de `BlockText.Presets`. Todos os outros campos desta tabela têm prioridade sobre o preset. |

### Aparência

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `Color` | `Color3` | `Color3.fromRGB(255, 255, 255)` | Cor lisa do corpo, usada quando não há `Gradient`. |
| `Gradient` | `{ Color3 }` | nenhum | Duas ou mais paradas interpoladas pela palavra na direção de `GradientRotation`. Tem prioridade sobre `Color`. A mistura é feita em HSV, então o meio continua um tom vibrante em vez de puxar para o cinza, e cada trecho passa por um smoothstep, de modo que a varredura suaviza *através* de cada parada. |
| `GradientRotation` | `number` | `0` | Ângulo da varredura do gradiente, em graus. `0` = da esquerda para a direita, `90` = de baixo para cima. |
| `GradientSpan` | `number` | `1` | Quantas vezes o gradiente se repete ao longo do texto. Abaixo de `1` dá zoom em parte dele. |
| `GradientSpeed` | `number` | `0` | Ciclos por segundo que o gradiente (ou o arco-íris) rola pelo texto. `0` é estático. |
| `Rainbow` | `boolean` | `false` | Arco-íris de matiz contínuo e animado, com saturação e valor no máximo. Tem prioridade sobre `Color` e `Gradient`. |
| `RainbowSpan` | `number` | `1` | Quantas voltas completas de matiz cabem no texto ao mesmo tempo. |
| `ToneVariation` | `number` | `0.12` | Intensidade do brilho direcional suave aplicado sobre a cor resolvida: uma rampa única numa diagonal do canto superior esquerdo ao inferior direito (com peso mais vertical), para o bloco parecer iluminado de cima. Ele só desloca o *valor* HSV, então todo cubo continua com a mesma cor, apenas num tom mais claro ou mais escuro. `0` deixa tudo chapado. Valores negativos viram `0`. |
| `Material` | `Enum.Material` | o do template | Sobrescreve o material do corpo `Inner` do template. |
| `Outline` | `boolean` | `true` | Mantém a casca de contorno `Outer` do template, quando ele tem uma. Com `false` ela é destruída em cada clone. Não faz nada num template sem `Outer`. |
| `OutlineColor` | `Color3` | a do template | Recolore a casca de contorno. Só vale quando o contorno é mantido. |

### Geometria

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `Template` | `Model` | o cubo neon embutido | Model de cubo a ser clonado: uma BasePart chamada `Inner`, mais uma BasePart opcional chamada `Outer`. Um clone sem `Inner` é descartado. |
| `CubeSize` | `number` | `0.6` | Aresta de um cubo em escala cheia, em studs. |
| `CellStep` | `number` | `CubeSize * 1.2` | Distância de centro a centro entre as células da grade, em studs. |
| `Mirror` | `boolean` | `false` | Espelha o layout na horizontal, para quando a palavra fica invertida de onde ela é vista. |
| `Parent` | `Instance` | `Workspace` | Onde a Folder dos cubos é colocada. |

### Movimento

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `MoveFrequency` | `number` | `7` | Frequência angular da mola de posição. Quanto menor, mais lento e solto o deslize. Limitado a no mínimo `0.1`. |
| `MoveDamping` | `number` | `0.85` | Razão de amortecimento da mola de posição. Abaixo de `1` ela passa do ponto e quica; a razão é limitada logo abaixo de `1`. |
| `FloatHeight` | `number` | `0.18` | Amplitude do sobe-e-desce por letra, em studs. `0` desliga. |
| `FloatSpeed` | `number` | `2.4` | Velocidade do sobe-e-desce por letra. |
| `Wobble` | `number` | `5` | Amplitude do balanço ocioso por letra, em graus. Todos os cubos de uma letra compartilham a fase, então a letra inclina como uma peça só e as faces cintilam. `0` desliga. |
| `WobbleSpeed` | `number` | `1.2` | Velocidade do balanço por letra. |
| `RebuildStyle` | [`RebuildStyle`](#rebuildstyle) | `"Relocate"` | Transição padrão usada pelo `SetText` quando a chamada não passa a sua. |

A mola de escala (crescer e encolher) é de propósito mais seca que a de posição, e não é configurável.

### Orientação

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `FollowCamera` | `boolean` | `false` | Faz a palavra inteira virar para a câmera atual, para ler de qualquer ângulo. |
| `FaceTarget` | [`FaceTargetProvider`](#facetargetprovider) | nenhum | Aponta o +X local da palavra para um ponto do mundo a cada quadro. Tem prioridade sobre `FollowCamera`. |

Prioridade de orientação a cada quadro: um `FaceTarget` mirando ganha do billboard do `FollowCamera`, que ganha
do CFrame da própria âncora.

### Interação

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `PlayerInteraction` | `boolean` | `false` | Empurra e achata os cubos por onde um personagem passa. Dá para ligar e desligar depois com `Handle:SetPlayerInteraction`. |
| `TouchSources` | [`TouchSourceProvider`](#touchsourceprovider) | as parts do personagem local | Quem faz o empurrão. No máximo 8 fontes são lidas por quadro. |
| `TouchRadius` | `number` | `6` | Alcance da interação, em studs. Um cubo dentro desse raio é empurrado, com a força caindo linearmente até zero na borda. |
| `TouchStrength` | `number` | `3.5` | Quanto um cubo totalmente tocado é empurrado, em studs. |

Um cubo tocado também é achatado -- até 45% da escala no contato total -- e volta na mola quando a fonte se
afasta.

### Ciclo de vida

| Campo | Tipo | Padrão | Descrição |
| --- | --- | --- | --- |
| `Lifetime` | `number` | nenhum | Destrói a palavra sozinho depois de N segundos. Sem isso, o ciclo de vida é seu. |
| `ReducedMotion` | `() -> boolean` | a checagem global | Override de acessibilidade por palavra, consultado a cada quadro. É usado *no lugar do* provider passado para `BlockText.SetReducedMotion`, então retornar `false` aqui tira esta palavra da configuração global. |

## Handle

Devolvido por `BlockText.Create`. Todos os métodos não fazem nada depois que a palavra foi destruída.

| Membro | Assinatura |
| --- | --- |
| `Container` | `Instance` |
| `SetText` | `(self, text: string, style: RebuildStyle?) -> ()` |
| `SetAnchor` | `(self, anchor: Anchor) -> ()` |
| `SetFaceTarget` | `(self, provider: FaceTargetProvider?) -> ()` |
| `SetScale` | `(self, multiplier: number) -> ()` |
| `SetPlayerInteraction` | `(self, enabled: boolean) -> ()` |
| `Destroy` | `(self) -> ()` |

### Container

A Folder que guarda todos os cubos desta palavra. Somente leitura: destruir ela na mão deixa o handle
desatualizado -- chame o `Destroy`.

### Handle:SetText(text, style?)

Reconstrói a palavra. O `style` substitui a opção `RebuildStyle` só nesta chamada.

Os estilos de reaproveitamento (`"Relocate"`, `"Shuffle"`) mantêm os cubos que já estão na tela e os levam de
mola até os novos lugares -- é isso que transforma uma palavra na outra em vez de cortar entre elas. Os outros
estilos aposentam todos os cubos e criam um conjunto novo. Os cubos que sobram -- quando a palavra nova é mais
curta -- encolhem e são recolhidos automaticamente.

```lua
handle:SetText("SCORE: 1200")
handle:SetText("NEW HIGH\nSCORE", "Rise")
```

### Handle:SetAnchor(anchor)

Aponta a palavra para uma nova [`Anchor`](#anchor). Como a mola trabalha em espaço de mundo, as letras deslizam
até lá em vez de teleportar.

### Handle:SetFaceTarget(provider?)

Instala ou troca o [`FaceTargetProvider`](#facetargetprovider). Passe `nil` para voltar ao `FollowCamera`, ou à
orientação da própria âncora.

### Handle:SetScale(multiplier)

Escala a palavra inteira de forma uniforme -- tamanho do cubo e espaçamento da grade juntos. `1` é o tamanho
original, e valores negativos viram `0`.

**Só tem efeito no próximo `SetText`**, porque os lugares do layout são calculados na hora de montar. Chame logo
antes de reconstruir ou trocar o texto:

```lua
handle:SetScale(2)
handle:SetText("BIG")
```

### Handle:SetPlayerInteraction(enabled)

Liga ou desliga o comportamento de empurrar/achatar no toque em tempo de execução. Tem prioridade sobre a opção
`PlayerInteraction`.

### Handle:Destroy()

Destrói o container e todos os cubos, e tira a palavra do laço de quadro compartilhado. Pode ser chamado mais de
uma vez sem problema. Quando a última palavra viva é destruída, a conexão de `Heartbeat` compartilhada se
desconecta sozinha.

## Tipos

### Anchor

```lua
export type Anchor = Attachment | (() -> CFrame?)
```

Onde a palavra fica ancorada.

- **`Attachment`** -- a palavra segue o `WorldCFrame` do attachment, e se autodestrói assim que esse attachment
  sai do DataModel.
- **`() -> CFrame?`** -- consultada a cada quadro por um CFrame. Uma função que retorna `nil` **mantém o último
  frame conhecido** em vez de destruir, então a palavra sobrevive a um personagem momentaneamente ausente (um
  respawn, um modelo que saiu por streaming) e se reancora quando ele volta.

### FaceTargetProvider

```lua
export type FaceTargetProvider = () -> Vector3?
```

Posição no mundo para onde o frame do layout aponta seu +X local a cada quadro. Retornar `nil` pula a mira
naquele quadro e cai de volta no `FollowCamera` ou na orientação da própria âncora.

A mira é 3D completa: a guinada vem da direção no plano do chão e a inclinação vem da diferença de altura, então
uma seta aponta exatamente *para* o alvo, e não só na direção da bússola dele. O +Y local continua sendo o vetor
lateral horizontal, então a palavra só inclina em torno desse eixo e nunca gira de lado. Quando o alvo fica quase
exatamente acima ou abaixo da âncora (a menos de 0,05 stud na horizontal), a direção fica indefinida, então
aquele quadro mantém a orientação de fallback em vez de pular para uma qualquer.

### TouchSourceProvider

```lua
export type TouchSourceProvider = () -> { Vector3 }?
```

Posições no mundo que empurram os cubos quando `PlayerInteraction` está ligado. Retornar `nil` cai de volta nas
parts do personagem do jogador local. Como isso é chamado a cada quadro, **retorne uma tabela reutilizada** em
vez de alocar uma nova. No máximo 8 posições são lidas por quadro.

### RebuildStyle

```lua
export type RebuildStyle = "Relocate" | "Shuffle" | "Rebuild" | "Scatter" | "Rise" | "Typewriter"
```

| Estilo | Transição |
| --- | --- |
| `"Relocate"` | Reaproveita os cubos que já estão na tela e desliza cada um até o novo lugar. É o padrão. |
| `"Shuffle"` | Também reaproveita, mas embaralha o pareamento cubo/lugar, então as letras se cruzam no caminho. |
| `"Rebuild"` | Encolhe a palavra antiga até sumir e faz a nova crescer no lugar. |
| `"Scatter"` | Os cubos antigos explodem para fora em direções aleatórias e os novos voltam voando, de 10 studs de distância. |
| `"Rise"` | Os cubos antigos caem para baixo e os novos sobem de volta, num percurso de 5 studs. |
| `"Typewriter"` | Limpa a palavra e vai estalando as letras da esquerda para a direita, a cada 0,07 s. |

## Font

`BlockText.Font`, também disponível como o módulo filho `Font`. É dado puro mais matemática de layout, **sem
nenhuma instância do Roblox**, então a tabela de glifos e a conversão de string em células rodam em qualquer
runtime Luau e são testadas fora do Studio. Quem transforma essas células em cubos animados de verdade é o
`BlockText`.

Os glifos são desenhados só em maiúsculas, como bitmaps de 5 linhas feitos de `#` (cubo preenchido) e espaço
(vazio). As letras `A`-`Z` e os dígitos `0`-`9` têm 5 colunas de largura, para as formas ficarem legíveis; a
pontuação (`: . , ' ! - + = * % ( ) / \ ? # $`) fica mais estreita onde faz sentido. Glifos vizinhos são
separados por uma coluna em branco, um espaço avança uma coluna e as linhas são separadas por uma linha em
branco. Minúsculas viram maiúsculas, e qualquer caractere sem glifo vira um espaço em branco.

| Membro | Assinatura |
| --- | --- |
| `Font.Height` | `number` -- `5` |
| `Font.ARROW` | `string` |
| `Font.Rows` | `(char: string) -> { string }?` |
| `Font.Width` | `(char: string) -> number` |
| `Font.SetGlyph` | `(char: string, rows: { string }) -> ()` |
| `Font.Layout` | `(text: string) -> Layout` |

### Font.Height

A quantidade de linhas que todo glifo precisa ter: `5`. É fixo, porque o renderizador assume uma linha de base
uniforme.

### Font.ARROW

A chave do glifo de seta para a direita já embutido (`"\u{2192}"`), exportada para você desenhá-lo sem precisar
colar um literal multibyte no seu código. Ele tem 7 colunas: uma haste de largura total com uma ponta em chevron
na extremidade +X, então o glifo aponta na direção do +X local do frame de layout. Junte com a opção `FaceTarget`
para mirar esse +X numa posição do mundo e você tem uma seta de waypoint que sempre aponta para o destino.

```lua
BlockText.Create(anchor, BlockText.Font.ARROW, { FaceTarget = function() return destination end })
```

### Font.Rows(char) -> { string }?

As linhas do bitmap de um caractere, ou `nil` quando ele não tem glifo. O caractere já precisa estar em
maiúscula.

### Font.Width(char) -> number

Quantas colunas um caractere ocupa. Espaços -- e caracteres desconhecidos, que viram branco -- devolvem `1`. A
comparação não diferencia maiúsculas de minúsculas.

### Font.SetGlyph(char, rows)

Registra ou substitui um glifo. As chaves são comparadas depois de virar maiúscula e podem ser multibyte (UTF-8),
então dá para acrescentar símbolos fora do ASCII.

`rows` precisa ter exatamente `Font.Height` linhas, todas do mesmo comprimento, feitas de `#` (preenchido) e
qualquer outro caractere (vazio). As duas regras são verificadas com assert: o renderizador assume uma linha de
base uniforme, então um glifo curto ficaria flutuando e um irregular rasgaria o layout.

```lua
local Font = BlockText.Font

Font.SetGlyph("\u{2764}", {
	" # # ",
	"#####",
	"#####",
	" ### ",
	"  #  ",
})
```

### Font.Layout(text) -> Layout

Distribui uma string em células preenchidas, centradas na origem do bloco. `\n` começa uma nova linha; cada linha
é centrada horizontalmente pela própria largura, e a pilha de linhas é centrada verticalmente.

```lua
local layout = Font.Layout("HELLO\nWORLD")
-- layout.Width  = 29 -- cinco glifos de 5 colunas e os quatro espaços entre eles
-- layout.Height = 11 -- duas linhas de 5 fileiras e a fileira em branco entre elas
-- layout.Cells  = { { X = -14, Y = 5, Letter = 1 }, ... }
```

### Cell

```lua
export type Cell = { X: number, Y: number, Letter: number }
```

| Campo | Significado |
| --- | --- |
| `X` | Posição da coluna em **unidades de célula**, relativa ao centro do bloco inteiro. Cresce para a direita. |
| `Y` | Posição da fileira em **unidades de célula**, relativa ao centro do bloco inteiro. Cresce para cima. |
| `Letter` | O índice (começando em 1) do caractere de origem ao qual a célula pertence. |

O sistema de coordenadas é de propósito centrado e sem unidade: toda a centralização -- de cada linha na
horizontal e da pilha de linhas na vertical -- já está feita, então o renderizador só multiplica `X` e `Y` por um
passo em studs. As fileiras são desenhadas de cima (índice 1) para baixo (índice `Font.Height`), mas o `Y` já sai
invertido, com o positivo para cima. Quando o vão de colunas de uma linha (ou o vão total de fileiras) é par, os
valores caem na metade -- e está certo, o bloco é centrado, não encaixado na grade.

O `Letter` é o que permite agrupar as células por caractere, que é como o BlockText faz cada letra da palavra
flutuar e balançar na sua própria fase enquanto todos os cubos de uma mesma letra ficam grudados. Vale lembrar
que um `\n` também conta como caractere de origem, então em `"A\nB"` as células do `B` carregam `Letter = 3`.

### Layout

```lua
export type Layout = { Cells: { Cell }, Width: number, Height: number }
```

| Campo | Significado |
| --- | --- |
| `Cells` | Todas as células preenchidas do texto. Vazio para texto vazio ou só com caracteres desconhecidos. |
| `Width` | O vão de colunas da linha mais larga, já sem o espaço final entre glifos. |
| `Height` | O vão total de fileiras somando todas as linhas, incluindo a fileira em branco entre elas. |

`Width` e `Height` estão em unidades de célula, e são o que o BlockText usa para normalizar o gradiente e o
brilho tonal, de modo que os dois varram de ponta a ponta em qualquer tamanho de palavra.
