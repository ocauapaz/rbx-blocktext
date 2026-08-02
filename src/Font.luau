--!strict

-- Pixel-grid font for BlockText.
--
-- Each glyph is a 5-row bitmap of '#' (a filled cube) and ' ' (empty), authored uppercase-only. Letters and
-- digits are 5 columns wide for clean, legible letterforms; punctuation stays narrow. This module is pure data
-- plus layout math with NO Roblox instances, so the glyph table and the string -> cell layout are unit-testable
-- outside Studio (Lune, or any plain Luau runtime); `BlockText` is what turns the returned cells into real
-- animated cubes. Characters with no glyph render as a blank space.
--
--   local layout = Font.Layout("HELLO\nWORLD")
--   -- layout.Width = 29, layout.Height = 11 (two 5-row lines and the gap between them)
--   -- layout.Cells = { { X = -14, Y = 5, Letter = 1 }, ... } -- 118 filled cells

local Font = {}

-- Rows run top (index 1) to bottom (index `Font.Height`). A laid-out cell carries its position in CELL UNITS
-- relative to the CENTER of the whole block (X grows right, Y grows up), so a renderer just multiplies by a
-- stud step -- all centering (per line horizontally, and the stack of lines vertically) is already done here.
-- `Letter` is the 1-based index of the source character the cell belongs to, so cells can be grouped per
-- letter (e.g. to float each letter of a word on its own phase).
export type Cell = { X: number, Y: number, Letter: number }
export type Layout = { Cells: { Cell }, Width: number, Height: number }

-- Row count every glyph must have. Fixed, because the renderer assumes a uniform baseline.
Font.Height = 5

-- Blank cell columns a space advances, the gap between adjacent glyphs, and the blank rows between text lines.
local SPACE_WIDTH = 1
local GLYPH_GAP = 1
local LINE_GAP = 1

local GLYPHS: { [string]: { string } } = {
	["0"] = { " ### ", "#  ##", "# # #", "##  #", " ### " },
	["1"] = { "  #  ", " ##  ", "  #  ", "  #  ", " ### " },
	["2"] = { " ### ", "#   #", "  ## ", " #   ", "#####" },
	["3"] = { "#### ", "    #", " ### ", "    #", "#### " },
	["4"] = { "#  # ", "#  # ", "#####", "   # ", "   # " },
	["5"] = { "#####", "#    ", "#### ", "    #", "#### " },
	["6"] = { " ### ", "#    ", "#### ", "#   #", " ### " },
	["7"] = { "#####", "    #", "   # ", "  #  ", " #   " },
	["8"] = { " ### ", "#   #", " ### ", "#   #", " ### " },
	["9"] = { " ### ", "#   #", " ####", "    #", " ### " },

	["A"] = { " ### ", "#   #", "#####", "#   #", "#   #" },
	["B"] = { "#### ", "#   #", "#### ", "#   #", "#### " },
	["C"] = { " ### ", "#   #", "#    ", "#   #", " ### " },
	["D"] = { "###  ", "#  # ", "#   #", "#  # ", "###  " },
	["E"] = { "#####", "#    ", "###  ", "#    ", "#####" },
	["F"] = { "#####", "#    ", "###  ", "#    ", "#    " },
	["G"] = { " ### ", "#    ", "#  ##", "#   #", " ### " },
	["H"] = { "#   #", "#   #", "#####", "#   #", "#   #" },
	["I"] = { " ### ", "  #  ", "  #  ", "  #  ", " ### " },
	["J"] = { "  ###", "   # ", "   # ", "#  # ", " ##  " },
	["K"] = { "#  # ", "# #  ", "##   ", "# #  ", "#  # " },
	["L"] = { "#    ", "#    ", "#    ", "#    ", "#####" },
	["M"] = { "#   #", "## ##", "# # #", "#   #", "#   #" },
	["N"] = { "#   #", "##  #", "# # #", "#  ##", "#   #" },
	["O"] = { " ### ", "#   #", "#   #", "#   #", " ### " },
	["P"] = { "#### ", "#   #", "#### ", "#    ", "#    " },
	["Q"] = { " ### ", "#   #", "#   #", "#  # ", " ## #" },
	["R"] = { "#### ", "#   #", "#### ", "# #  ", "#  # " },
	["S"] = { " ####", "#    ", " ### ", "    #", "#### " },
	["T"] = { "#####", "  #  ", "  #  ", "  #  ", "  #  " },
	["U"] = { "#   #", "#   #", "#   #", "#   #", " ### " },
	["V"] = { "#   #", "#   #", "#   #", " # # ", "  #  " },
	["W"] = { "#   #", "#   #", "# # #", "## ##", "#   #" },
	["X"] = { "#   #", " # # ", "  #  ", " # # ", "#   #" },
	["Y"] = { "#   #", " # # ", "  #  ", "  #  ", "  #  " },
	["Z"] = { "#####", "   # ", "  #  ", " #   ", "#####" },

	[":"] = { " ", "#", " ", "#", " " },
	["."] = { " ", " ", " ", " ", "#" },
	[","] = { " ", " ", " ", "#", "#" },
	["'"] = { "#", "#", " ", " ", " " },
	["!"] = { "#", "#", "#", " ", "#" },
	["-"] = { "     ", "     ", " ### ", "     ", "     " },
	["+"] = { "     ", "  #  ", " ### ", "  #  ", "     " },
	["="] = { "     ", " ### ", "     ", " ### ", "     " },
	["*"] = { "# # #", " ### ", "#####", " ### ", "# # #" },
	["%"] = { "#   #", "   # ", "  #  ", " #   ", "#   #" },
	["("] = { "  #", " # ", " # ", " # ", "  #" },
	[")"] = { "#  ", " # ", " # ", " # ", "#  " },
	["/"] = { "    #", "   # ", "  #  ", " #   ", "#    " },
	["\\"] = { "#    ", " #   ", "  #  ", "   # ", "    #" },
	["?"] = { " ### ", "#   #", "  ## ", "     ", "  #  " },
	["#"] = { " # # ", "#####", " # # ", "#####", " # # " },
	["$"] = { " ####", "##   ", " ### ", "   ##", "#### " },

	-- Right-pointing arrow (7 wide): a full-width shaft with a chevron head at the +X end, so the glyph points
	-- along the layout frame's local +X. Combine it with `BlockText`'s `FaceTarget` option to yaw that +X at a
	-- world position and you get a waypoint arrow that always points at its destination.
	["\u{2192}"] = { "    #  ", "     # ", "#######", "     # ", "    #  " },
}

