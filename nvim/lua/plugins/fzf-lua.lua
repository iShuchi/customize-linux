-- Fuzzy finding, as in jdhao/nvim-config. Needs the fzf binary on PATH;
-- ripgrep for grep, fd (optional) for faster file listing.

return {
  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      winopts = { border = "rounded" },
    },
  },
}
