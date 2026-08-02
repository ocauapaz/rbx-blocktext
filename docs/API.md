[Português](API.pt-br.md)

# BlockText API reference

Client-side presentation only. Every function here spawns, animates or destroys purely decorative parts --
nothing is replicated, nothing is server-authoritative, and the cubes never collide, block raycasts, fire touch
events, weigh anything or cast shadows.

```lua
local BlockText = require(ReplicatedStorage.Packages.BlockText)
```

- [Module functions](#module-functions)
- [Options](#options)
- [Handle](#handle)
- [Types](#types)
- [Font](#font)

## Module functions

| Member | Signature |
| --- | --- |
| `BlockText.Create` | `(anchor: Anchor, text: string, options: Options?) -> Handle` |
| `BlockText.Preset` | `(name: string, overrides: Options?) -> Options` |
| `BlockText.Presets` | `{ [string]: Options }` |
| `BlockText.RebuildStyles` | `{ RebuildStyle }` |
| `BlockText.SetReducedMotion` | `(provider: (() -> boolean)?) -> ()` |
| `BlockText.Font` | the [`Font`](#font) module |

### BlockText.Create(anchor, text, options?) -> Handle

Builds a word and starts animating it. Returns a [`Handle`](#handle) you own: nothing else will destroy it
unless an Attachment anchor leaves the DataModel, or the `Lifetime` option elapses.

The word gets its own Folder named `BlockText`, parented to the `Parent` option (Workspace by default), holding
one Model per cube. The cubes start tiny at the anchor's frame and spring in.

If `options.Preset` is set, the named bundle from `BlockText.Presets` is used as the base and every other field
you passed is layered on top of it:

```lua
-- Hologram, but with smaller cubes.
BlockText.Create(attachment, "HELLO", { Preset = "Hologram", CubeSize = 0.3 })
```

### BlockText.Preset(name, overrides?) -> Options

A shallow copy of the named preset with `overrides` applied on top. An unknown name yields just the overrides.
Equivalent to passing `{ Preset = name, ... }` straight to `Create`, but useful when you want to hold on to the
resulting options table.

```lua
local style = BlockText.Preset("Arcade", { CubeSize = 0.4 })
local a = BlockText.Create(attachmentA, "READY", style)
local b = BlockText.Create(attachmentB, "GO", style)
```

### BlockText.Presets

The table of ready-made option bundles, keyed by name.

| Preset | What it sets |
| --- | --- |
| `Hologram` | `FollowCamera = true`, `Outline = false`, `ToneVariation = 0.1`, `FloatHeight = 0.3`, `MoveFrequency = 6`, a cyan-to-blue `Gradient`. |
| `Arcade` | `PlayerInteraction = true`, `ToneVariation = 0.16`, `RebuildStyle = "Typewriter"`, a magenta-to-cyan `Gradient`. |
| `Toon` | `Color` golden yellow, `Outline = true`, `ToneVariation = 0.12`, `RebuildStyle = "Relocate"`. |
| `Ghost` | `Color` pale blue-white, `Outline = false`, `ToneVariation = 0.08`, `FloatHeight = 0.5`, `FloatSpeed = 1.6`, `MoveFrequency = 4`, `MoveDamping = 0.9`. |
| `Rainbow` | `Rainbow = true`, `GradientSpeed = 0.15`, `RainbowSpan = 1`, `FollowCamera = true`, `ToneVariation = 0.08`. |
| `Confetti` | `PlayerInteraction = true`, `ToneVariation = 0.2`, `RebuildStyle = "Scatter"`, a four-stop red / yellow / green / blue `Gradient`. |

The table is the live one, so you can add your own bundles to it:

```lua
BlockText.Presets.Warning = { Color = Color3.fromRGB(255, 80, 60), RebuildStyle = "Rise" }
```

### BlockText.RebuildStyles

An array of every valid [`RebuildStyle`](#rebuildstyle) string, in order:
`{ "Relocate", "Shuffle", "Rebuild", "Scatter", "Rise", "Typewriter" }`. Handy for building a debug picker or
for validating input.

### BlockText.SetReducedMotion(provider?)

Installs a global "reduce motion" check, polled every frame by every word. While it returns `true`, each word
drops the float, the wobble, the touch interaction and the transition animation, and snaps straight to its rest
pose -- the text stays fully readable, it just stops moving. Animated colors freeze too.

```lua
BlockText.SetReducedMotion(function()
	return Settings.Get("ReduceMotion") == true
end)
```

Pass `nil` to clear it. A word that supplies its own `ReducedMotion` option uses that instead of the global
check.

### BlockText.Font

The [`Font`](#font) module, re-exported so you do not have to require it separately -- mainly for `Font.ARROW`
and `Font.SetGlyph`.

## Options

Every field is optional. Defaults below are what the module uses when the field is absent (and no preset
supplies it).

### Preset

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `Preset` | `string` | none | Start from a `BlockText.Presets` bundle. Every other field in this table overrides that preset. |

### Appearance

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `Color` | `Color3` | `Color3.fromRGB(255, 255, 255)` | Flat body color, used when no `Gradient` is set. |
| `Gradient` | `{ Color3 }` | none | Two or more stops lerped across the word along `GradientRotation`. Overrides `Color`. Blending happens in HSV, so the midpoint stays a vibrant hue instead of dipping toward gray, and each segment is smoothstepped so the sweep eases *through* every stop. |
| `GradientRotation` | `number` | `0` | Angle of the gradient sweep, in degrees. `0` = left to right, `90` = bottom to top. |
| `GradientSpan` | `number` | `1` | How many times the gradient repeats across the text. Below `1` zooms into part of it. |
| `GradientSpeed` | `number` | `0` | Cycles per second the gradient (or the rainbow) scrolls across the text. `0` is static. |
| `Rainbow` | `boolean` | `false` | Animated continuous hue rainbow at full saturation and value. Overrides `Color` and `Gradient`. |
| `RainbowSpan` | `number` | `1` | How many full hue wraps span the text at once. |
| `ToneVariation` | `number` | `0.12` | Amplitude of the soft directional lightness sheen laid over the resolved color: one smooth ramp down a mostly-vertical top-left to bottom-right diagonal, so the block reads as lit from above. It only ever shifts the HSV *value*, so every cube stays the same color, just a lighter or darker shade of it. `0` is flat. Negative values are clamped to `0`. |
| `Material` | `Enum.Material` | the template's own | Override the material of the template's `Inner` body. |
| `Outline` | `boolean` | `true` | Keep the template's `Outer` outline shell, when it has one. `false` destroys it on each clone. No effect on a template without an `Outer`. |
| `OutlineColor` | `Color3` | the template's own | Recolor the outline shell. Only applies when the outline is kept. |

### Geometry

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `Template` | `Model` | the built-in neon cube | Cube Model to clone: a BasePart named `Inner`, plus an optional BasePart named `Outer`. A clone with no `Inner` is skipped entirely. |
| `CubeSize` | `number` | `0.6` | Edge length of one cube at full scale, in studs. |
| `CellStep` | `number` | `CubeSize * 1.2` | Center-to-center spacing between grid cells, in studs. |
| `Mirror` | `boolean` | `false` | Flip the layout horizontally, for when the word reads backwards from where it is being viewed. |
| `Parent` | `Instance` | `Workspace` | Where the cube container Folder goes. |

### Motion

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `MoveFrequency` | `number` | `7` | Angular frequency of the position spring. Lower is a slower, floatier glide. Clamped to a minimum of `0.1`. |
| `MoveDamping` | `number` | `0.85` | Damping ratio of the position spring. Below `1` it overshoots and bounces; the stepper clamps the ratio just under `1`. |
| `FloatHeight` | `number` | `0.18` | Per-letter bob amplitude, in studs. `0` disables the bob. |
| `FloatSpeed` | `number` | `2.4` | Per-letter bob speed. |
| `Wobble` | `number` | `5` | Per-letter idle tumble amplitude, in degrees. Every cube of a letter shares the phase, so the letter tilts as one unit and its faces shimmer. `0` disables it. |
| `WobbleSpeed` | `number` | `1.2` | Per-letter tumble speed. |
| `RebuildStyle` | [`RebuildStyle`](#rebuildstyle) | `"Relocate"` | Default transition used by `SetText` when the call does not pass its own. |

The grow-in / shrink-out scale spring is deliberately snappier than the position spring and is not
configurable.

### Orientation

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `FollowCamera` | `boolean` | `false` | Billboard the whole word to the current camera so it reads from any angle. |
| `FaceTarget` | [`FaceTargetProvider`](#facetargetprovider) | none | Aim the word's local +X at a world point every frame. Takes priority over `FollowCamera`. |

Orientation priority per frame: an aimed `FaceTarget` beats a `FollowCamera` billboard, which beats the
anchor's own CFrame.

### Interaction

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `PlayerInteraction` | `boolean` | `false` | Push and squash cubes that a character walks through. Can be toggled later with `Handle:SetPlayerInteraction`. |
| `TouchSources` | [`TouchSourceProvider`](#touchsourceprovider) | the local player's character parts | What does the pushing. At most 8 sources are sampled per frame. |
| `TouchRadius` | `number` | `6` | Interaction reach, in studs. A cube inside this radius is pushed, with the strength falling off linearly to zero at the edge. |
| `TouchStrength` | `number` | `3.5` | How far a fully-touched cube is shoved, in studs. |

A touched cube is also squashed -- down to 45% of its scale at full contact -- and springs back once the source
moves away.

### Lifecycle

| Field | Type | Default | Description |
| --- | --- | --- | --- |
| `Lifetime` | `number` | none | Auto-destroy the word after N seconds. Absent means the caller owns the lifetime. |
| `ReducedMotion` | `() -> boolean` | the global check | Per-word accessibility override, polled every frame. Used *instead of* the provider given to `BlockText.SetReducedMotion`, so returning `false` here opts this word out of the global setting. |

## Handle

Returned by `BlockText.Create`. Every method is a no-op after the word has been destroyed.

| Member | Signature |
| --- | --- |
| `Container` | `Instance` |
| `SetText` | `(self, text: string, style: RebuildStyle?) -> ()` |
| `SetAnchor` | `(self, anchor: Anchor) -> ()` |
| `SetFaceTarget` | `(self, provider: FaceTargetProvider?) -> ()` |
| `SetScale` | `(self, multiplier: number) -> ()` |
| `SetPlayerInteraction` | `(self, enabled: boolean) -> ()` |
| `Destroy` | `(self) -> ()` |

### Container

The Folder holding every cube of this word. Read-only: destroying it directly leaves the handle stale -- call
`Destroy` instead.

### Handle:SetText(text, style?)

Rebuilds the word. `style` overrides the `RebuildStyle` option for this one call.

The reuse styles (`"Relocate"`, `"Shuffle"`) keep the cubes currently on screen and spring them over to the new
slots, which is what morphs one word into the next instead of cutting between them. The other styles retire
every cube and spawn a fresh set. Surplus cubes -- when the new word is shorter -- shrink out and are cleaned up
automatically.

```lua
handle:SetText("SCORE: 1200")
handle:SetText("NEW HIGH\nSCORE", "Rise")
```

### Handle:SetAnchor(anchor)

Retargets the word to a new [`Anchor`](#anchor). The world-space spring makes the letters glide over to it
rather than teleport.

### Handle:SetFaceTarget(provider?)

Installs or replaces the [`FaceTargetProvider`](#facetargetprovider). Pass `nil` to revert to `FollowCamera`, or
to the anchor's own facing.

### Handle:SetScale(multiplier)

Uniformly scales the whole word -- cube size and grid spacing together. `1` is the authored size, and negative
values are clamped to `0`.

**Takes effect on the next `SetText`**, because the layout slots are computed at build time. Call it just before
retargeting or rebuilding the text:

```lua
handle:SetScale(2)
handle:SetText("BIG")
```

### Handle:SetPlayerInteraction(enabled)

Turns the push/squash-on-touch behavior on or off at runtime. Overrides the `PlayerInteraction` option.

### Handle:Destroy()

Destroys the container and every cube, and unregisters the word from the shared frame loop. Safe to call more
than once. When the last live word is destroyed, the shared `Heartbeat` connection disconnects itself.

## Types

### Anchor

```lua
export type Anchor = Attachment | (() -> CFrame?)
```

Where the word is anchored.

- **`Attachment`** -- the word follows the attachment's `WorldCFrame`, and self-destructs once that attachment
  leaves the DataModel.
- **`() -> CFrame?`** -- polled every frame for a CFrame. A provider that returns `nil` **holds the last known
  frame** instead of destroying, so a word can outlive a momentarily-absent character (a respawn, a streamed-out
  model) and re-anchor when it comes back.

### FaceTargetProvider

```lua
export type FaceTargetProvider = () -> Vector3?
```

World position the layout frame aims its local +X at each frame. Returning `nil` skips the aiming for that frame
and falls back to `FollowCamera` or the anchor's own orientation.

The aim is full 3D: the yaw comes from the ground-plane heading and the pitch from the height difference, so an
arrow points exactly *at* the target rather than merely in its compass direction. Local +Y stays the horizontal
side vector, so the word tilts about that axis and never rolls. When the target sits almost directly above or
below the anchor (within 0.05 studs horizontally) the heading is undefined, so that frame keeps its fallback
orientation instead of snapping to an arbitrary one.

### TouchSourceProvider

```lua
export type TouchSourceProvider = () -> { Vector3 }?
```

World positions that push cubes around when `PlayerInteraction` is on. Returning `nil` falls back to the local
player's character parts. Since this is called every frame, **return a table you reuse** rather than allocating a
fresh one. At most 8 positions are read per frame.

### RebuildStyle

```lua
export type RebuildStyle = "Relocate" | "Shuffle" | "Rebuild" | "Scatter" | "Rise" | "Typewriter"
```

| Style | Transition |
| --- | --- |
| `"Relocate"` | Reuses the cubes already on screen and glides each one to its new slot. The default. |
| `"Shuffle"` | Reuses them as well, but pairs each cube with a scrambled slot, so the letters cross over each other on the way. |
| `"Rebuild"` | Shrinks the old word out and grows the new one in, in place. |
| `"Scatter"` | The old cubes explode outward in random directions and the new ones fly back in, from 10 studs out. |
| `"Rise"` | The old cubes fall out downward and the new ones rise back up, over 5 studs. |
| `"Typewriter"` | Clears the word, then pops the letters in left to right, 0.07 s apart. |

## Font

`BlockText.Font`, also available as the `Font` child module. Pure data plus layout math with **no Roblox
instances**, so the glyph table and the string-to-cell layout run in any plain Luau runtime and are unit-tested
outside Studio. `BlockText` is what turns the returned cells into real animated cubes.

Glyphs are authored uppercase-only as 5-row bitmaps of `#` (a filled cube) and space (empty). Letters `A`-`Z`
and digits `0`-`9` are 5 columns wide for legible letterforms; the punctuation set
(`: . , ' ! - + = * % ( ) / \ ? # $`) stays narrower where it should. Adjacent glyphs are separated by one blank
column, a space advances one column, and lines are separated by one blank row. Lowercase folds to uppercase, and
any character without a glyph renders as a blank space.

| Member | Signature |
| --- | --- |
| `Font.Height` | `number` -- `5` |
| `Font.ARROW` | `string` |
| `Font.Rows` | `(char: string) -> { string }?` |
| `Font.Width` | `(char: string) -> number` |
| `Font.SetGlyph` | `(char: string, rows: { string }) -> ()` |
| `Font.Layout` | `(text: string) -> Layout` |

### Font.Height

The row count every glyph must have: `5`. Fixed, because the renderer assumes a uniform baseline.

### Font.ARROW

The key of the built-in right-pointing arrow glyph (`"\u{2192}"`), exported so you can render it without
embedding a multibyte literal in your own code. It is 7 columns wide: a full-width shaft with a chevron head at
the +X end, so the glyph points along the layout frame's local +X. Combine it with the `FaceTarget` option to
aim that +X at a world position and you get a waypoint arrow that always points at its destination.

```lua
BlockText.Create(anchor, BlockText.Font.ARROW, { FaceTarget = function() return destination end })
```

### Font.Rows(char) -> { string }?

The bitmap rows for a character, or `nil` when it has no glyph. The character must already be upper-cased.

### Font.Width(char) -> number

The column count a character occupies. Spaces -- and unknown characters, which render blank -- report `1`.
Matching is case-insensitive.

### Font.SetGlyph(char, rows)

Registers or replaces a glyph. Keys are matched after upper-casing and may be multibyte UTF-8, so you can add
symbols outside ASCII.

`rows` must have exactly `Font.Height` rows, all of equal length, made of `#` (filled) and any other character
(empty). Both rules are asserted: the renderer assumes a uniform baseline, so a short glyph would float and a
ragged one would tear the layout.

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

Lays a string out into filled cells centered on the block's origin. `\n` starts a new line; each line is
centered horizontally on its own width, and the stack of lines is centered vertically.

```lua
local layout = Font.Layout("HELLO\nWORLD")
-- layout.Width  = 29 -- five 5-wide glyphs and the four gaps between them
-- layout.Height = 11 -- two 5-row lines and the blank row between them
-- layout.Cells  = { { X = -14, Y = 5, Letter = 1 }, ... }
```

### Cell

```lua
export type Cell = { X: number, Y: number, Letter: number }
```

| Field | Meaning |
| --- | --- |
| `X` | Column position in **cell units**, relative to the center of the whole block. Grows to the right. |
| `Y` | Row position in **cell units**, relative to the center of the whole block. Grows upward. |
| `Letter` | The 1-based index of the source character this cell belongs to. |

The coordinate system is deliberately centered and unit-less: all the centering -- each line horizontally, and
the stack of lines vertically -- is already done, so a renderer just multiplies `X` and `Y` by a stud step.
Rows are authored top (index 1) to bottom (index `Font.Height`), but `Y` comes out already flipped so that up is
positive. When a line's column span (or the total row span) is even, the values land on halves -- that is
correct, the block is centered rather than snapped to the grid.

`Letter` is what lets cells be grouped per character, which is how BlockText floats and tumbles each letter of a
word on its own phase while every cube inside one letter stays locked together. Note that a `\n` counts as a
source character too, so in `"A\nB"` the `B` cells carry `Letter = 3`.

### Layout

```lua
export type Layout = { Cells: { Cell }, Width: number, Height: number }
```

| Field | Meaning |
| --- | --- |
| `Cells` | Every filled cell of the text. Empty for empty or fully-unknown text. |
| `Width` | The widest line's column span, with the trailing inter-glyph gap trimmed. |
| `Height` | The total row span across all lines, including the blank row between them. |

`Width` and `Height` are in cell units, and are what BlockText normalizes the gradient and the tonal sheen
against, so both sweep edge to edge at any word size.
