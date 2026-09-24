-- create a file in the folder under the tree cursor.

local M = {}

local sidebar = require "configs.sidebar"

---@return integer? window holding the tree, when it is on screen
local function tree_win()
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    local b = vim.api.nvim_win_get_buf(w)
    if vim.api.nvim_buf_is_valid(b) and vim.bo[b].filetype == "NvimTree" then
      return w
    end
  end
  return nil
end

---Path as it reads in the box title: relative to cwd, or the tail at the root.
---@param dir string
---@return string
local function label(dir)
  local rel = vim.fn.fnamemodify(vim.fs.normalize(dir), ":~:.")
  if rel == "." or rel == "" then
    rel = vim.fn.fnamemodify(vim.fs.normalize(dir), ":t")
  end
  return rel
end

---@param win integer tree window
---@param node table? nvim-tree node under the cursor
---@return integer row, integer col, integer width
local function anchor(win, node)
  local lnum = vim.api.nvim_win_get_cursor(win)[1]
  local line = vim.api.nvim_buf_get_lines(vim.api.nvim_win_get_buf(win), lnum - 1, lnum, false)[1] or ""
  local win_w, win_h = vim.api.nvim_win_get_width(win), vim.api.nvim_win_get_height(win)

  local col = 0
  local s = node and node.name and line:find(node.name, 1, true)
  if s then
    col = vim.fn.strdisplaywidth(line:sub(1, s - 1))
    if node.type ~= "directory" then
      col = col - 2
    end
  end
  local width = math.max(win_w - col - 2, 16)
  col = math.max(math.min(col, win_w - width - 2), 0)

  -- winline() is 1-based, so as a 0-based float row it is the line below the
  -- cursor. Too close to the bottom, the box goes above the line instead.
  local row = vim.api.nvim_win_call(win, vim.fn.winline)
  if row + 3 > win_h then
    row = math.max(row - 4, 0)
  end
  return row, col, width
end

---One-line box inside the tree, asking for the name.
---@param win integer tree window it is anchored to
---@param node table? node the box is placed under
---@param dir string folder the name is relative to, with a trailing "/"
---@param done fun(name: string?)
local function name_box(win, node, dir, done)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"

  local row, col, width = anchor(win, node)
  local title = " " .. label(dir) .. "/ "
  if vim.fn.strdisplaywidth(title) > width then
    local l = label(dir)
    title = " …" .. vim.fn.strcharpart(l, vim.fn.strchars(l) - width + 5) .. "/ "
  end

  local box = vim.api.nvim_open_win(buf, true, {
    relative = "win",
    win = win,
    row = row,
    col = col,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })
  -- Drop the "pick a directory" hint from an earlier press.
  vim.api.nvim_echo({}, false, {})

  local function finish(name)
    if vim.api.nvim_win_is_valid(box) then
      vim.api.nvim_win_close(box, true)
    end
    vim.cmd "stopinsert"
    done(name)
  end

  local function confirm()
    finish(vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""))
  end

  local function cancel()
    finish(nil)
  end

  vim.keymap.set({ "i", "n" }, "<CR>", confirm, { buffer = buf, nowait = true, desc = "create the file" })
  vim.keymap.set({ "i", "n" }, "<Esc>", cancel, { buffer = buf, nowait = true, desc = "cancel" })
  vim.keymap.set({ "i", "n" }, "<C-c>", cancel, { buffer = buf, nowait = true, desc = "cancel" })
  -- Clicking away is a cancel too, otherwise the box outlives its window.
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(box) then
        vim.api.nvim_win_close(box, true)
      end
    end,
  })

  vim.cmd "startinsert"
end

---Entry point for <leader>n.
function M.open()
  local win = tree_win()

  if not win then
    -- No tree on screen. Open the sidebar and ask once edgy has drawn it --
    -- the same wait sidebar.toggle()'s own main-window guard uses.
    sidebar.toggle()
    vim.defer_fn(function()
      local w = tree_win()
      if w then
        vim.api.nvim_set_current_win(w)
        vim.notify("pick a directory in the tree, then press <leader>n again", vim.log.levels.INFO)
      else
        vim.notify("new file: could not open the file tree", vim.log.levels.WARN)
      end
    end, 250)
    return
  end

  local api = require "nvim-tree.api"
  local node = api.tree.get_node_under_cursor()

  -- api.fs.create asks through vim.ui.input, which would be a cmdline prompt.
  -- For this one call it is the box instead. nvim-tree passes the target folder
  -- as `default`, so only the name is typed.
  local ui_input = vim.ui.input
  vim.ui.input = function(opts, on_confirm)
    vim.ui.input = ui_input
    local dir = opts.default
    name_box(win, node, dir, function(name)
      if not name or name == "" then
        return on_confirm(nil)
      end
      local path = dir .. name
      on_confirm(path)
      -- Opened whether it was just made or already there; a "dir/" entry is
      -- not a readable file, so it only shows up in the tree.
      if vim.fn.filereadable(path) == 1 then
        sidebar.main_do("edit " .. vim.fn.fnameescape(path))
      end
    end)
  end

  local ok, err = pcall(api.fs.create, node)
  vim.ui.input = ui_input
  if not ok then
    vim.notify("new file: " .. tostring(err), vim.log.levels.ERROR)
  end
end

return M
