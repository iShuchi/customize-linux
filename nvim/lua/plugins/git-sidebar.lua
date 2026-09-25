-- Left sidebar includes NVIM logo, file tree and commit graph

local sidebar = require "configs.sidebar"

return {
  { "tpope/vim-fugitive", cmd = { "Git", "G" } },

  {
    "isakbm/gitgraph.nvim",
    opts = {
      symbols = { merge_commit = "M", commit = "*" },
      format = {
        timestamp = "%d-%m-%Y",
        fields = { "hash", "timestamp", "author", "branch_name", "tag" },
      },
    },
  },

  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    init = function()
      -- edgy needs a global statusline and splits that keep their screen
      -- position when the layout changes.
      vim.opt.laststatus = 3
      vim.opt.splitkeep = "screen"
      sidebar.track_drags()
      sidebar.track_logo()
      sidebar.autostart()
      sidebar.track_graph_top()
      sidebar.track_graph_keys()
    end,
    keys = {
      { "<leader>gs", "<cmd>Git<cr>", desc = "git status (fugitive)" },
      { "<leader>gl", function() sidebar.graph(true) end, desc = "git graph panel" },
      { "<leader>ge", sidebar.toggle, desc = "toggle left sidebar" },
    },
    opts = {
      animate = { enabled = false },
      wo = { signcolumn = "no" },
      options = { left = { size = sidebar.width } },
      left = {
        {
          ft = sidebar.LOGO_FT,
          title = "",
          size = { height = #sidebar.LOGO + 2 }, -- two blank lines under the logo
          pinned = true,
          open = sidebar.open_logo,
          wo = { winbar = "", cursorline = false, number = false, relativenumber = false },
        },
        {
          ft = "NvimTree",
          title = "Explorer",
          pinned = true,
          open = "NvimTreeOpen",
        },
        {
          ft = "gitgraph",
          title = "Git Graph",
          size = { height = 0.42 },
          -- graph lines reach ~120 cols; keep them on one line and scroll
          -- sideways (<S-Left>/<S-Right>) rather than wrapping them.
          wo = { wrap = false },
          pinned = true,
          open = function() sidebar.graph(false) end,
        },
      },
    },
  },
}
