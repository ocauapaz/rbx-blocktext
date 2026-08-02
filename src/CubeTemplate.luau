--!strict

-- The default cube a `BlockText` letter is built from, when the caller does not supply their own `Template`.
--
-- A template is a Model with a BasePart named `Inner` (the colored body -- BlockText tints this per cube) and
-- an OPTIONAL BasePart named `Outer` (an outline shell drawn around the body). The built-in template ships only
-- `Inner`, because a solid outline shell cannot be built from a plain Part: an opaque box around the body would
-- simply hide it. A real outline needs an INVERTED-HULL mesh -- a cube MeshPart with its normals flipped, so the
-- camera sees its far faces and the body shows through -- which is authored art, not something a library can
-- conjure at runtime.
--
-- To get outlined letters, author that Model once in Studio and pass it as `Template`:
--
--   Cube (Model)
--    |- Inner (Part,     Material = Neon)          -- tinted per cube
--    |- Outer (MeshPart, inverted-hull cube, black) -- the outline
--
-- BlockText reads the Inner/Outer size ratio straight off the template, so the outline keeps exactly the
-- thickness it was authored with at every cube size.

local CubeTemplate = {}

-- One shared, never-parented Model that every default cube is cloned from. Built on first use so merely
-- requiring this module creates nothing.
local cached: Model? = nil

-- Edge length of the template body. Arbitrary -- BlockText rescales every cube it clones -- but 1 stud keeps
-- the numbers readable if someone inspects the template in the explorer.
local TEMPLATE_SIZE = 1

-- Builds the default template: a single neon cube named `Inner`, with everything the renderer would otherwise
-- have to strip already turned off (no collision, no queries, no shadows).
local function build(): Model
	local model = Instance.new("Model")
	model.Name = "BlockTextCube"

	local inner = Instance.new("Part")
	inner.Name = "Inner"
	inner.Shape = Enum.PartType.Block
	inner.Material = Enum.Material.Neon
	inner.Color = Color3.new(1, 1, 1)
	inner.Size = Vector3.new(TEMPLATE_SIZE, TEMPLATE_SIZE, TEMPLATE_SIZE)
	inner.Anchored = true
	inner.CanCollide = false
	inner.CanQuery = false
	inner.CanTouch = false
	inner.CastShadow = false
	inner.Massless = true
	inner.TopSurface = Enum.SurfaceType.Smooth
	inner.BottomSurface = Enum.SurfaceType.Smooth
	inner.Parent = model
	model.PrimaryPart = inner

	return model
end

-- The shared default template. Callers must NOT mutate or destroy it -- BlockText only ever clones it.
function CubeTemplate.Get(): Model
	local existing = cached
	if existing ~= nil then
		return existing
	end
	local created = build()
	cached = created
	return created
end

return CubeTemplate
