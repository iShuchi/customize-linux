-- Replaces the NvChad starter's lua/mappings.lua outright.
-- NvChad's default mappings are not loaded; only the keys in the README are set.
-- The first word of each desc is the heading it gets in the <leader>ch cheatsheet.

local map = vim.keymap.set
local sidebar = require "configs.sidebar"

-- Runs a picker (or command) in the editor area, never inside the sidebar
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

local function format_and_lint()
  require("conform").format({ lsp_format = "fallback", timeout_ms = 2000 }, function(err)
    -- "no formatters" is the normal case for filetypes we only lint, not an error.
    if err and not err:match "No formatters available" then
      vim.notify(err, vim.log.levels.WARN)
    end
    require("configs.lint").lint()
  end)
end

-- files and search
map("n", "<leader>p", fzf "files", { desc = "files go to file" })
map("n", "<leader>o", fzf "oldfiles", { desc = "files recent files" })
map("n", "<leader>f", fzf "blines", { desc = "files find a word in this file" })
map("n", "<leader>F", fzf "live_grep", { desc = "files find in all files" })
map("n", "<leader>P", find_plugins, { desc = "files find installed plugins" })

-- editing
map("n", "<leader>I", format_and_lint, { desc = "edit format and lint the file" })
map({ "n", "i", "v" }, "<C-s>", "<cmd>w<cr>", { desc = "edit save file" })
map("n", "<C-z>", "u", { desc = "edit undo" })
map("i", "<C-z>", "<C-o>u", { desc = "edit undo" })

-- clipboard
map("x", "<C-c>", '"+y', { desc = "edit copy selection" })
map("n", "<C-c>", '"+yy', { desc = "edit copy line" })
map("n", "<C-v>", '"+p', { desc = "edit paste" })
map("x", "<C-v>", '"+P', { desc = "edit paste over selection" })
map({ "i", "c" }, "<C-v>", "<C-r><C-o>+", { desc = "edit paste" })

-- Esc leaves terminal mode too, so ":" works from anywhere. fzf-lua keeps its
-- own buffer-local <Esc> to close the picker.
map("t", "<Esc>", "<C-\\><C-n>", { desc = "edit back to normal mode" })

-- tabs
map("n", "<Tab>", function()
  require("nvchad.tabufline").next()
end, { desc = "panes next tab" })

map("n", "<leader>x", function()
  require("nvchad.tabufline").close_buffer()
end, { desc = "panes close tab" })

-- new panes and terminals, always in the editor area
map("n", "<leader>h", function()
  sidebar.main_do "split"
end, { desc = "panes new pane (horizontal)" })

map("n", "<leader>v", function()
  sidebar.main_do "vsplit"
end, { desc = "panes new pane (vertical)" })

map("n", "<leader>H", function()
  sidebar.main_do(function()
    require("nvchad.term").new { pos = "sp" }
  end)
end, { desc = "panes new terminal (horizontal)" })

map("n", "<leader>V", function()
  sidebar.main_do(function()
    require("nvchad.term").new { pos = "vsp" }
  end)
end, { desc = "panes new terminal (vertical)" })

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
  end, { desc = "panes move " .. key:lower() })
end

-- sidebar
map("n", "<leader>b", sidebar.toggle, { desc = "sidebar show or hide" })
map("n", "<leader>e", "<cmd>NvimTreeFocus<cr>", { desc = "sidebar jump to the file tree" })
map("n", "<leader>n", function()
  require("configs.newfile").open()
end, { desc = "sidebar new file in the tree's selected directory" })

-- this list
map("n", "<leader>ch", "<cmd>NvCheatsheet<cr>", { desc = "help show keybindings" })
