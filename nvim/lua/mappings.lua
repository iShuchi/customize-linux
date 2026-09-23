-- Replaces the NvChad starter's lua/mappings.lua outright

require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

local function format_and_lint()
  require("conform").format({ lsp_format = "fallback", timeout_ms = 2000 }, function(err)
    -- "no formatters" is the normal case for filetypes we only lint, not an error.
    if err and not err:match "No formatters available" then
      vim.notify(err, vim.log.levels.WARN)
    end
    require("configs.lint").lint()
  end)
end

map({ "n", "i", "v" }, "<C-S-i>", format_and_lint, { desc = "format + lint buffer" })
map("n", "<leader>l", format_and_lint, { desc = "format + lint buffer" })

-- VS Code style bindings.

local sidebar = require "configs.sidebar"

for _, lhs in ipairs { "<C-n>", "<leader>ff", "<leader>fw", "<leader>fz" } do
  pcall(vim.keymap.del, "n", lhs)
end

-- files and search
map("n", "<leader>p", "<cmd>Telescope find_files<cr>", { desc = "go to file" })
map("n", "<leader>F", "<cmd>Telescope live_grep<cr>", { desc = "find in all files" })
map("n", "<leader>f", "<cmd>Telescope current_buffer_fuzzy_find<cr>", { desc = "find in this file" })

-- sidebar
map("n", "<leader>b", function()
  sidebar.toggle()
end, { desc = "toggle left panel" })

-- new file / new panes, always in the editor area
map("n", "<leader>n", function()
  require("configs.newfile").open()
end, { desc = "new file in the tree's selected directory" })

map("n", "<leader>V", function()
  sidebar.main_do "vsplit"
end, { desc = "new pane (vertical)" })

map("n", "<leader>H", function()
  sidebar.main_do "split"
end, { desc = "new pane (horizontal)" })
