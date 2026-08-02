[English](README.md)

# BlockText

O BlockText desenha um texto no mundo 3D do Roblox como uma grade de cubinhos, e cada cubo é movido por uma mola
analítica tanto na posição quanto na escala -- não tem TweenService em lugar nenhum. Como a perseguição acontece
em **espaço de mundo**, uma âncora que se move arrasta as letras junto: elas ficam para trás, inclinam na curva
e só então assentam, em vez de grudarem num deslocamento rígido. É essa mesma mola que transforma uma palavra na
outra, então o `SetText` é uma transição, não um corte seco. É apresentação puramente client-side -- rode no
cliente, nada aqui é replicado nem tem autoridade do servidor.

## Recursos

- **Perseguição fluida** -- cada cubo é puxado por mola até seu lugar no mundo; `MoveFrequency` / `MoveDamping`
  ajustam o quanto isso é solto ou seco.
- **Texto que se transforma** -- o `SetText` realoca os cubos que já existem para os novos lugares, então uma
  palavra derrete na seguinte. São seis estilos de transição.
- **Flutuação por letra** -- cada letra sobe e desce no seu próprio ritmo, então a palavra ondula em vez de
  deslizar como uma placa rígida.
- **Billboard de câmera** -- deixe o texto legível de qualquer ângulo com `FollowCamera`.
- **Mirar num alvo** -- aponta o +X local do texto para um ponto do mundo a cada quadro; junte com `Font.ARROW`
  e você tem uma seta de waypoint que sempre aponta para o destino.
- **Gradientes, arco-íris e tom** -- a cor interpola pela palavra em qualquer ângulo, com rolagem opcional ou
  como arco-íris animado, mais um brilho direcional suave que faz o bloco parecer iluminado.
- **Interação por toque** -- cubos perto de um personagem são empurrados e achatados, e voltam na mola.
- **Cubos personalizados** -- traga seu próprio Model para letras com contorno, textura ou formato diferente.
- **Movimento reduzido** -- um gancho global corta todo o movimento sem tirar nada da legibilidade do texto.
- **Fonte em Luau puro** -- a tabela de glifos e a matemática de layout não usam instâncias do Roblox, e têm
  testes que rodam fora do Studio.

## Instalação

### Wally

Adicione a dependência no seu `wally.toml`:

```toml
[dependencies]
BlockText = "ocauapaz/rbx-blocktext@0.1.0"
```

Depois rode:

```sh
wally install
```

E use:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockText = require(ReplicatedStorage.Packages.BlockText)
```

### Manual

Copie a pasta `src/` para o seu place como um ModuleScript chamado `BlockText` (os filhos `Font`, `Spring` e
`CubeTemplate` vão junto) e dê `require` de onde você colocou.

## Começando

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockText = require(ReplicatedStorage.Packages.BlockText)

local attachment = workspace.Sign.Attachment

-- Ancorado num Attachment: mexa a part e as letras vêm atrás.
local handle = BlockText.Create(attachment, "HELLO", {
	Preset = "Hologram",
	CubeSize = 0.5,
})

-- A mesma mola que segue a âncora também transforma a palavra.
task.wait(3)
handle:SetText("WORLD", "Scatter")

task.wait(3)
handle:Destroy()
```

O texto é só em maiúsculas (minúsculas viram maiúsculas), `\n` começa uma nova linha e qualquer caractere sem
glifo vira um espaço em branco.

## Presets

Pacotes de opções prontos. Use `{ Preset = "Hologram" }` nas suas opções -- qualquer outro campo que você passar
tem prioridade sobre o preset -- ou monte uma cópia ajustada com `BlockText.Preset("Hologram", { CubeSize = 0.3 })`.

| Preset | Como fica |
| --- | --- |
| `Hologram` | Placa sci-fi ciano-para-azul que está sempre virada para a câmera. Sem contorno (o brilho neon dá conta), flutuação mais forte e um deslize mais lento e solto. |
| `Arcade` | Magenta-para-ciano marcante, que se digita letra por letra e reage ao jogador passando por dentro. |
| `Toon` | Texto cartoon amarelo-ouro sólido, mantendo a casca de contorno do template. Combine com um template que tenha mesmo um `Outer`. |
| `Ghost` | Texto claro e pálido, azul-esbranquiçado, com flutuação lenta e pesada e uma perseguição bem frouxa. Sem contorno. |
| `Rainbow` | Arco-íris contínuo rolando pelo texto, virado para a câmera, com um leve brilho tonal. |
| `Confetti` | Gradiente de quatro cores com bastante variação tonal; os cubos explodem para fora e se remontam a cada troca de texto, e reagem ao toque. |

## Estilos de reconstrução

Como fica a transição do `SetText`. Defina o padrão da palavra na opção `RebuildStyle`, ou troque em cada
chamada: `handle:SetText("WORLD", "Scatter")`.

| Estilo | Transição |
| --- | --- |
| `"Relocate"` | Reaproveita os cubos que já estão na tela e desliza cada um até o novo lugar. É o padrão. |
| `"Shuffle"` | Também reaproveita, mas embaralha o pareamento cubo/lugar, então as letras se cruzam no caminho. |
| `"Rebuild"` | Encolhe a palavra antiga até sumir e faz a nova crescer no lugar. |
| `"Scatter"` | Os cubos antigos explodem para fora e os novos voltam voando, de 10 studs de distância. |
| `"Rise"` | Os cubos antigos caem para baixo e os novos sobem de volta, num percurso de 5 studs. |
| `"Typewriter"` | Limpa a palavra e vai estalando as letras da esquerda para a direita, a cada 0,07 s. |

