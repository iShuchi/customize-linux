-- Formatters

return {
  formatters_by_ft = {
    python = { "ruff_organize_imports", "ruff_fix", "black" },
    c = { "clang-format" },
    cpp = { "clang-format" },
    sh = { "shfmt" },
    bash = { "shfmt" },
    xml = { "xmllint" },
    lua = { "stylua" },
  },

  formatters = {
    black = { prepend_args = { "--line-length=88" } },
    ["clang-format"] = { prepend_args = { "--style=file", "--fallback-style=Google" } },
    shfmt = { args = { "-filename", "$FILENAME", "-i", "4", "-ci", "-bn" } },
  },
}
