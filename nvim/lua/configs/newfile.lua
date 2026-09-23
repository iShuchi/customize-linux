-- <leader>+n -- create a file inside the directory selected in the file tree.

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

---@return string? directory under the tree cursor, nil when it is on a file
local function selected_dir()
  local ok, api = pcall(require, "nvim-tree.api")
  if not ok then
    return nil
  end
  local node = api.tree.get_node_under_cursor()
  if not node or not node.absolute_path or node.absolute_path == "" then
    return nil
  end
  if node.type == "directory" or vim.fn.isdirectory(node.absolute_path) == 1 then
    return node.absolute_path
  end
  return nil
end

---Path as it reads in the box title: relative to cwd, or the tail at the root.
---@param dir string
---@return string
local function label(dir)
  local rel = vim.fn.fnamemodify(dir, ":~:.")
  if rel == "." or rel == "" then
    rel = vim.fn.fnamemodify(dir, ":t")
  end
  return rel
end

---Nothing usable under the cursor: put the cursor in the tree and say so.
---@param win integer
local function ask_for_dir(win)
  vim.api.nvim_set_current_win(win)
  vim.notify("pick a directory in the tree, then press <leader>n again", vim.log.levels.INFO)
end

local function reload_tree()
  pcall(function()
    require("nvim-tree.api").tree.reload()
  end)
end

---@param dir string directory the name is relative to
---@param name string what was typed into the box
function M.create(dir, name)
  if name == "" then
    return -- empty box, treated as a cancel
  end
  
  local dir_only = name:sub(-1) == "/"
  local path = vim.fs.normalize(dir .. "/" .. name)

  if vim.fn.fnamemodify(path, ":t") == "" then
    vim.notify("new file: '" .. name .. "' has no filename in it", vim.log.levels.WARN)
    return
  end

  if dir_only then
    if vim.fn.isdirectory(path) == 0 and not pcall(vim.fn.mkdir, path, "p") then
      vim.notify("new file: could not create " .. label(path), vim.log.levels.ERROR)
      return
    end
    reload_tree()
    vim.notify(label(path) .. "/ ready, press <leader>n on it to add a file", vim.log.levels.INFO)
    return
  end

  if vim.fn.isdirectory(path) == 1 then
    vim.notify("new file: " .. label(path) .. " is a directory", vim.log.levels.WARN)
    return
  end

  -- A typed name may carry directories of its own ("configs/new.lua"), so the
  -- parent chain is created before the file.
  local parent = vim.fs.dirname(path)
  if vim.fn.isdirectory(parent) == 0 then
    local made = pcall(vim.fn.mkdir, parent, "p")
    if not made then
      vim.notify("new file: could not create " .. label(parent), vim.log.levels.ERROR)
      return
    end
  end

  local existed = vim.fn.filereadable(path) == 1
  if not existed then
    -- Touched on disk rather than left as an unwritten buffer, so the tree
    -- lists it straight away instead of after the first :w.
    local fd = io.open(path, "w")
    if not fd then
      vim.notify("new file: could not create " .. label(path), vim.log.levels.ERROR)
      return
    end
    fd:close()
  end

  -- goto_main() first, so the file never opens inside an edgy panel.
  sidebar.main_do("edit " .. vim.fn.fnameescape(path))
  reload_tree()

  if existed then
    vim.notify(label(path) .. " already existed, opened it", vim.log.levels.INFO)
  end
end

---One-line box over the sidebar, asking for the name.
---@param win integer tree window it is anchored to
---@param dir string directory the file goes in
local function open_box(win, dir)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false

  -- Anchored to the tree pane rather than centred over the editor: the
  -- directory it is about is the one highlighted right behind the box.
  local width = math.max(vim.api.nvim_win_get_width(win) - 4, 12)
  local title = " " .. label(dir) .. "/ "
  if vim.fn.strdisplaywidth(title) > width then
    title = " …" .. vim.fn.strcharpart(label(dir), vim.fn.strchars(label(dir)) - width + 4) .. "/ "
  end

  local box = vim.api.nvim_open_win(buf, true, {
    relative = "win",
    win = win,
    row = 1,
    col = 1,
    width = width,
    height = 1,
    style = "minimal",
    border = "rounded",
    title = title,
    title_pos = "center",
  })

  local function close()
    if vim.api.nvim_win_is_valid(box) then
      vim.api.nvim_win_close(box, true)
    end
  end

  local function cancel()
    close()
    vim.cmd "stopinsert"
  end

  local function confirm()
    local typed = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ""
    close()
    vim.cmd "stopinsert"
    M.create(dir, vim.trim(typed))
  end

  vim.keymap.set({ "i", "n" }, "<CR>", confirm, { buffer = buf, nowait = true, desc = "create the file" })
  vim.keymap.set({ "i", "n" }, "<Esc>", cancel, { buffer = buf, nowait = true, desc = "cancel" })
  vim.keymap.set({ "i", "n" }, "<C-c>", cancel, { buffer = buf, nowait = true, desc = "cancel" })
  -- Clicking away is a cancel too, otherwise the box outlives its window.
  vim.api.nvim_create_autocmd("BufLeave", { buffer = buf, once = true, callback = close })

  vim.cmd "startinsert"
end

---Entry point for <leader>n.
function M.open()
  local win = tree_win()

  if not win then
    -- No tree on screen. Open the sidebar and ask once edgy has drawn it --
    -- the same wait M.toggle()'s own main-window guard uses.
    sidebar.toggle()
    vim.defer_fn(function()
      local w = tree_win()
      if w then
        ask_for_dir(w)
      else
        vim.notify("new file: could not open the file tree", vim.log.levels.WARN)
      end
    end, 250)
    return
  end

  local dir = selected_dir()
  if not dir then
    ask_for_dir(win)
    return
  end

  open_box(win, dir)
end

return M