-- The arrow glyph's key, exported so callers can render it without embedding a multibyte literal in their code.
Font.ARROW = "\u{2192}"

-- Bitmap rows for a character (which must already be upper-cased), or nil when it has no glyph.
function Font.Rows(char: string): { string }?
	return GLYPHS[char]
end

-- Register or replace a glyph. `rows` must have exactly `Font.Height` rows of equal length, made of '#' (filled)
-- and any other character (empty) -- the renderer assumes a uniform baseline, so a short glyph would float.
-- Keys are matched after upper-casing, and may be multibyte (UTF-8) for symbols outside ASCII.
function Font.SetGlyph(char: string, rows: { string })
	assert(#rows == Font.Height, `glyph "{char}" must have exactly {Font.Height} rows, got {#rows}`)
	local width = #rows[1]
	for index, row in rows do
		assert(#row == width, `glyph "{char}" row {index} is {#row} wide, expected {width}`)
	end
	GLYPHS[string.upper(char)] = rows
end

-- Column count a character occupies. Spaces -- and unknown characters, which render blank -- use SPACE_WIDTH.
function Font.Width(char: string): number
	local rows = GLYPHS[string.upper(char)]
	if rows == nil then
		return SPACE_WIDTH
	end
	return #rows[1]
end

-- A single glyph cell before centering: its column (0-based from the line's left edge), row (0 = top), and the
-- index of the source character it came from.
type RawCell = { Column: number, Row: number, Letter: number }

-- Decode one UTF-8 character starting at byte `index`: returns the whole character substring (so a multibyte
-- glyph key like the arrow matches) and the next byte index. Pure ASCII decodes one byte at a time, so this is
-- behaviourally identical to a plain byte walk for ASCII text.
local function decodeChar(text: string, index: number): (string, number)
	local first = string.byte(text, index) or 0
	local size = 1
	if first >= 0xF0 then
		size = 4
	elseif first >= 0xE0 then
		size = 3
	elseif first >= 0xC0 then
		size = 2
	end
	return string.sub(text, index, index + size - 1), index + size
end

-- Lay a string out into filled cells centered on the block's origin. "\n" starts a new line; each line is
-- centered horizontally on its own width, and the lines are stacked and centered vertically. `Width` is the
-- widest line's column span, `Height` the total row span across all lines. Lowercase folds to uppercase; any
-- character without a glyph becomes a blank gap.
function Font.Layout(text: string): Layout
	local height = Font.Height
	local lines: { { cells: { RawCell }, width: number } } = {}
	local current: { RawCell } = {}
	local cursor = 0
	local maxWidth = 0

	local function flushLine()
		-- The cursor always carries a trailing GLYPH_GAP from the last glyph; the line does not.
		local width = math.max(cursor - GLYPH_GAP, 0)
		maxWidth = math.max(maxWidth, width)
		table.insert(lines, { cells = current, width = width })
		current = {}
		cursor = 0
	end

	local index = 1
	local letter = 0
	while index <= #text do
		local char, nextIndex = decodeChar(text, index)
		letter += 1
		if char == "\n" then
			flushLine()
		else
			local rows = GLYPHS[string.upper(char)]
			if rows ~= nil then
				for rowIndex, rowString in rows do
					for column = 1, #rowString do
						if string.sub(rowString, column, column) == "#" then
							table.insert(
								current,
								{ Column = cursor + (column - 1), Row = rowIndex - 1, Letter = letter }
							)
						end
					end
				end
				cursor += #rows[1]
			else
				cursor += SPACE_WIDTH
			end
			cursor += GLYPH_GAP
		end
		index = nextIndex
	end
	flushLine()

	local totalRows = #lines * height + (#lines - 1) * LINE_GAP
	local centerY = (totalRows - 1) / 2

	local cells: { Cell } = {}
	for lineIndex, line in lines do
		local lineCenterX = (line.width - 1) / 2
		local lineTopRow = (lineIndex - 1) * (height + LINE_GAP)
		for _, raw in line.cells do
			table.insert(cells, {
				X = raw.Column - lineCenterX,
				Y = centerY - (lineTopRow + raw.Row),
				Letter = raw.Letter,
			})
		end
	end

	return { Cells = cells, Width = maxWidth, Height = totalRows }
end

return Font
