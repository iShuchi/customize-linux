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
		-- Colour names below come from the selected theme's palette
		VirtColumn = { fg = "grey" },
		MarkdownRuler = { fg = "orange" },

		-- Git graph, instead of the plugin's own dull gruvbox colours
		GitGraphHash = { fg = "purple" },
		GitGraphTimestamp = { fg = "green" },
		GitGraphAuthor = { fg = "blue" },
		GitGraphBranchName = { fg = "orange" },
		GitGraphBranchTag = { fg = "sun" },
		GitGraphBranchMsg = { fg = "white" },
		GitGraphBranch1 = { fg = "blue" },
		GitGraphBranch2 = { fg = "purple" },
		GitGraphBranch3 = { fg = "sun" },
		GitGraphBranch4 = { fg = "green" },
		GitGraphBranch5 = { fg = "orange" },
	},
}

M.ui = {
	tabufline = {
		bufwidth = 32,
	},
}

-- Keep <leader>ch to our own keys: hide Neovim's and nvim-tree's built-in ones
M.cheatsheet = {
	excluded_groups = { ":help", "Add", "Jump", "Opens", "Select", "Show", "Toggle", "nvim-tree:", "vim.snippet.jump" },
}

-- M.nvdash = { load_on_startup = true }

return M