Quando o texto novo é mais curto que o antigo, os cubos que sobraram encolhem e são recolhidos sozinhos.

## Cubos personalizados

Um template é um **Model** com:

- `Inner` -- uma BasePart, o corpo colorido. O BlockText tinge esta part por cubo e redimensiona a cada quadro.
- `Outer` -- uma BasePart OPCIONAL, a casca de contorno desenhada em volta do corpo.

```
Cube (Model)
 |- Inner (Part,     Material = Neon)            -- tingido por cubo
 |- Outer (MeshPart, cubo de casco invertido,    -- o contorno
 |                   preto)
```

```lua
local handle = BlockText.Create(attachment, "OUTLINED", {
	Template = ReplicatedStorage.Assets.Cube,
	OutlineColor = Color3.new(0, 0, 0),
})
```

O BlockText lê a proporção entre `Inner` e `Outer` direto do seu template, então o contorno mantém exatamente a
espessura com que foi criado em qualquer `CubeSize`. As parts clonadas ficam sem colisão, sem consulta de
raycast, sem eventos de toque, sem massa e sem sombra.

**Por que o template embutido vem sem contorno:** uma casca de contorno sólida não dá para fazer com uma Part
comum. Uma caixa opaca em volta do corpo simplesmente esconderia ele. Um contorno de verdade precisa de uma
malha de *casco invertido* -- um cubo MeshPart com as normais invertidas, para a câmera enxergar as faces de trás
e o corpo aparecer através dela -- e isso é arte autorada, não algo que uma biblioteca consiga inventar em tempo
de execução. Por isso o template embutido é só o `Inner`, um cubo neon, e o corpo É o cubo inteiro. Monte o
Model com contorno uma vez no Studio e passe ele como `Template` para ter letras contornadas.

## Movimento reduzido

Ligue a checagem global à sua opção de acessibilidade uma vez, na inicialização:

```lua
BlockText.SetReducedMotion(function()
	return Settings.Get("ReduceMotion") == true
end)
```

Ela é consultada a cada quadro, então instalar ou limpar tem efeito imediato. Enquanto retornar `true`, toda
palavra abre mão da flutuação, do balanço, da interação por toque e da animação de transição, e vai direto para
a pose de repouso -- o texto continua exatamente onde deveria estar e totalmente legível, só para de se mexer. As
cores animadas também congelam.

Uma palavra específica pode passar por cima da checagem global com sua própria opção `ReducedMotion`, que é
usada *no lugar da* global naquela palavra:

```lua
-- Esta palavra continua se mexendo mesmo com a checagem global dizendo o contrário.
BlockText.Create(attachment, "ALWAYS", { ReducedMotion = function() return false end })
```

Passe `nil` para `SetReducedMotion` para limpar a checagem global.

## Desempenho

- **Uma conexão, uma chamada de engine.** Todas as palavras vivas compartilham uma única conexão de
  `Heartbeat`. O passo de cada palavra calcula os novos CFrames dos seus cubos num lote compartilhado e o quadro
  termina com um único `Workspace:BulkMoveTo`, então uma tela cheia de palavras custa uma ida e volta à engine
  em vez de centenas de escritas individuais de `.CFrame`. O `Enum.BulkMoveMode.FireCFrameChanged` ainda pula o
  disparo dos sinais de Position/Orientation, já que nada nunca escuta esses cubos.
- **Laço quente sem alocação.** O frame da palavra é desmontado uma vez por quadro em escalares, então o alvo de
  cada cubo é matemática escalar pura -- nenhum `Vector3` ou `CFrame` temporário por cubo para o GC ter que
  limpar.
- **Cor só quando ela se mexe.** Uma palavra estática escreve a cor de cada cubo exatamente uma vez, quando o
  cubo assume seu lugar. Só arco-íris e gradiente com rolagem são atualizados a cada quadro.
- **Trigonometria memoizada por letra.** O deslocamento de flutuação e a rotação de balanço são calculados uma
  vez por letra por quadro, não por cubo -- uma letra tem cerca de quinze cubos que repetiriam os mesmos senos e
  a mesma construção de CFrame.
- **Redimensiona só quando muda.** As parts só são redimensionadas quando a escala mudou de forma perceptível.
- **Nada quando está ocioso.** O `Heartbeat` compartilhado se desconecta sozinho quando a última palavra é
  destruída.
- O sistema se identifica no MicroProfiler sob o rótulo `BlockText`, em vez de se perder no bucket agregado de
  eventos da engine.

## API

Referência completa: [docs/API.pt-br.md](docs/API.pt-br.md).

## Desenvolvimento

Rodar os testes da fonte (Luau puro, sem precisar do Studio):

```sh
lune run tests/font
```

Formatar e lintar:

```sh
stylua src tests
selene src tests
```

Checagem de tipos:

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json src tests
```

As versões das ferramentas estão fixadas no `rokit.toml`.

## Licença

MIT. Veja o [LICENSE](LICENSE).
