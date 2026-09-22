-- Diagnostics presentation.

local M = {}

local S = vim.diagnostic.severity

local ICON = {
  [S.ERROR] = "✗",
  [S.WARN] = "",
  [S.INFO] = "󰋼",
  [S.HINT] = "󰌵",
}

local HL = {
  [S.ERROR] = "DiagnosticError",
  [S.WARN] = "DiagnosticWarn",
  [S.INFO] = "DiagnosticInfo",
  [S.HINT] = "DiagnosticHint",
}

-- Tracks whether the last thing on the command line was ours, so we only clear
-- our own message and never stomp on ":w" style feedback.
local echoing = false

local function clear()
  if echoing then
    vim.api.nvim_echo({}, false, {})
    echoing = false
  end
end

local function show()
  -- Only in normal mode: echoing while typing fights with the command line.
  if vim.api.nvim_get_mode().mode ~= "n" then
    return
  end

  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local list = vim.diagnostic.get(0, { lnum = lnum })
  if #list == 0 then
    clear()
    return
  end

  -- Most severe first (ERROR == 1).
  table.sort(list, function(a, b)
    return a.severity < b.severity
  end)
  local d = list[1]

  local msg = d.message:gsub("%s+", " ")
  if #list > 1 then
    msg = msg .. (" (+%d more)"):format(#list - 1)
  end
  msg = (ICON[d.severity] or "") .. " " .. msg

  -- Truncate, or a long message triggers the "Press ENTER" prompt.
  local room = vim.o.columns - 12
  if vim.fn.strdisplaywidth(msg) > room then
    msg = vim.fn.strcharpart(msg, 0, room - 1) .. "…"
  end

  vim.api.nvim_echo({ { msg, HL[d.severity] or "Normal" } }, false, {})
  echoing = true
end

function M.setup()
  vim.diagnostic.config {
    -- Off: this is the inline text at the end of the line.
    virtual_text = false,
    signs = { text = ICON },
    underline = true,
    severity_sort = true,
    float = { border = "rounded", source = true },
  }

  local group = vim.api.nvim_create_augroup("UserDiagnosticEcho", { clear = true })
  -- CursorHold fires after 'updatetime' (NvChad sets 250ms).
  vim.api.nvim_create_autocmd({ "CursorHold", "DiagnosticChanged" }, {
    group = group,
    callback = show,
  })
  vim.api.nvim_create_autocmd({ "CursorMoved", "InsertEnter", "BufLeave" }, {
    group = group,
    callback = clear,
  })
end

return M
