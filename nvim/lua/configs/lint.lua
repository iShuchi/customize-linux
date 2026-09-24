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

function M.lint()
  local ok, lint = pcall(require, "lint")
  if not ok then
    return
  end
  lint.try_lint(nil, { ignore_errors = true })
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
