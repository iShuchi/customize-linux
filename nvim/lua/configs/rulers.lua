-- Vertical rulers

local M = {}

M.columns = {
  python = 88, -- "[python]".editor.rulers
  c = 80, -- "[c]".editor.rulers
  cpp = 80, -- "[cpp]".editor.rulers
  sh = 80, -- "[shellscript]".editor.rulers
  bash = 80,
  zsh = 80,
  yaml = 80, -- "[yaml]".editor.rulers
  markdown = 80, -- "[markdown]".editor.rulers
}

M.CHAR = "│"
M.DEFAULT_HL = "VirtColumn"
M.highlight = {
  markdown = "MarkdownRuler",
}

local ns = vim.api.nvim_create_namespace "UserRulers"

function M.setup()
  vim.api.nvim_set_decoration_provider(ns, {
    on_win = function(_, _, buf)
      return M.columns[vim.bo[buf].filetype] ~= nil
    end,
    on_line = function(_, _, buf, row)
      local ft = vim.bo[buf].filetype
      local col = M.columns[ft]
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
      if not line then
        return
      end
      if vim.fn.strdisplaywidth(line) >= col then
        return
      end
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = { { M.CHAR, M.highlight[ft] or M.DEFAULT_HL } },
        virt_text_win_col = col - 1,
        ephemeral = true,
      })
    end,
  })
end

return M
