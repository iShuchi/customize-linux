-- nvim-tree appearance.
-- This only *overrides* NvChad's defaults (nvchad/configs/nvimtree.lua).

return {
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeOpen" },
    opts = {
      view = {
        width = 38,
        signcolumn = "no",
      },

      renderer = {
        indent_width = 2,
        group_empty = false,
        highlight_git = "all",

        special_files = {
          "README.md",
          "readme.md",
          "Makefile",
          "CMakeLists.txt",
          "package.xml",
          "Cargo.toml",
          "pyproject.toml",
          "package.json",
        },

        indent_markers = {
          enable = true,   -- false moves the expander arrow into its own column
          inline_arrows = false,
          icons = { corner = "└", edge = "│", item = "│", bottom = "─", none = " " },
        },

        icons = {
          git_placement = "after",
          modified_placement = "after",
          symlink_arrow = " ➜ ",
          padding = { icon = " ", folder_arrow = " " },
          show = { file = true, folder = true, folder_arrow = true, git = true, diagnostics = false },
          glyphs = {
            git = {
              unstaged = "", -- U+F448
              staged = "", -- U+F00C
              unmerged = "", -- U+EB29
              renamed = "", -- U+F45A
              untracked = "", -- U+F067
              deleted = "", -- U+F474
              ignored = "◌", -- U+25CC
            },
          },
        },
      },

      diagnostics = { enable = false },
      hijack_directories = { enable = false },

      git = { enable = true, timeout = 500 },

      filters = {
        dotfiles = true,
        git_ignored = true,
        custom = { "^\\.git$" },
      },

      actions = {
        file_popup = { open_win_config = { border = "rounded" } },
      },
    },
  },
}
