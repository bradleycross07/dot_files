return {
  -- gruvbox colour theme
  'ellisonleao/gruvbox.nvim',

  -- loads the theme before other plugins
  priority = 1000,

  config = function()
    vim.cmd.colorscheme('gruvbox')
  end,
}
