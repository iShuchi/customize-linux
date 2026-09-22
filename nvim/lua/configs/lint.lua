-- Linting (nvim-lint). Diagnostics run automatically on read/save/InsertLeave,
-- and on demand via the format+lint mapping in lua/mappings.lua.

local M = {}

M.linters_by_ft = {
  sh = { "shellcheck" },
  bash = { "shellcheck" },
  python = { "ruff" },
  c = { "clangtidy" },
  cpp = { "clangtidy" },
  lua = { "luacheck" },
}

-- Only run linters whose executable is actually installed, otherwise nvim-lint
-- raises a notification on every lint for every tool you happen not to have.
local function runnable_for(ft)
  local lint = require "lint"
  local runnable = {}

  for _, name in ipairs(M.linters_by_ft[ft] or {}) do
    local linter = lint.linters[name]
    local cmd = type(linter) == "table" and linter.cmd or name
    if type(cmd) == "function" then
      cmd = cmd()
    end
    if vim.fn.executable(cmd) == 1 then
      table.insert(runnable, name)
    end
  end

  return runnable
end

function M.lint()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return
  end

  local runnable = runnable_for(vim.bo.filetype)
  if #runnable > 0 then
    lint.try_lint(runnable)
  end
end

function M.setup()
  require("lint").linters_by_ft = M.linters_by_ft

  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
    group = vim.api.nvim_create_augroup("UserLint", { clear = true }),
    callback = function()
      M.lint()
    end,
  })

  M.lint()
end

return M
