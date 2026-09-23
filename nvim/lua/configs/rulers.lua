-- Vertical ruler

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

M.highlight = {
  markdown = "ColorColumn:MarkdownRuler",
}

function M.setup()
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("UserRulers", { clear = true }),
    pattern = vim.tbl_keys(M.columns),
    callback = function(ev)
      local ft = vim.bo[ev.buf].filetype
      local col = M.columns[ft]
      if not col then
        return
      end
      vim.opt_local.colorcolumn = tostring(col)
      if M.highlight[ft] then
        vim.opt_local.winhighlight:append(M.highlight[ft])
      end
    end,
  })
end

return M
