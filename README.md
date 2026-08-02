[Português](README.pt-br.md)

# BlockText

BlockText renders a string in the Roblox 3D world as a grid of small cubes, where every single cube is driven
by an analytic spring for BOTH its world position and its scale -- there is no TweenService anywhere in it.
Because the follow happens in **world space**, a moving anchor drags the letters along: they trail behind, lean
into the turn and then settle, instead of snapping to a rigid offset. The very same spring is what morphs one
word into the next, so `SetText` is a transition rather than a cut. It is client-side presentation only -- run
it on the client, nothing here is replicated or server-authoritative.

## Features

- **Fluid follow** -- every cube springs toward its world slot; `MoveFrequency` / `MoveDamping` tune how floaty
  or how snappy that is.
- **Morphing text** -- `SetText` relocates the existing cubes to their new slots, so a word melts into the next
  one. Six transition styles to pick from.
- **Per-letter float** -- each letter bobs and tumbles on its own phase, so the word ripples instead of sliding
  around as one rigid slab.
- **Camera billboarding** -- keep the word readable from any angle with `FollowCamera`.
- **Face target** -- aim the word's local +X at a world point every frame; combine it with `Font.ARROW` for a
  waypoint arrow that always points at its destination.
- **Gradients, rainbow and tone** -- the color lerps across the word at any angle, optionally scrolling or as an
  animated hue rainbow, with a soft directional sheen so the block reads as lit.
- **Touch interaction** -- cubes near a character are pushed away and squashed, then spring back.
- **Custom cubes** -- bring your own Model for outlined, textured or oddly-shaped letters.
- **Reduced motion** -- one global hook drops all the motion while keeping the text fully readable.
- **Pure-Luau font** -- the glyph table and the layout math have no Roblox instances, and are unit-tested
  outside Studio.

## Install

### Wally

Add the dependency to your `wally.toml`:

```toml
[dependencies]
BlockText = "ocauapaz/rbx-blocktext@0.1.0"
```

Then run:

```sh
wally install
```

And require it:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockText = require(ReplicatedStorage.Packages.BlockText)
```

### Manual

Copy `src/` into your place as a ModuleScript named `BlockText` (its children `Font`, `Spring` and
`CubeTemplate` come along with it), then require it from wherever you put it.

## Quick start

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlockText = require(ReplicatedStorage.Packages.BlockText)

local attachment = workspace.Sign.Attachment

-- Anchored to an Attachment: move the part and the letters trail after it.
local handle = BlockText.Create(attachment, "HELLO", {
	Preset = "Hologram",
	CubeSize = 0.5,
})

-- The same spring that follows the anchor also morphs the word.
task.wait(3)
handle:SetText("WORLD", "Scatter")

task.wait(3)
handle:Destroy()
```

Text is uppercase-only (lowercase folds to uppercase), `\n` starts a new line, and any character without a
glyph renders as a blank gap.

## Presets

Ready-made option bundles. Use `{ Preset = "Hologram" }` in your options -- every other field you pass wins over
the preset -- or build a tweaked copy with `BlockText.Preset("Hologram", { CubeSize = 0.3 })`.

| Preset | What it looks like |
| --- | --- |
| `Hologram` | Cyan-to-blue sci-fi label that always faces the camera. No outline (the neon glow carries it), a heavier float and a slower, floatier glide. |
| `Arcade` | Punchy magenta-to-cyan that types itself in letter by letter and reacts to the player walking through it. |
| `Toon` | Solid golden-yellow cartoon text with the template's outline shell kept. Pair it with a template that actually has an `Outer` shell. |
| `Ghost` | Soft, pale blue-white text with a heavy slow float and a very loose, drifting follow. No outline. |
| `Rainbow` | Continuous hue rainbow scrolling across the text, camera-facing, with a light tonal sheen. |
| `Confetti` | Four-color gradient with a high tonal spread; the cubes explode outward and reassemble on every text change, and react to touch. |

## Rebuild styles

How a `SetText` transition looks. Set the default for a word with the `RebuildStyle` option, or override it per
call: `handle:SetText("WORLD", "Scatter")`.

