local M = {}

-- The NVIM logo at four sizes, largest first; the sidebar shows the biggest
-- one that fits its width. Each size lists its four letters as equal-width
-- rows, so every letter gets its own colour: NvimLogo1..4, defined in
-- lua/chadrc.lua from espresso's palette.
local LOGOS = {
  {
    gap = 0,
    letters = {
      { "███╗   ██╗", "████╗  ██║", "██╔██╗ ██║", "██║╚██╗██║", "██║ ╚████║", "╚═╝  ╚═══╝" },
      { "██╗   ██╗", "██║   ██║", "██║   ██║", "╚██╗ ██╔╝", " ╚████╔╝ ", "  ╚═══╝  " },
      { "██╗", "██║", "██║", "██║", "██║", "╚═╝" },
      { "███╗   ███╗", "████╗ ████║", "██╔████╔██║", "██║╚██╔╝██║", "██║ ╚═╝ ██║", "╚═╝     ╚═╝" },
    },
  },
  {
    gap = 1,
    letters = {
      { "█▄  █", "█ █ █", "█  ▀█" },
      { "█   █", "▀▄ ▄▀", "  ▀  " },
      { "█", "█", "█" },
      { "█▄ ▄█", "█ ▀ █", "█   █" },
    },
  },
  {
    gap = 1,
    letters = {
      { "█▄ █", "█ ▀█" },
      { "█ █", "▀▄▀" },
      { "█", "█" },
      { "█▀▄▀█", "█ ▀ █" },
    },
  },
  { gap = 1, letters = { { "N" }, { "V" }, { "I" }, { "M" } } },
}

