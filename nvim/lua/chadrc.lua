-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua
-- Please read that file to know all available options :(

---@type ChadrcConfig
local M = {}

M.base46 = {
	theme = "espresso",

	-- hl_override = {
	-- 	Comment = { italic = true },
	-- 	["@comment"] = { italic = true },
	-- },

	-- nvim-tree keeps base46's own espresso colours: blue folders, per-filetype
	-- devicons, yellow special files. The two overrides below are NOT colour
	-- changes -- they fix things that are effectively invisible on this theme.
	hl_override = {
		NvimTreeIndentMarker = { fg = { "line", 8 } },

		NvimTreeCursorLine = { bg = "black2" },
	},

	hl_add = {
		-- NVIM block banner, one group per letter. All four are espresso's own
		-- base_30 names, so the banner re-colours itself if the theme changes.
		-- Ordered green -> blue -> purple, echoing Neovim's own logo gradient.
		NvimLogo1 = { fg = "green" }, -- N  #7dc5a2
		NvimLogo2 = { fg = "teal" }, -- V  #51decf
		NvimLogo3 = { fg = "blue" }, -- I  #76bef9
		NvimLogo4 = { fg = "purple" }, -- M  #c993ef
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