| Style | Transition |
| --- | --- |
| `"Relocate"` | Reuses the cubes already on screen and glides each one over to its new slot. The default. |
| `"Shuffle"` | Reuses them as well, but pairs each cube with a scrambled slot, so the letters cross over each other on the way. |
| `"Rebuild"` | Shrinks the old word out and grows the new one in, in place. |
| `"Scatter"` | The old cubes explode outward and the new ones fly back in, from 10 studs out. |
| `"Rise"` | The old cubes fall out downward and the new ones rise back up, over 5 studs. |
| `"Typewriter"` | Clears the word, then pops the letters in left to right, 0.07 s apart. |

When the new text is shorter than the old one, the surplus cubes shrink out and are cleaned up on their own.

## Custom cubes

A template is a **Model** with:

- `Inner` -- a BasePart, the colored body. BlockText tints this per cube and resizes it every frame.
- `Outer` -- an OPTIONAL BasePart, the outline shell drawn around the body.

```
Cube (Model)
 |- Inner (Part,     Material = Neon)           -- tinted per cube
 |- Outer (MeshPart, inverted-hull cube, black) -- the outline
```

```lua
local handle = BlockText.Create(attachment, "OUTLINED", {
	Template = ReplicatedStorage.Assets.Cube,
	OutlineColor = Color3.new(0, 0, 0),
})
```

BlockText reads the `Inner`/`Outer` size ratio straight off your template, so the outline keeps exactly the
thickness it was authored with at every `CubeSize`. Cloned parts are stripped of collision, queries, touch
events, mass and shadows.

**Why the built-in template ships without an outline:** a solid outline shell cannot be built from a plain Part.
An opaque box around the body would simply hide it. A real outline needs an *inverted-hull* mesh -- a cube
MeshPart with its normals flipped, so the camera sees its far faces and the body shows through -- and that is
authored art, not something a library can conjure at runtime. So the built-in template is just `Inner`, a neon
cube, and the body IS the full cube. Author the outlined Model once in Studio and pass it as `Template` to get
outlined letters.

## Reduced motion

Wire the global check to your accessibility setting once at startup:

```lua
BlockText.SetReducedMotion(function()
	return Settings.Get("ReduceMotion") == true
end)
```

It is polled every frame, so installing or clearing it takes effect immediately. While it returns `true`, every
word drops the float, the wobble, the touch interaction and the transition animation, and snaps straight to its
rest pose -- the text stays exactly where it should be and stays fully readable, it just stops moving. Animated
colors freeze as well.

A single word can override the global check with its own `ReducedMotion` option, which is used *instead of* the
global one for that word:

```lua
-- This word keeps moving even when the global check says otherwise.
BlockText.Create(attachment, "ALWAYS", { ReducedMotion = function() return false end })
```

Pass `nil` to `SetReducedMotion` to clear the global check.

## Performance

- **One connection, one engine call.** Every live word shares a single `Heartbeat` connection. Each word's
  stepper computes its cubes' new CFrames into a shared batch and the frame ends with a single
  `Workspace:BulkMoveTo`, so a screenful of words costs one engine round trip instead of hundreds of individual
  `.CFrame` writes. `Enum.BulkMoveMode.FireCFrameChanged` skips the Position/Orientation changed-signal fanout,
  since nothing ever listens to these cubes.
- **Allocation-free hot loop.** The word's frame is unpacked once per frame into scalars, so each cube's world
  target is plain scalar math -- no per-cube `Vector3` or `CFrame` temporaries for the GC to churn through.
- **Colors only when they move.** A static word writes each cube's color exactly once, when the cube takes its
  slot. Only a rainbow or a scrolling gradient refreshes per frame.
- **Trig memoized per letter.** The per-letter float offset and the wobble rotation are computed once per letter
  per frame, not once per cube -- a letter is roughly fifteen cubes that would otherwise repeat the same sines
  and the same CFrame construction.
- **Resize only on change.** Parts are resized only when the scale actually changed by a meaningful amount.
- **Nothing when idle.** The shared `Heartbeat` disconnects itself when the last word is destroyed.
- The system reports itself to the MicroProfiler under a `BlockText` label instead of being lumped into the
  engine's aggregated event bucket.

## API

Full reference: [docs/API.md](docs/API.md).

## Development

Run the font tests (pure Luau, no Studio needed):

```sh
lune run tests/font
```

Format and lint:

```sh
stylua src tests
selene src tests
```

Type-check:

```sh
rojo sourcemap default.project.json -o sourcemap.json
luau-lsp analyze --sourcemap=sourcemap.json src tests
```

Toolchain versions are pinned in `rokit.toml`.

## License

MIT. See [LICENSE](LICENSE).