for _, logo in ipairs(LOGOS) do
  logo.width = logo.gap * (#logo.letters - 1)
  for _, letter in ipairs(logo.letters) do
    logo.width = logo.width + vim.fn.strdisplaywidth(letter[1])
  end
end

M.LOGO_FT = "nvimlogo"
M.WIDTH = 0.25

local ns = vim.api.nvim_create_namespace("nvimlogo")

---@param width integer
local function pick_logo(width)
  for _, logo in ipairs(LOGOS) do
    if logo.width <= width then
      return logo
    end
  end
  return LOGOS[#LOGOS]
end

-- Logo panel height, read by edgy: the logo plus two blank lines under it.
-- Uses the sidebar's settled width so a slide doesn't flip between sizes.
function M.logo_height()
  return #pick_logo(math.floor(vim.o.columns * M.WIDTH)).letters[1] + 2
end

---@param buf integer
---@param win integer
local function draw_logo(buf, win)
  if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then
    return
  end
  local width = vim.api.nvim_win_get_width(win)
  local logo = pick_logo(width)
  local indent = string.rep(" ", math.max(math.floor((width - logo.width) / 2), 0))
  local gap = string.rep(" ", logo.gap)
  local lines, marks = {}, {}
  for r = 1, #logo.letters[1] do
    local line = indent
    for i, letter in ipairs(logo.letters) do
      if i > 1 then
        line = line .. gap
      end
      -- byte offsets: the block characters are multi-byte
      marks[#marks + 1] = { r - 1, #line, #line + #letter[r], "NvimLogo" .. i }
      line = line .. letter[r]
    end
    lines[r] = line
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(buf, ns, m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
end

function M.open_logo()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = M.LOGO_FT
  vim.cmd("topleft split")
  vim.api.nvim_win_set_buf(0, buf)
  local win = vim.api.nvim_get_current_win()
  draw_logo(buf, win)
  vim.defer_fn(function() draw_logo(buf, win) end, 200)
end

function M.track_logo()
  vim.api.nvim_create_autocmd({ "WinResized", "VimResized", "BufWinEnter" }, {
    group = vim.api.nvim_create_augroup("SidebarLogoCenter", { clear = true }),
    callback = function()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype == M.LOGO_FT then
          draw_logo(b, w)
        end
      end
    end,
  })
end

-- `notify` is false when edgy calls this to restore a pinned view: opening a
-- non-repo directory should not warn on every sidebar open.
local function in_repo(notify)
  if vim.fn.isdirectory ".git" == 1 or vim.fn.finddir(".git", ".;") ~= "" then
    return true
  end
  if notify then
    vim.notify("not inside a git repository", vim.log.levels.WARN)
  end
  return false
end

function M.graph(notify)
  if not in_repo(notify) then
    return
  end
  require("edgy").goto_main()
  vim.cmd "split"
  require("gitgraph").draw({}, { all = true, max_count = 500 })
  M.graph_to_top()
end

local GRAPH_TOP_RETRIES = { 0, 60, 150, 350, 700, 1000 }

function M.graph_to_top()
  for _, delay in ipairs(GRAPH_TOP_RETRIES) do
    vim.defer_fn(function()
      for _, w in ipairs(vim.api.nvim_list_wins()) do
        local b = vim.api.nvim_win_get_buf(w)
        if vim.bo[b].filetype == "gitgraph" and vim.api.nvim_buf_line_count(b) > 0 then
          vim.api.nvim_win_call(w, function()
            vim.fn.winrestview { topline = 1, lnum = 1, col = 0, leftcol = 0 }
          end)
        end
      end
    end, delay)
  end
end

local function ensure_main()
  local edgy = require "edgy"
  for _, w in ipairs(vim.api.nvim_list_wins()) do
    if not edgy.get_win(w) then
      return
    end
  end
  vim.cmd "botright vsplit"
  vim.cmd "enew"
end

---@return integer[]
local function main_columns()
  local edgy = require "edgy"
  local layout = vim.fn.winlayout()
  local nodes = layout[1] == "row" and layout[2] or { layout }
  local wins = {}
  for _, node in ipairs(nodes) do
    while node[1] ~= "leaf" do
      node = node[2][1]
    end
    if not edgy.get_win(node[2]) then
      table.insert(wins, node[2])
    end
  end
  return wins
end

local SLIDE_MS, SLIDE_FRAMES = 150, 10
local slide_width ---@type integer?
local sliding = false

-- edgy reads the sidebar width through this on every resize, so during a
-- slide it follows the animation instead of snapping back to M.WIDTH.
function M.width()
  return slide_width or M.WIDTH
end

---@return integer?
local function sidebar_win()
  local edgy = require "edgy"
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local ew = edgy.get_win(w)
    if ew and ew.view.edgebar.pos == "left" then
      return w
    end
  end
end

---@param cols integer[]
---@return number[]
local function ratios_of(cols)
  local widths, total = {}, 0
  for i, w in ipairs(cols) do
    widths[i] = vim.api.nvim_win_get_width(w)
    total = total + widths[i]
  end
  for i = 1, #widths do
    widths[i] = widths[i] / total
  end
  return widths
end

-- Left to right: each resize trades space with the columns to its right, and
-- the last column takes whatever is left.
---@param cols integer[]
---@param ratios number[]
local function set_ratios(cols, ratios)
  local total = 0
  for _, w in ipairs(cols) do
    if not vim.api.nvim_win_is_valid(w) then
      return
    end
    total = total + vim.api.nvim_win_get_width(w)
  end
  for i = 1, #cols - 1 do
    vim.api.nvim_win_set_width(cols[i], math.floor(ratios[i] * total + 0.5))
  end
end

-- Slides the sidebar between two widths (ease-out), holding the editor
-- columns at their ratios on every frame.
local function slide(from, to, cols, ratios, done)
  local frame = 0
  local function step()
    frame = frame + 1
    local t = 1 - (1 - frame / SLIDE_FRAMES) ^ 3
    slide_width = math.max(math.floor(from + (to - from) * t + 0.5), 1)
    local sw = sidebar_win()
    if sw then
      vim.api.nvim_win_set_width(sw, slide_width)
    end
    set_ratios(cols, ratios)
    if frame < SLIDE_FRAMES then
      vim.defer_fn(step, SLIDE_MS / SLIDE_FRAMES)
    else
      done()
    end
  end
  step()
end

function M.toggle()
  if sliding then
    return
  end
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and vim.fn.isdirectory(name) == 1 then
    vim.cmd "enew"
  end

  -- Without this, Neovim takes (or gives back) the sidebar's whole width
  -- from the leftmost editor column only.
  local cols = main_columns()
  local ratios = ratios_of(cols)
  local edgy = require "edgy"
  local function finish()
    slide_width = nil
    sliding = false
    -- Deferred, not scheduled: edgy has not finished claiming windows on the
    -- next tick, so an immediate check still sees a "main" window and bails.
    vim.defer_fn(ensure_main, 200)
  end

  sliding = true
  local sw = sidebar_win()
  if sw then
    slide(vim.api.nvim_win_get_width(sw), 1, cols, ratios, function()
      edgy.close "left"
      vim.schedule(function()
        set_ratios(cols, ratios)
        finish()
      end)
    end)
  else
    slide_width = 1
    edgy.open "left"
    -- edgy creates the sidebar windows on the next tick.
    vim.schedule(function()
      slide(1, math.max(math.floor(vim.o.columns * M.WIDTH), 1), cols, ratios, finish)
    end)
  end
end

function M.track_drags()
  vim.api.nvim_create_autocmd("WinResized", {
    group = vim.api.nvim_create_augroup("SidebarDrag", { clear = true }),
    callback = function()
      local ok, edgy = pcall(require, "edgy")
      if not ok then
        return
      end
      for _, w in ipairs(vim.v.event.windows or {}) do
        if vim.api.nvim_win_is_valid(w) then
          local ew = edgy.get_win(w)
          -- Only vertical edgebars stack their views, so only they have a
          -- meaningful per-panel height to pin.
          if ew and ew.view and ew.view.edgebar and ew.view.edgebar.pos == "left" then
            local actual = vim.api.nvim_win_get_height(w)
            if actual > 0 and actual ~= ew.height then
              vim.w[w].edgy_height = actual
            end
          end
        end
      end
    end,
  })
end

---@return boolean
local function startup_ok()
  -- diff mode (nvim -d, git difftool)
  if vim.o.diff then
    return false
  end
  -- git commit / rebase buffers
  local ft = vim.bo.filetype
  if ft == "gitcommit" or ft == "gitrebase" then
    return false
  end
  -- reading from stdin, e.g. `cat x | nvim -`
  for _, a in ipairs(vim.fn.argv()) do
    if a == "-" then
      return false
    end
  end
  return true
end

---@return boolean
local function should_restore()
  local argv = vim.fn.argv()
  if #argv == 0 then
    return true
  end
  return #argv == 1 and vim.fn.isdirectory(argv[1]) == 1
end

---@return string?
local function last_file()
  local cwd = vim.uv.cwd()
  if not cwd then
    return nil
  end
  cwd = cwd:gsub("/$", "") .. "/"
  local state, data = vim.fn.stdpath "state", vim.fn.stdpath "data"
  for _, f in ipairs(vim.v.oldfiles or {}) do
    if vim.startswith(f, cwd)
      and not vim.startswith(f, state)
      and not vim.startswith(f, data)
      and not f:find("/%.git/")
      and vim.fn.filereadable(f) == 1
    then
      return f
    end
  end
  return nil
end

function M.autostart()
  vim.api.nvim_create_autocmd("VimEnter", {
    group = vim.api.nvim_create_augroup("SidebarAutostart", { clear = true }),
    nested = true,
    callback = function()
      if not startup_ok() then
        return
      end
      -- Scheduled so it runs after lazy has finished its VimEnter work.
      vim.schedule(function()
        if should_restore() then
          local f = last_file()
          if f then
            vim.cmd.edit(vim.fn.fnameescape(f))
            -- '"' is the cursor position when the file was last closed; shada
            -- has been read by now, so the mark is available.
            local mark = vim.api.nvim_buf_get_mark(0, '"')
            if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(0) then
              pcall(vim.api.nvim_win_set_cursor, 0, mark)
              vim.cmd "normal! zz"
            end
          end
        end
        M.toggle()
      end)
    end,
  })
end

function M.track_graph_top()
  vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType" }, {
    group = vim.api.nvim_create_augroup("SidebarGraphTop", { clear = true }),
    pattern = "*",
    callback = function(ev)
      if vim.bo[ev.buf].filetype == "gitgraph" then
        M.graph_to_top()
      end
    end,
  })
end

---@param cmd string|function
function M.main_do(cmd)
  pcall(function()
    require("edgy").goto_main()
  end)
  if type(cmd) == "function" then
    cmd()
  else
    vim.cmd(cmd)
  end
end

function M.track_graph_keys()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("SidebarGraphKeys", { clear = true }),
    pattern = "gitgraph",
    callback = function(ev)
      local function nm(lhs, rhs, desc)
        vim.keymap.set("n", lhs, rhs, { buffer = ev.buf, desc = desc, nowait = true })
      end
      nm("<S-Right>", "zL", "graph: scroll right")
      nm("<S-Left>", "zH", "graph: scroll left")
      nm("<ScrollWheelRight>", "zl", "graph: scroll right")
      nm("<ScrollWheelLeft>", "zh", "graph: scroll left")
      nm("<Home>", "zH", "graph: scroll to start")
      vim.wo[vim.fn.bufwinid(ev.buf)].wrap = false
    end,
  })
end

return M
