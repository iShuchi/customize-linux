-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "decay",

	-- Make the tree's indent guides and selected line visible
	hl_override = {
		NvimTreeIndentMarker = { fg = { "line", 8 } },
		NvimTreeCursorLine = { bg = "black2" },
	},

	hl_add = {
		VirtColumn = { fg = "grey" }, -- VS Code #80808075 -> espresso #424242
		MarkdownRuler = { fg = "#ff9900" }, -- "[markdown]".editor.rulers[0].color
	},
}

M.ui = {
	tabufline = {
		-- NvChad truncates each tab label to (bufwidth - 7) characters, so the
		-- default 21 cuts names at 14 -- "simulation.lau..". 32 shows 25, which
		-- covers normal source filenames. Wider tabs means fewer fit on screen
		-- before NvChad starts hiding them, so this is the trade-off dial.
		bufwidth = 32,
	},
}

-- M.nvdash = { load_on_startup = true }

return M
