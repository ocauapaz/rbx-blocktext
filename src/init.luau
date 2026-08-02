--!strict

-- BlockText -- floating 3D text built from springy cubes.
--
-- Renders a string as a grid of cubes in the world, each one driven by an analytic spring (`Spring`) for BOTH
-- its position and its scale -- no TweenService anywhere. Every cube owns its own `(position, velocity)` and
-- `(scale, velocity)` and springs toward a WORLD target = the anchor's frame times the cube's layout slot.
-- Because the follow happens in world space, a moving anchor DRAGS the letters along smoothly (they trail and
-- then settle) instead of snapping, and the very same spring morphs the word when `SetText` relocates cubes to
-- new slots.
--
-- Features, all optional:
--   * Fluid follow       -- cubes spring toward the anchor; `MoveFrequency`/`MoveDamping` tune how floaty it is.
--   * Per-letter float   -- each letter bobs and tumbles on its own phase, so the word ripples instead of
--                           sliding around as one rigid slab.
--   * Touch interaction  -- cubes near a character are pushed away and squashed, then spring back.
--   * Rebuild styles     -- how a `SetText` transition looks (set a default at `Create`, or per call):
--       "Relocate"   reuse the cubes and glide each to its nearest new slot (default)
--       "Shuffle"    reuse them, but cross to a scrambled slot
--       "Rebuild"    shrink the old word out, grow the new one in
--       "Scatter"    explode outward, fly back in
--       "Rise"       fall out downward, rise back up
--       "Typewriter" clear, then pop the letters in left to right
--   * Follow camera      -- billboards the whole word so it stays readable from any angle.
--   * Face target        -- aims the word's local +X at a world point every frame; combine with `Font.ARROW`
--                           for a waypoint arrow that always points at its destination.
--   * Gradient + tone    -- the color lerps across the word at any angle, optionally scrolling or as an
--                           animated rainbow, with a soft directional sheen so the block reads as lit.
--   * Custom cubes       -- bring your own Model (`Template`) for outlined, textured or oddly-shaped letters.
--
-- PRESENTATION ONLY: call this on the client. Every live word shares ONE Heartbeat connection and ONE
-- `BulkMoveTo` per frame, so a screenful of words costs a single engine round trip rather than hundreds.
--
--   local BlockText = require(ReplicatedStorage.Packages.BlockText)
--
--   local handle = BlockText.Create(attachment, "HELLO", BlockText.Preset("Hologram"))
--   handle:SetText("WORLD", "Scatter")
--   handle:Destroy()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local CubeTemplate = require(script.CubeTemplate)
local Font = require(script.Font)
local Spring = require(script.Spring)

export type RebuildStyle = "Relocate" | "Shuffle" | "Rebuild" | "Scatter" | "Rise" | "Typewriter"

-- Where the word is anchored. Either an Attachment -- the default, and the word self-destructs once that
-- attachment leaves the DataModel -- or a function polled every frame for a CFrame. A provider that returns nil
-- HOLDS the last frame instead of destroying, so a word can outlive a momentarily-absent character (a respawn,
-- a streamed-out model) and re-anchor when it comes back.
export type Anchor = Attachment | (() -> CFrame?)

-- World position the layout frame aims its local +X at each frame. Returning nil skips the aiming for that
-- frame and falls back to `FollowCamera` / the anchor's own orientation.
export type FaceTargetProvider = () -> Vector3?

-- World positions that push cubes around when `PlayerInteraction` is on. Return a table you REUSE if you call
-- this every frame. Defaults to the local player's character parts when not supplied.
export type TouchSourceProvider = () -> { Vector3 }?

