--!strict

-- Font is pure Luau -- no Roblox instances -- so its glyph metrics and string -> cell layout run in any plain
-- Luau runtime. BlockText itself spawns and animates real parts, so it is validated in Studio instead.
--
--   lune run tests/font

local Font = require("../src/Font")

local failures = 0

local function test(name: string, callback: () -> ())
	local ok, err = pcall(callback :: () -> any)
	if ok then
		print(`PASS {name}`)
	else
		failures += 1
		print(`FAIL {name}: {tostring(err)}`)
	end
end

local function assertEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(message or `expected {tostring(expected)}, got {tostring(actual)}`, 2)
	end
end

-- Cells carry centered X/Y (X right, Y up), both 0 at the block's middle.
local function hasCell(layout: Font.Layout, x: number, y: number): boolean
	for _, cell in layout.Cells do
		if cell.X == x and cell.Y == y then
			return true
		end
	end
	return false
end

test("glyph widths: digits and letters are 5, narrow punctuation is 1, space and unknowns are 1", function()
	assertEqual(Font.Width("0"), 5)
	assertEqual(Font.Width("A"), 5)
	assertEqual(Font.Width("Q"), 5)
	assertEqual(Font.Width("#"), 5, "hash is a real glyph, not a blank")
	assertEqual(Font.Width(":"), 1)
	assertEqual(Font.Width("."), 1)
	assertEqual(Font.Width(" "), 1)
	assertEqual(Font.Width("~"), 1, "unknown character falls back to a blank space")
end)

test("Rows returns the bitmap for known glyphs and nil for unknowns; lowercase folds to uppercase", function()
	local zero = Font.Rows("0")
	assertEqual(zero ~= nil, true)
	assertEqual((zero :: { string })[1], " ### ")
	assertEqual(Font.Rows("~"), nil)
	assertEqual(Font.Width("a"), Font.Width("A"), "lowercase width matches uppercase")
end)

test("Layout of a single glyph reports its cell count, width and height, centered on the origin", function()
	local layout = Font.Layout("8")
	assertEqual(layout.Height, 5)
	assertEqual(layout.Width, 5)
	-- "8" =  ###  / #   # /  ###  / #   # /  ###  = 13 filled cells.
	assertEqual(#layout.Cells, 13)
	-- The top row (Y = +2) is filled across the inner columns X = -1, 0, 1; the 5-wide corners are empty.
	assertEqual(hasCell(layout, -1, 2), true)
	assertEqual(hasCell(layout, 0, 2), true)
	assertEqual(hasCell(layout, 1, 2), true)
	-- The second row from the top (Y = +1) has a hollow middle.
	assertEqual(hasCell(layout, 0, 1), false)
end)

test("Layout advances the cursor with a one-column gap between glyphs", function()
	-- "1" (width 5) + gap + ":" (width 1) => width 7, 10 cells.
	local layout = Font.Layout("1:")
	assertEqual(layout.Width, 7)
	assertEqual(#layout.Cells, 10)
	-- The colon sits at the far column: raw column 6, centered X = 6 - (7-1)/2 = 3; its dots are rows 1 and 3.
	assertEqual(hasCell(layout, 3, 1), true)
	assertEqual(hasCell(layout, 3, -1), true)
end)

test("Layout of empty text is empty, and unknown text lays out as blank width", function()
	local empty = Font.Layout("")
	assertEqual(empty.Width, 0)
	assertEqual(#empty.Cells, 0)

	local unknown = Font.Layout("~")
	assertEqual(#unknown.Cells, 0)
	assertEqual(unknown.Width, 1, "a lone unknown char is a 1-wide blank with the trailing gap trimmed")
end)

test("lowercase input renders the same cells as uppercase", function()
	assertEqual(#Font.Layout("abc").Cells, #Font.Layout("ABC").Cells)
end)

test("cells carry the 1-based source-character index, so letters can be grouped and floated apart", function()
	local layout = Font.Layout("1:")
	-- "1" is character 1 (its cells sit left of center), ":" is character 2 (right of center).
	for _, cell in layout.Cells do
		if cell.X <= 0 then
			assertEqual(cell.Letter, 1, "the '1' cells belong to letter 1")
		else
			assertEqual(cell.Letter, 2, "the ':' cells belong to letter 2")
		end
	end
end)

test("newline stacks a second centered line below the first", function()
	local layout = Font.Layout("A\nB")
	-- Two 5-row lines with a 1-row gap => 11 rows total; the widest line is 5 wide.
	assertEqual(layout.Height, 11)
	assertEqual(layout.Width, 5)
	assertEqual(#layout.Cells, 30, "'A' (14 cells) + 'B' (16 cells)")
	-- 'A' occupies the top (its top cell at Y = +5); 'B' the bottom (its bottom row at Y = -5).
	assertEqual(hasCell(layout, 0, 5), true)
	assertEqual(hasCell(layout, 0, -5), true)
	-- 'A' is character 1 and 'B' is character 3, because the newline itself counts as character 2.
	for _, cell in layout.Cells do
		if cell.Y > 0 then
			assertEqual(cell.Letter, 1, "top line cells belong to 'A' (letter 1)")
		else
			assertEqual(cell.Letter, 3, "bottom line cells belong to 'B' (letter 3)")
		end
	end
end)

test("the arrow glyph is multibyte and decodes as a single 7-wide character", function()
	assertEqual(Font.Width(Font.ARROW), 7)
	local layout = Font.Layout(Font.ARROW)
	assertEqual(layout.Width, 7)
	for _, cell in layout.Cells do
		assertEqual(cell.Letter, 1, "the whole arrow is one source character, not one per byte")
	end
end)

test("SetGlyph registers a custom character, and rejects a mis-sized bitmap", function()
	Font.SetGlyph("~", { "###", "#  ", "###", "  #", "###" })
	assertEqual(Font.Width("~"), 3)
	assertEqual(#Font.Layout("~").Cells, 11)

	assertEqual(pcall(Font.SetGlyph, "@", { "#", "#" }), false, "wrong row count is rejected")
	assertEqual(pcall(Font.SetGlyph, "@", { "##", "#", "#", "#", "#" }), false, "ragged rows are rejected")
end)

if failures > 0 then
	error(`{failures} test(s) failed`, 0)
end
print("all tests passed")
return true
