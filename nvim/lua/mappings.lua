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
map("n", "<leader>I", format_and_lint, { desc = "format + lint buffer" })

-- VS Code style bindings.

local sidebar = require "configs.sidebar"

-- NvChad defaults that are rebound below, or that share the <leader>f prefix
-- and would make <leader>f wait for a second key.
for _, lhs in ipairs {
  "<C-n>", "<leader>ff", "<leader>fw", "<leader>fz", "<leader>fm",
  "<leader>fb", "<leader>fh", "<leader>fo", "<leader>fa", "<leader>h", "<leader>v",
  "<leader>wK", "<leader>wk", -- which-key is disabled
} do
  pcall(vim.keymap.del, "n", lhs)
end
pcall(vim.keymap.del, "x", "<leader>fm")

local function fzf(picker, opts)
  return function()
    sidebar.main_do(function()
      require("fzf-lua")[picker](opts)
    end)
  end
end

local function find_plugins()
  local dirs = {}
  for _, p in ipairs(require("lazy").plugins()) do
    dirs[p.name] = p.dir
  end
  local names = vim.tbl_keys(dirs)
  table.sort(names)
  require("fzf-lua").fzf_exec(names, {
    prompt = "Plugins> ",
    actions = {
      -- <cr> fuzzy-finds files inside the chosen plugin
      default = function(sel)
        require("fzf-lua").files { cwd = dirs[sel[1]] }
      end,
    },
  })
end

-- files and search
map("n", "<leader>p", fzf "files", { desc = "go to file" })
map("n", "<leader>o", fzf "oldfiles", { desc = "recent files" })
map("n", "<leader>f", fzf "blines", { desc = "find a word in this file" })
map("n", "<leader>F", fzf "live_grep", { desc = "find in all files" })
map("n", "<leader>P", find_plugins, { desc = "find installed plugins" })

-- clipboard
map("x", "<C-c>", '"+y', { desc = "copy selection" })
map("n", "<C-c>", '"+yy', { desc = "copy line" })
map("n", "<C-v>", '"+p', { desc = "paste" })
map("x", "<C-v>", '"+P', { desc = "paste over selection" })
map({ "i", "c" }, "<C-v>", "<C-r><C-o>+", { desc = "paste" })

-- Esc leaves terminal mode too, so ":" works from anywhere. fzf-lua keeps its
-- own buffer-local <Esc> to close the picker.
map("t", "<Esc>", "<C-\\><C-n>", { desc = "terminal to normal mode" })

-- move between editor and terminal windows; the sidebar is reached only with
-- <leader>e, so these never step into it
for key, dir in pairs { Left = "h", Down = "j", Up = "k", Right = "l" } do
  map({ "n", "i", "t" }, "<A-S-" .. key .. ">", function()
    local target = vim.fn.win_getid(vim.fn.winnr(dir))
    if target == vim.api.nvim_get_current_win() or require("edgy").get_win(target) then
      return
    end
    vim.cmd "stopinsert" -- land in normal mode, as <C-w> would
    vim.api.nvim_set_current_win(target)
  end, { desc = "window " .. key:lower() })
end

-- sidebar
map("n", "<leader>b", function()
  sidebar.toggle()
end, { desc = "toggle left panel" })

-- new file / new panes, always in the editor area
map("n", "<leader>n", function()
  require("configs.newfile").open()
end, { desc = "new file in the tree's selected directory" })

map("n", "<leader>v", function()
  sidebar.main_do "vsplit"
end, { desc = "new pane (vertical)" })

map("n", "<leader>h", function()
  sidebar.main_do "split"
end, { desc = "new pane (horizontal)" })

map("n", "<leader>V", function()
  sidebar.main_do(function()
    require("nvchad.term").new { pos = "vsp" }
  end)
end, { desc = "new terminal (vertical)" })

map("n", "<leader>H", function()
  sidebar.main_do(function()
    require("nvchad.term").new { pos = "sp" }
  end)
end, { desc = "new terminal (horizontal)" })