export type Options = {
	Preset: string?, -- start from a `BlockText.Presets` bundle; every other field here overrides that preset

	-- Appearance
	Color: Color3?, -- flat body color, used when no `Gradient` is set
	Gradient: { Color3 }?, -- 2+ stops lerped across the word along `GradientRotation` (overrides `Color`)
	GradientRotation: number?, -- angle of the gradient sweep in degrees: 0 = left->right, 90 = bottom->top
	GradientSpan: number?, -- how many times the gradient repeats across the text (default 1; < 1 zooms in)
	GradientSpeed: number?, -- cycles/sec the gradient (or rainbow) scrolls across the text; 0 = static (default)
	Rainbow: boolean?, -- animated continuous hue rainbow (overrides `Color`/`Gradient`)
	RainbowSpan: number?, -- how many full hue wraps span the text at once (default 1)
	ToneVariation: number?, -- soft directional lightness sheen over the resolved color; 0 = flat (default 0.12)
	Material: Enum.Material?, -- override the template body's material (default: whatever the template uses)
	Outline: boolean?, -- keep the template's `Outer` outline shell, when it has one (default true)
	OutlineColor: Color3?, -- recolor that outline shell (default: keeps the template's own color)

	-- Geometry
	Template: Model?, -- cube Model to clone: a BasePart `Inner`, plus an optional BasePart `Outer` outline
	CubeSize: number?, -- edge length of one cube at full scale, in studs
	CellStep: number?, -- center-to-center spacing between grid cells, studs (default `CubeSize` * 1.2)
	Mirror: boolean?, -- flip horizontally, for when the word reads backwards from where it is being viewed
	Parent: Instance?, -- where the cube container goes (default Workspace)

	-- Motion
	MoveFrequency: number?, -- position spring angular frequency; lower = slower, floatier glide (default 7)
	MoveDamping: number?, -- position spring damping ratio; below 1 overshoots and bounces (default 0.85)
	FloatHeight: number?, -- per-letter bob amplitude in studs (0 disables)
	FloatSpeed: number?, -- per-letter bob speed
	Wobble: number?, -- per-letter idle tumble amplitude in degrees (0 disables); makes the faces shimmer
	WobbleSpeed: number?, -- per-letter tumble speed
	RebuildStyle: RebuildStyle?, -- default `SetText` transition (default "Relocate")

	-- Orientation
	FollowCamera: boolean?, -- billboard the word to the camera so it reads from any angle
	FaceTarget: FaceTargetProvider?, -- aim the word's local +X at a world point each frame (beats FollowCamera)

	-- Interaction
	PlayerInteraction: boolean?, -- push and squash cubes that a character walks through
	TouchSources: TouchSourceProvider?, -- what does the pushing (default: the local player's character)
	TouchRadius: number?, -- interaction reach, studs
	TouchStrength: number?, -- how far a touched cube is shoved, studs

	-- Lifecycle
	Lifetime: number?, -- auto-destroy after N seconds (nil = the caller owns the lifetime)
	ReducedMotion: (() -> boolean)?, -- per-word accessibility override; see `BlockText.SetReducedMotion`
}

export type Handle = {
	-- The Folder holding every cube of this word. Read-only: destroying it directly leaves the handle stale.
	Container: Instance,
	SetText: (self: Handle, text: string, style: RebuildStyle?) -> (),
	-- Retarget the word to a new anchor; the world-space spring makes the letters glide over to it.
	SetAnchor: (self: Handle, anchor: Anchor) -> (),
	-- Point the word at a world target, or pass nil to revert to `FollowCamera` / the anchor's own facing.
	SetFaceTarget: (self: Handle, provider: FaceTargetProvider?) -> (),
	-- Uniformly scale the whole word (cube size and grid spacing together); 1 is the authored size. Takes
	-- effect on the next `SetText`, so call it just before retargeting or rebuilding the text.
	SetScale: (self: Handle, multiplier: number) -> (),
	-- Turn the push/squash-on-touch behaviour on or off at runtime (overrides the `PlayerInteraction` option).
	SetPlayerInteraction: (self: Handle, enabled: boolean) -> (),
	Destroy: (self: Handle) -> (),
}

type CubeState = {
	Model: Model?, -- nil once destroyed; doubles as the liveness marker
	Inner: BasePart?,
	Outer: BasePart?,
	Letter: number, -- source-character index: cubes of the same letter float and tumble together as a unit
	GradientPos: number, -- 0..1 position along the gradient axis (drives both static and animated coloring)
	ToneShade: number, -- static HSV-value delta for this cube's share of the tonal sheen
	LocalX: number, -- rest slot in the text frame's local space
	LocalY: number,
	LocalZ: number,
	PosX: number, -- current sprung WORLD position
	PosY: number,
	PosZ: number,
	VelX: number,
	VelY: number,
	VelZ: number,
	Scale: number,
	ScaleVel: number,
	ScaleTarget: number,
	AppliedScale: number, -- last scale written to the parts, so they are only resized when it actually changes
	Retiring: boolean,
	SpawnSnap: boolean, -- fresh cube: on its first frame, teleport to (world target + SpawnOffset), then spring in
	SpawnOffset: Vector3, -- world offset a fresh cube starts at (the fly-in styles)
	RetireOffset: Vector3, -- world drift added to a retiring cube's target (the scatter/fall styles)
	RevealAt: number, -- elapsed time before a fresh cube starts growing (typewriter stagger); 0 = immediate
}

local REBUILD_STYLES: { RebuildStyle } = { "Relocate", "Shuffle", "Rebuild", "Scatter", "Rise", "Typewriter" }

local DEFAULT_COLOR = Color3.fromRGB(255, 255, 255)
local DEFAULT_TONE_VARIATION = 0.12
-- The tonal sheen is a single smooth light ramp down a top-left -> bottom-right diagonal (weighted mostly
-- vertical), so the block reads as lit from above instead of striped by a repeating wave. These weight the
-- vertical against the horizontal contribution to that diagonal.
local TONE_VERTICAL_WEIGHT = 0.7
local TONE_HORIZONTAL_WEIGHT = 0.3
-- Rainbow mode paints full-vibrancy hues; the span defaults to one full color wheel across the text.
local RAINBOW_SATURATION = 1
local RAINBOW_VALUE = 1
local DEFAULT_RAINBOW_SPAN = 1
local DEFAULT_GRADIENT_SPAN = 1
local DEFAULT_CUBE_SIZE = 0.6
local DEFAULT_CELL_STEP_RATIO = 1.2 -- gap between cubes, as a multiple of the cube edge
local DEFAULT_MOVE_FREQUENCY = 7 -- deliberately slow, for a floaty glide rather than a snap
local DEFAULT_MOVE_DAMPING = 0.85
local DEFAULT_SCALE_FREQUENCY = 16 -- the grow/shrink spring is snappier than the position one
local DEFAULT_SCALE_DAMPING = 0.7
local DEFAULT_FLOAT_HEIGHT = 0.18
local DEFAULT_FLOAT_SPEED = 2.4
local DEFAULT_WOBBLE = 5 -- degrees of gentle idle tumble, kept subtle so the grid stays readable
local DEFAULT_WOBBLE_SPEED = 1.2
local DEFAULT_TOUCH_RADIUS = 6
local DEFAULT_TOUCH_STRENGTH = 3.5

-- Per-letter phase offsets (radians of bob, and of tumble on each axis) so letters move out of sync with one
-- another while every cube INSIDE one letter stays locked together -- the letter floats and tilts as a unit.
local FLOAT_PHASE_STEP = 0.7
local LETTER_SPIN_X = 1.7
local LETTER_SPIN_Y = 2.6
local LETTER_SPIN_Z = 3.4

-- Slightly mismatched per-axis tumble frequencies, so the wobble never resolves into a flat spin.
local WOBBLE_FREQ_X = 1
local WOBBLE_FREQ_Y = 1.31
local WOBBLE_FREQ_Z = 0.77

local SPAWN_SCALE = 0.02 -- cubes grow in from here, via the scale spring
local RETIRE_SCALE = 0.03 -- a retiring cube is destroyed once it has shrunk below this
local SQUASH_FACTOR = 0.45 -- how much a fully-touched cube shrinks (its deform on contact)
local MAX_PUSHERS = 8 -- how many touch sources are sampled per frame
local SCATTER_DISTANCE = 10 -- how far "Scatter" cubes fly out and back in, studs
local RISE_DISTANCE = 5 -- how far "Rise" cubes fall and rise, studs
local TYPE_LETTER_DELAY = 0.07 -- "Typewriter" reveal delay per letter, seconds
local SIZE_EPSILON = 0.0005 -- skip resizing the parts when the scale change is smaller than this
local MIN_PUSH_DISTANCE_SQ = 1e-6 -- below this a push direction is undefined, so that source is ignored
-- Below this horizontal distance to a `FaceTarget` the heading is undefined (the target sits directly above or
-- below the anchor), so that frame keeps its fallback orientation instead of snapping to an arbitrary one.
local FACE_TARGET_EPSILON = 0.05

local BlockText = {}

BlockText.RebuildStyles = REBUILD_STYLES
BlockText.Font = Font

--------------------------------------------------------------------------------------------------------------
-- Reduced motion
--------------------------------------------------------------------------------------------------------------

local globalReducedMotion: (() -> boolean)? = nil

-- Install a global "reduce motion" check, polled every frame. While it returns true, every word drops the
-- float, wobble, touch interaction and transition animation and snaps straight to its rest pose -- the text
-- stays fully readable, it just stops moving. Wire this to your accessibility setting once at startup:
--
--   BlockText.SetReducedMotion(function() return Settings.Get("ReduceMotion") == true end)
--
-- A single word can opt out with its own `ReducedMotion` option. Pass nil here to clear the global check.
function BlockText.SetReducedMotion(provider: (() -> boolean)?)
	globalReducedMotion = provider
end

--------------------------------------------------------------------------------------------------------------
-- Shared frame loop
--------------------------------------------------------------------------------------------------------------

-- All live words share ONE Heartbeat: each word's stepper computes its cubes' new CFrames into a shared batch,
-- and the frame ends with a single `Workspace:BulkMoveTo`. Per-cube `.CFrame` writes (two per cube, body and
-- outline) profile as the dominant cost of this system; BulkMoveTo collapses hundreds of property round trips
-- into one engine call, and `FireCFrameChanged` skips the Position/Orientation changed-signal fanout -- nothing
-- ever listens to these cubes.
type Stepper = (deltaTime: number) -> ()

local steppers: { [Instance]: Stepper } = {}
local sharedHeartbeat: RBXScriptConnection? = nil
local bulkParts: { BasePart } = {}
local bulkCFrames: { CFrame } = {}

-- MicroProfiler scope, so this system shows up as a named block in the timeline instead of being lumped into
-- the engine's aggregated "$Event" bucket. Resolved once, and a no-op outside Roblox (e.g. a Luau test runner).
local profileBegin: ((string) -> ())? = (debug :: any).profilebegin
local profileEnd: (() -> ())? = (debug :: any).profileend
local PROFILE_LABEL = "BlockText"

local function sharedStep(deltaTime: number)
	if profileBegin ~= nil then
		profileBegin(PROFILE_LABEL)
	end

	table.clear(bulkParts)
	table.clear(bulkCFrames)
	for _, stepper in steppers do
		stepper(deltaTime)
	end
	if #bulkParts > 0 then
		Workspace:BulkMoveTo(bulkParts, bulkCFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	-- The last word destroying itself takes the connection down with it, so an idle game pays nothing.
	if next(steppers) == nil and sharedHeartbeat ~= nil then
		sharedHeartbeat:Disconnect()
		sharedHeartbeat = nil
	end

	if profileEnd ~= nil then
		profileEnd()
	end
end

local function registerStepper(key: Instance, stepper: Stepper)
	steppers[key] = stepper
	if sharedHeartbeat == nil then
		sharedHeartbeat = RunService.Heartbeat:Connect(sharedStep)
	end
end

local function unregisterStepper(key: Instance)
	steppers[key] = nil
end

--------------------------------------------------------------------------------------------------------------
-- Color helpers
--------------------------------------------------------------------------------------------------------------

local function option<T>(value: T?, fallback: T): T
	return if value ~= nil then value else fallback
end

-- Uniformly random unit vector, for the cosmetic scatter directions. Purely visual, so the shared `math.random`
-- is fine here -- nothing about a word's look needs a seeded or server-authoritative generator.
local function randomUnit(): Vector3
	local theta = math.random() * 2 * math.pi
	local z = math.random() * 2 - 1
	local radius = math.sqrt(math.max(1 - z * z, 0))
	return Vector3.new(radius * math.cos(theta), radius * math.sin(theta), z)
end

-- Interpolate a hue (0..1 around the wheel) along the SHORTER arc, so red -> magenta does not detour all the
-- way through cyan.
local function lerpHue(from: number, to: number, t: number): number
	local diff = to - from
	if diff > 0.5 then
		diff -= 1
	elseif diff < -0.5 then
		diff += 1
	end
	return (from + diff * t) % 1
end

-- Blend two colors in HSV rather than RGB, so the midpoint stays a vibrant hue between them instead of dipping
-- toward gray. A (near) grayscale end has no meaningful hue of its own, so it borrows the other end's hue to
-- keep the sweep clean.
local function lerpColor(from: Color3, to: Color3, t: number): Color3
	local hueFrom, satFrom, valueFrom = from:ToHSV()
	local hueTo, satTo, valueTo = to:ToHSV()
	local anchoredFrom = if satFrom > 0.001 then hueFrom else hueTo
	local anchoredTo = if satTo > 0.001 then hueTo else hueFrom
	return Color3.fromHSV(
		lerpHue(anchoredFrom, anchoredTo, t),
		satFrom + (satTo - satFrom) * t,
		valueFrom + (valueTo - valueFrom) * t
	)
end

-- Base color for a cube at `fraction` along the gradient (0 at its start, 1 at its end): find the pair of stops
-- it falls between and blend them in HSV, with a smoothstep on the segment so the sweep eases THROUGH each stop
-- instead of kinking at it.
local function gradientColor(gradient: { Color3 }, fraction: number): Color3
	local stops = #gradient
	if stops == 1 then
		return gradient[1]
	end
	local scaled = math.clamp(fraction, 0, 1) * (stops - 1)
	local lower = math.floor(scaled)
	local upper = math.min(lower + 1, stops - 1)
	local segment = scaled - lower
	local eased = segment * segment * (3 - 2 * segment)
	return lerpColor(gradient[lower + 1], gradient[upper + 1], eased)
end

-- Cyclic variant, for the scrolling animation: the stops form a ring (the last blends back into the first) so a
-- fraction that keeps advancing loops seamlessly instead of snapping at the ends.
local function gradientColorCyclic(gradient: { Color3 }, fraction: number): Color3
	local stops = #gradient
	if stops == 1 then
		return gradient[1]
	end
	local scaled = (fraction % 1) * stops
	local floored = math.floor(scaled)
	local lower = floored % stops
	local upper = (lower + 1) % stops
	local segment = scaled - floored
	local eased = segment * segment * (3 - 2 * segment)
	return lerpColor(gradient[lower + 1], gradient[upper + 1], eased)
end

-- Shift a color's brightness (its HSV value) by a signed delta, keeping hue and saturation, so the result is
-- the SAME color -- just a lighter or darker shade of it. Never a different tint, never washed toward white.
local function shadeValue(color: Color3, delta: number): Color3
	local hue, saturation, value = color:ToHSV()
	return Color3.fromHSV(hue, saturation, math.clamp(value + delta, 0, 1))
end

--------------------------------------------------------------------------------------------------------------
-- Layout / template helpers
--------------------------------------------------------------------------------------------------------------

-- A cube's slot in studs on the frame's local XY plane, from the font cell's already-centered X/Y. X runs along
-- local +X, so the word reads left-to-right for a viewer on the frame's front (+Z) -- which is exactly where the
-- camera sits in `FollowCamera` mode. `Mirror` flips it.
local function cellSlotX(cell: Font.Cell, step: number, mirror: boolean): number
	return (if mirror then -cell.X else cell.X) * step
end

-- World drift a retiring cube of this style should exit along.
local function retireOffset(style: RebuildStyle): Vector3
	if style == "Scatter" then
		return randomUnit() * SCATTER_DISTANCE
	elseif style == "Rise" then
		return Vector3.new(0, -RISE_DISTANCE, 0)
	end
	return Vector3.zero
end

-- Strip a cloned cube part of everything the renderer does not want it to do. These cubes are pure decoration:
-- they must not collide, block raycasts, fire touch events, weigh anything, or cast shadows.
local function setupCubePart(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
end

-- Shallow-merge two option tables, where `overrides` win. Used to layer a caller's tweaks on top of a preset
-- (base = the preset, overrides = what the caller passed), so `{ Preset = "Rainbow", CubeSize = 0.3 }` works.
local function mergeOptions(base: Options?, overrides: Options?): Options
	local merged: { [string]: any } = {}
	if base ~= nil then
		for key, value in base :: any do
			merged[key] = value
		end
	end
	if overrides ~= nil then
		for key, value in overrides :: any do
			merged[key] = value
		end
	end
	return merged :: any
end

--------------------------------------------------------------------------------------------------------------
-- Create
--------------------------------------------------------------------------------------------------------------

-- Build a word. Returns a handle you own: nothing else will destroy it unless the anchor Attachment leaves the
-- DataModel or `Lifetime` elapses.
function BlockText.Create(anchor: Anchor, text: string, options: Options?): Handle
	local opts: Options = options or {}
	if opts.Preset ~= nil then
		-- Layer the caller's own fields over the named preset.
		opts = mergeOptions(BlockText.Presets[opts.Preset], opts)
	end

	local baseColor = option(opts.Color, DEFAULT_COLOR)
	local gradient = opts.Gradient
	local gradientAngle = math.rad(option(opts.GradientRotation, 0))
	local gradientCos = math.cos(gradientAngle)
	local gradientSin = math.sin(gradientAngle)
	local gradientSpan = option(opts.GradientSpan, DEFAULT_GRADIENT_SPAN)
	local gradientSpeed = option(opts.GradientSpeed, 0)
	local rainbow = option(opts.Rainbow, false)
	local rainbowSpan = option(opts.RainbowSpan, DEFAULT_RAINBOW_SPAN)
	-- Colors need a per-frame refresh only when something about them actually moves: a rainbow, or a gradient
	-- that scrolls. A static word writes each cube's color exactly once, when the cube takes its slot.
	local animated = rainbow or (gradient ~= nil and #gradient > 0 and gradientSpeed ~= 0)
	local toneVariation = math.max(option(opts.ToneVariation, DEFAULT_TONE_VARIATION), 0)
	local materialOverride = opts.Material
	local cubeSize = option(opts.CubeSize, DEFAULT_CUBE_SIZE)
	local cellStep = option(opts.CellStep, cubeSize * DEFAULT_CELL_STEP_RATIO)
	local outline = option(opts.Outline, true)
	local outlineColorOverride = opts.OutlineColor
	local moveFrequency = math.max(option(opts.MoveFrequency, DEFAULT_MOVE_FREQUENCY), 0.1)
	local moveDamping = option(opts.MoveDamping, DEFAULT_MOVE_DAMPING)
	local floatHeight = option(opts.FloatHeight, DEFAULT_FLOAT_HEIGHT)
	local floatSpeed = option(opts.FloatSpeed, DEFAULT_FLOAT_SPEED)
	local wobble = math.rad(option(opts.Wobble, DEFAULT_WOBBLE))
	local wobbleSpeed = option(opts.WobbleSpeed, DEFAULT_WOBBLE_SPEED)
	local followCamera = option(opts.FollowCamera, false)
	local mirror = option(opts.Mirror, false)
	local interaction = option(opts.PlayerInteraction, false)
	local touchSources = opts.TouchSources
	local touchRadius = option(opts.TouchRadius, DEFAULT_TOUCH_RADIUS)
	local touchStrength = option(opts.TouchStrength, DEFAULT_TOUCH_STRENGTH)
	local reducedMotion = opts.ReducedMotion
	local defaultStyle: RebuildStyle = if opts.RebuildStyle ~= nil then opts.RebuildStyle else "Relocate"

	-- The anchor and the face target start from the options but stay mutable at runtime (`SetAnchor` /
	-- `SetFaceTarget`), so a caller can move the word between anchors and swap billboard and aimed modes.
	local currentAnchor: Anchor = anchor
	local faceTargetProvider: FaceTargetProvider? = opts.FaceTarget
	local lastFrameCF: CFrame? = nil
	-- Uniform runtime scale over cube size and grid spacing (1 = the authored size). Read when laying out slots
	-- and when sizing cubes each frame, which is why `SetScale` takes effect on the next `SetText`.
	local scaleMul = 1

	local container = Instance.new("Folder")
	container.Name = "BlockText"
	container.Parent = option(opts.Parent, Workspace :: Instance)

	local template = if opts.Template ~= nil then opts.Template else CubeTemplate.Get()
	-- Read the outline's proportion straight off the template, so scaling the outer shell to `CubeSize` keeps
	-- the outline exactly as thick as it was authored, at every cube size. No template outline means the body
	-- IS the full cube.
	local innerRatio = 1
	do
		local templateInner = template:FindFirstChild("Inner")
		local templateOuter = template:FindFirstChild("Outer")
		if
			templateInner ~= nil
			and templateInner:IsA("BasePart")
			and templateOuter ~= nil
			and templateOuter:IsA("BasePart")
			and templateOuter.Size.X > 0
		then
			innerRatio = templateInner.Size.X / templateOuter.Size.X
		end
	end

	local cubes: { CubeState } = {}
	local pushers: { Vector3 } = {}
	-- Per-frame memo of each letter's shared float offset and combined (frame rotation * wobble) rotation,
	-- cleared and lazily refilled by the stepper -- so the per-letter trig runs once per LETTER, not once per
	-- cube (a letter is ~15 cubes that would otherwise repeat the same four sines and a CFrame construction).
	local letterFloatY: { [number]: number } = {}
	local letterRotation: { [number]: CFrame? } = {}
	local alive = true
	local elapsed = 0

	-- A cube's 0..1 position along the gradient axis: its centered cell projected onto the `GradientRotation`
	-- direction, normalized by the block's own extent along that direction, so the sweep runs edge to edge at
	-- any word size.
	local function gradientPosFor(x: number, y: number, width: number, height: number): number
		local halfX = (width - 1) / 2
		local halfY = (height - 1) / 2
		local extent = math.abs(gradientCos) * halfX + math.abs(gradientSin) * halfY
		local projection = x * gradientCos + y * gradientSin
		return if extent > 0 then (projection + extent) / (2 * extent) else 0
	end

	-- Static HSV-value delta for this cube's share of the tonal sheen: one soft light ramp along a top-left ->
	-- bottom-right diagonal (mostly vertical). The top of the word keeps the full base color (the highlight) and
	-- it eases toward a darker shade of the SAME color at the bottom, normalized by the block's extent so it
	-- spans edge to edge at any size. Monotonic, so it reads as directional lighting and never as banding.
	local function toneShadeFor(x: number, y: number, width: number, height: number): number
		if toneVariation <= 0 then
			return 0
		end
		local halfX = (width - 1) / 2
		local halfY = (height - 1) / 2
		local nx = if halfX > 0 then (x + halfX) / (2 * halfX) else 0.5 -- 0 at the left edge, 1 at the right
		local ny = if halfY > 0 then (halfY - y) / (2 * halfY) else 0.5 -- 0 at the top edge, 1 at the bottom
		local t = math.clamp(ny * TONE_VERTICAL_WEIGHT + nx * TONE_HORIZONTAL_WEIGHT, 0, 1)
		local eased = t * t * (3 - 2 * t) -- smoothstep: pools softly at the highlight and the shadow ends
		return -eased * toneVariation
	end

	-- The body color for a cube, given its gradient position, its tonal shade and the current time. A rainbow
	-- cycles a continuous hue; a scrolling gradient loops cyclically; otherwise it is the fixed gradient or the
	-- flat color. `time` only matters when `animated` is true.
	local function resolveColor(pos: number, shade: number, time: number): Color3
		local base: Color3
		if rainbow then
			base = Color3.fromHSV((pos * rainbowSpan + time * gradientSpeed) % 1, RAINBOW_SATURATION, RAINBOW_VALUE)
		elseif gradient ~= nil and #gradient > 0 then
			local fraction = pos * gradientSpan + time * gradientSpeed
			if gradientSpan ~= 1 or gradientSpeed ~= 0 then
				-- Repeating or scrolling: the stops tile as a ring, so it wraps seamlessly.
				base = gradientColorCyclic(gradient, fraction)
			else
				-- One static span: anchor the endpoints so the first and last stops sit exactly at the edges.
				base = gradientColor(gradient, fraction)
			end
		else
			base = baseColor
		end
		if shade ~= 0 then
			base = shadeValue(base, shade)
		end
		return base
	end

	-- Base frame the cubes' world slots are computed from. Orientation, in priority order: an aimed `FaceTarget`
	-- beats a `FollowCamera` billboard, which beats the anchor's own CFrame. Returns nil only when an Attachment
	-- anchor has left the DataModel, which is the signal to tear the word down.
	local function resolveFrame(): CFrame?
		local activeAnchor = currentAnchor
		local baseCF: CFrame
		if type(activeAnchor) == "function" then
			local provided = (activeAnchor :: () -> CFrame?)()
			if provided == nil then
				-- A provider with nothing to give holds the last known frame, so the word survives a respawn.
				return lastFrameCF
			end
			baseCF = provided
		else
			local anchorAttachment = activeAnchor :: Attachment
			if anchorAttachment.Parent == nil then
				return nil
			end
			baseCF = anchorAttachment.WorldCFrame
		end

		local position = baseCF.Position
		if faceTargetProvider ~= nil then
			local target = faceTargetProvider()
			if target ~= nil then
				-- Aim the frame's local +X straight at the target in 3D: the yaw comes from the ground-plane
				-- heading and the pitch from the height difference, so an arrow points exactly AT the target
				-- rather than merely in its compass direction. Local +Y stays the horizontal side vector, so the
				-- word only ever tilts about that axis and never rolls.
				local flat = Vector3.new(target.X - position.X, 0, target.Z - position.Z)
				if flat.Magnitude > FACE_TARGET_EPSILON then
					local forward = (target - position).Unit
					local result = CFrame.fromMatrix(position, forward, Vector3.yAxis:Cross(flat.Unit))
					lastFrameCF = result
					return result
				end
			end
		end
		if followCamera then
			local camera = Workspace.CurrentCamera
			if camera ~= nil then
				local cameraCF = camera.CFrame
				local result =
					CFrame.fromMatrix(position, cameraCF.RightVector, cameraCF.UpVector, -cameraCF.LookVector)
				lastFrameCF = result
				return result
			end
		end
		lastFrameCF = baseCF
		return baseCF
	end

	-- Clone one cube from the template. Returns nil when the template has no `Inner` body part, so `build` just
	-- skips it rather than spawning invisible junk.
	local function makeCube(): CubeState?
		local model = template:Clone()
		local inner = model:FindFirstChild("Inner")
		if inner == nil or not inner:IsA("BasePart") then
			model:Destroy()
			return nil
		end
		local innerPart: BasePart = inner
		setupCubePart(innerPart)
		if materialOverride ~= nil then
			innerPart.Material = materialOverride
		end

		local outerPart: BasePart? = nil
		local outer = model:FindFirstChild("Outer")
		if outer ~= nil and outer:IsA("BasePart") then
			if outline then
				setupCubePart(outer)
				if outlineColorOverride ~= nil then
					outer.Color = outlineColorOverride
				end
				outerPart = outer
			else
				outer:Destroy()
			end
		end

		-- Start the cube tiny and already at the word's frame, so its very first visible frame is a grow-in at
		-- the right place instead of a one-frame flash at the world origin.
		local startCF = lastFrameCF or resolveFrame() or CFrame.identity
		local seed = cubeSize * SPAWN_SCALE
		innerPart.Size = Vector3.new(seed * innerRatio, seed * innerRatio, seed * innerRatio)
		innerPart.CFrame = startCF
		if outerPart ~= nil then
			outerPart.Size = Vector3.new(seed, seed, seed)
			outerPart.CFrame = startCF
		end
		model.Parent = container

		return {
			Model = model,
			Inner = innerPart,
			Outer = outerPart,
			Letter = 0,
			GradientPos = 0,
			ToneShade = 0,
			LocalX = 0,
			LocalY = 0,
			LocalZ = 0,
			PosX = 0,
			PosY = 0,
			PosZ = 0,
			VelX = 0,
			VelY = 0,
			VelZ = 0,
			Scale = SPAWN_SCALE,
			ScaleVel = 0,
			ScaleTarget = 1,
			AppliedScale = -1,
			Retiring = false,
			SpawnSnap = false,
			SpawnOffset = Vector3.zero,
			RetireOffset = Vector3.zero,
			RevealAt = 0,
		}
	end

	-- Point an existing cube at a layout cell. `fresh` grows it in at its slot; an existing cube instead keeps
	-- its current world position and scale and springs over to the new slot, which is what morphs one word into
	-- the next instead of cutting between them.
	local function assign(state: CubeState, cell: Font.Cell, layout: Font.Layout, fresh: boolean)
		state.LocalX = cellSlotX(cell, cellStep * scaleMul, mirror)
		state.LocalY = cell.Y * cellStep * scaleMul
		state.LocalZ = 0
		state.Letter = cell.Letter
		state.GradientPos = gradientPosFor(cell.X, cell.Y, layout.Width, layout.Height)
		state.ToneShade = toneShadeFor(cell.X, cell.Y, layout.Width, layout.Height)
		state.ScaleTarget = 1
		state.Retiring = false
		state.SpawnOffset = Vector3.zero
		state.RetireOffset = Vector3.zero
		state.RevealAt = 0
		local inner = state.Inner
		if inner ~= nil and not animated then
			-- Animated colors are refreshed every frame in the step loop; static ones are written once, here.
			inner.Color = resolveColor(state.GradientPos, state.ToneShade, 0)
		end
		if fresh then
			state.SpawnSnap = true
			state.VelX, state.VelY, state.VelZ = 0, 0, 0
			state.Scale, state.ScaleVel = SPAWN_SCALE, 0
		end
	end

	-- Give a freshly spawned cube its per-style entrance: a fly-in offset, or a typewriter reveal delay.
	local function applyEntrance(state: CubeState, style: RebuildStyle, cell: Font.Cell, buildTime: number)
		if style == "Scatter" then
			state.SpawnOffset = randomUnit() * SCATTER_DISTANCE
		elseif style == "Rise" then
			state.SpawnOffset = Vector3.new(0, -RISE_DISTANCE, 0)
		elseif style == "Typewriter" then
			state.RevealAt = buildTime + (cell.Letter - 1) * TYPE_LETTER_DELAY
		end
	end

	local function build(newText: string, styleOverride: RebuildStyle?)
		local style: RebuildStyle = styleOverride or defaultStyle
		local reuse = style == "Relocate" or style == "Shuffle"
		local buildTime = elapsed
		local layout = Font.Layout(newText)
		local cells = layout.Cells

		-- The reusable pool is every cube currently on screen and not already retiring. The reuse styles glide
		-- those to the new slots ("Shuffle" re-pairs them scrambled first); the other styles retire every cube
		-- and spawn a fresh set.
		local pool: { CubeState } = {}
		if reuse then
			for _, state in cubes do
				if state.Model ~= nil and not state.Retiring then
					table.insert(pool, state)
				end
			end
			if style == "Shuffle" then
				for index = #pool, 2, -1 do
					local swap = math.random(index)
					pool[index], pool[swap] = pool[swap], pool[index]
				end
			end
		else
			for _, state in cubes do
				if state.Model ~= nil then
					state.Retiring = true
					state.ScaleTarget = 0
					state.RetireOffset = retireOffset(style)
				end
			end
		end

		for index, cell in cells do
			local reused = pool[index]
			if reused ~= nil then
				assign(reused, cell, layout, false)
			else
				local created = makeCube()
				if created ~= nil then
					assign(created, cell, layout, true)
					applyEntrance(created, style, cell, buildTime)
					table.insert(cubes, created)
				end
			end
		end

		-- Surplus reused cubes -- the word got shorter -- shrink out and get swept up by the step loop.
		for index = #cells + 1, #pool do
			pool[index].Retiring = true
			pool[index].ScaleTarget = 0
		end
	end

	local function destroy()
		if not alive then
			return
		end
		alive = false
		unregisterStepper(container)
		container:Destroy()
	end

	registerStepper(container, function(deltaTime: number)
		local frameCF = resolveFrame()
		if frameCF == nil then
			destroy()
			return
		end
		elapsed += deltaTime
		local frameRotation = frameCF.Rotation

		-- Resolved every frame, not cached, so installing or clearing the global check takes effect immediately.
		local reduceProvider: (() -> boolean)? = if reducedMotion ~= nil then reducedMotion else globalReducedMotion
		local reduce = reduceProvider ~= nil and reduceProvider() == true
		local floatOn = floatHeight > 0 and not reduce

		-- Unpack the frame ONCE per word per frame. Every cube's world target is then plain scalar math, which
		-- keeps the hot loop free of the per-cube Vector3 and CFrame temporaries that `frameCF * slot` would
		-- allocate -- with a few hundred cubes on screen that is the difference between churning the GC every
		-- frame and not touching it at all.
		local fx, fy, fz, r00, r01, r02, r10, r11, r12, r20, r21, r22 = frameCF:GetComponents()

		-- Sample the touch sources once per frame; skipped entirely under reduced motion.
		local pusherCount = 0
		if interaction and not reduce then
			local provided = if touchSources ~= nil then touchSources() else nil
			if provided ~= nil then
				for _, position in provided do
					pusherCount += 1
					pushers[pusherCount] = position
					if pusherCount >= MAX_PUSHERS then
						break
					end
				end
			else
				local player = Players.LocalPlayer
				local character = if player ~= nil then player.Character else nil
				if character ~= nil then
					for _, child in character:GetChildren() do
						if child:IsA("BasePart") then
							pusherCount += 1
							pushers[pusherCount] = child.Position
							if pusherCount >= MAX_PUSHERS then
								break
							end
						end
					end
				end
			end
		end

		-- Float bob and wobble tumble share their phase per LETTER, so both are memoized per letter per frame.
		-- The wobble memo folds the frame rotation in as well, which saves a CFrame multiply per cube.
		table.clear(letterFloatY)
		table.clear(letterRotation)

		local swept = false
		for _, state in cubes do
			local model = state.Model
			local inner = state.Inner
			if model == nil or inner == nil then
				continue
			end

			-- World target = the frame transform applied to this cube's local slot, plus the per-letter float,
			-- plus any style exit drift once the cube is retiring.
			local localY = state.LocalY
			if floatOn and not state.Retiring then
				local floatY = letterFloatY[state.Letter]
				if floatY == nil then
					floatY = math.sin(elapsed * floatSpeed + state.Letter * FLOAT_PHASE_STEP) * floatHeight
					letterFloatY[state.Letter] = floatY
				end
				localY += floatY
			end
			local localX, localZ = state.LocalX, state.LocalZ
			local targetX = fx + r00 * localX + r01 * localY + r02 * localZ
			local targetY = fy + r10 * localX + r11 * localY + r12 * localZ
			local targetZ = fz + r20 * localX + r21 * localY + r22 * localZ
			if state.Retiring then
				local drift = state.RetireOffset
				targetX += drift.X
				targetY += drift.Y
				targetZ += drift.Z
			end

			-- Touch push: shove the target away from every nearby source, and squash the cube on contact.
			local squash = 0
			if pusherCount > 0 and not state.Retiring then
				local posX, posY, posZ = state.PosX, state.PosY, state.PosZ
				local radiusSq = touchRadius * touchRadius
				for index = 1, pusherCount do
					local pusher = pushers[index]
					local dx, dy, dz = posX - pusher.X, posY - pusher.Y, posZ - pusher.Z
					local distanceSq = dx * dx + dy * dy + dz * dz
					if distanceSq < radiusSq and distanceSq > MIN_PUSH_DISTANCE_SQ then
						local distance = math.sqrt(distanceSq)
						local strength = 1 - distance / touchRadius
						-- Normalize and scale in one multiply: (delta / distance) * (strength * touchStrength).
						local push = strength * touchStrength / distance
						targetX += dx * push
						targetY += dy * push
						targetZ += dz * push
						squash = math.max(squash, strength)
					end
				end
			end

			if state.SpawnSnap then
				-- First frame for a fresh cube: teleport it onto (target + entrance offset) so it flies or grows
				-- in from THERE, rather than travelling in from wherever the state table happened to start.
				local spawn = state.SpawnOffset
				state.PosX, state.PosY, state.PosZ = targetX + spawn.X, targetY + spawn.Y, targetZ + spawn.Z
				state.VelX, state.VelY, state.VelZ = 0, 0, 0
				state.SpawnSnap = false
			end

			local revealed = state.RevealAt <= 0 or elapsed >= state.RevealAt
			local scaleTarget = if revealed then state.ScaleTarget else 0

			if reduce then
				-- Reduced motion: hold the rest pose exactly. The word is still there and still readable, it
				-- just does not glide, bob, squash or transition.
				state.PosX, state.PosY, state.PosZ = targetX, targetY, targetZ
				state.VelX, state.VelY, state.VelZ = 0, 0, 0
				state.Scale, state.ScaleVel = state.ScaleTarget, 0
			else
				state.PosX, state.VelX =
					Spring.Step(state.PosX, state.VelX, targetX, deltaTime, moveFrequency, moveDamping)
				state.PosY, state.VelY =
					Spring.Step(state.PosY, state.VelY, targetY, deltaTime, moveFrequency, moveDamping)
				state.PosZ, state.VelZ =
					Spring.Step(state.PosZ, state.VelZ, targetZ, deltaTime, moveFrequency, moveDamping)
				local scaleGoal = scaleTarget * (1 - squash * SQUASH_FACTOR)
				state.Scale, state.ScaleVel = Spring.Step(
					state.Scale,
					state.ScaleVel,
					scaleGoal,
					deltaTime,
					DEFAULT_SCALE_FREQUENCY,
					DEFAULT_SCALE_DAMPING
				)
			end

			local scale = math.max(state.Scale, 0)

			-- Retire check BEFORE the CFrame batch: a cube destroyed this frame must never make it into the bulk
			-- arrays, because BulkMoveTo runs after every stepper -- by then the part would already be gone.
			if state.Retiring and scale < RETIRE_SCALE then
				model:Destroy()
				state.Model = nil
				state.Inner = nil
				state.Outer = nil
				swept = true
				continue
			end

			local rotation = frameRotation
			if wobble > 0 and not reduce then
				-- Gentle per-letter idle tumble: every cube of a letter shares the phase, so the letter tilts as
				-- ONE unit -- its faces catch the light and shimmer -- instead of each cube shaking on its own.
				local letter = state.Letter
				local cached = letterRotation[letter]
				if cached ~= nil then
					rotation = cached
				else
					local tumbled = frameRotation
						* CFrame.Angles(
							math.sin(elapsed * wobbleSpeed * WOBBLE_FREQ_X + letter * LETTER_SPIN_X) * wobble,
							math.sin(elapsed * wobbleSpeed * WOBBLE_FREQ_Y + letter * LETTER_SPIN_Y) * wobble,
							math.sin(elapsed * wobbleSpeed * WOBBLE_FREQ_Z + letter * LETTER_SPIN_Z) * wobble
						)
					letterRotation[letter] = tumbled
					rotation = tumbled
				end
			end
			-- `rotation` carries no translation, so adding the position vector places it directly -- one CFrame
			-- built, instead of constructing a positional CFrame and multiplying the two together.
			local cframe = rotation + Vector3.new(state.PosX, state.PosY, state.PosZ)
			local bulkIndex = #bulkParts + 1
			bulkParts[bulkIndex] = inner
			bulkCFrames[bulkIndex] = cframe
			local outer = state.Outer
			if outer ~= nil then
				bulkParts[bulkIndex + 1] = outer
				bulkCFrames[bulkIndex + 1] = cframe
			end

			if animated then
				-- Rainbow or scrolling gradient: refresh the body color each frame (frozen under reduced motion).
				inner.Color = resolveColor(state.GradientPos, state.ToneShade, if reduce then 0 else elapsed)
			end

			if math.abs(scale - state.AppliedScale) > SIZE_EPSILON then
				state.AppliedScale = scale
				local outerEdge = cubeSize * scaleMul * scale
				local innerEdge = outerEdge * innerRatio
				inner.Size = Vector3.new(innerEdge, innerEdge, innerEdge)
				if outer ~= nil then
					outer.Size = Vector3.new(outerEdge, outerEdge, outerEdge)
				end
			end
		end

		-- Compact the cube list in place, only on the frames where something was actually destroyed.
		if swept then
			local kept = 0
			for _, state in cubes do
				if state.Model ~= nil then
					kept += 1
					cubes[kept] = state
				end
			end
			for index = #cubes, kept + 1, -1 do
				cubes[index] = nil
			end
		end
	end)

	build(text, nil)

	if opts.Lifetime ~= nil then
		task.delay(opts.Lifetime, destroy)
	end

	local handle: Handle = {
		Container = container,
		SetText = function(_self: Handle, newText: string, style: RebuildStyle?)
			if alive then
				build(newText, style)
			end
		end,
		SetAnchor = function(_self: Handle, newAnchor: Anchor)
			if alive then
				currentAnchor = newAnchor
			end
		end,
		SetFaceTarget = function(_self: Handle, provider: FaceTargetProvider?)
			if alive then
				faceTargetProvider = provider
			end
		end,
		SetScale = function(_self: Handle, multiplier: number)
			if alive then
				scaleMul = math.max(multiplier, 0)
			end
		end,
		SetPlayerInteraction = function(_self: Handle, enabled: boolean)
			if alive then
				interaction = enabled
			end
		end,
		Destroy = function(_self: Handle)
			destroy()
		end,
	}
	return handle
end

--------------------------------------------------------------------------------------------------------------
-- Presets
--------------------------------------------------------------------------------------------------------------

-- Ready-made option bundles. Pass one straight to `Create` via `{ Preset = "Hologram" }`, or build a tweaked
-- copy with `BlockText.Preset(name, { ... })`.
local PRESETS: { [string]: Options } = {
	-- Cyan/blue sci-fi label that always faces the camera; the neon glow carries it, so no outline.
	Hologram = {
		FollowCamera = true,
		Outline = false,
		ToneVariation = 0.1,
		FloatHeight = 0.3,
		MoveFrequency = 6,
		Gradient = { Color3.fromRGB(90, 220, 255), Color3.fromRGB(120, 140, 255) },
	},
	-- Punchy magenta -> cyan that types itself in and reacts to the player walking through it.
	Arcade = {
		PlayerInteraction = true,
		ToneVariation = 0.16,
		RebuildStyle = "Typewriter",
		Gradient = { Color3.fromRGB(255, 70, 200), Color3.fromRGB(80, 220, 255) },
	},
	-- Solid, outlined cartoon text. Pair it with a template that has an `Outer` shell.
	Toon = {
		Color = Color3.fromRGB(255, 210, 70),
		Outline = true,
		ToneVariation = 0.12,
		RebuildStyle = "Relocate",
	},
	-- Soft, pale, slowly drifting text with a heavy float and no outline.
	Ghost = {
		Color = Color3.fromRGB(210, 225, 255),
		Outline = false,
		ToneVariation = 0.08,
		FloatHeight = 0.5,
		FloatSpeed = 1.6,
		MoveFrequency = 4,
		MoveDamping = 0.9,
	},
	-- Continuous rainbow scrolling across the text, camera-facing.
	Rainbow = {
		Rainbow = true,
		GradientSpeed = 0.15,
		RainbowSpan = 1,
		FollowCamera = true,
		ToneVariation = 0.08,
	},
	-- Multi-color with a high tonal spread; the cubes explode and reassemble on every change.
	Confetti = {
		PlayerInteraction = true,
		ToneVariation = 0.2,
		RebuildStyle = "Scatter",
		Gradient = {
			Color3.fromRGB(255, 90, 90),
			Color3.fromRGB(255, 215, 80),
			Color3.fromRGB(90, 220, 140),
			Color3.fromRGB(90, 160, 255),
		},
	},
}

BlockText.Presets = PRESETS

-- A shallow copy of a named preset with optional overrides applied on top. An unknown name yields just the
-- overrides. Equivalent to passing `{ Preset = name, ... }` straight to `Create`.
function BlockText.Preset(name: string, overrides: Options?): Options
	return mergeOptions(PRESETS[name], overrides)
end

return BlockText
