-- lazy.neovim load
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/lazy.nvim')

-- plugins
require('lazy').setup({
  {
    'ellisonleao/gruvbox.nvim', -- theme
    priority = 1000,
    config = function()
      vim.cmd.colorscheme('gruvbox') -- colours
    end,
  },
  {
  'nvim-treesitter/nvim-treesitter',
  branch = 'main',
  build = ':TSUpdate',
  config = function()
    require('nvim-treesitter').install({ 'lua', 'bash', 'vim', 'markdown' })
    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'lua', 'bash', 'vim', 'markdown' },
      callback = function()
        vim.treesitter.start()
      end,
     })
  end,
  },
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      require('gitsigns').setup()
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('lualine').setup({
        options = { theme = 'gruvbox' },
      })
    end,
  },
})

-- change in specific colour overrides
vim.api.nvim_set_hl(0, 'Normal', { bg = '#000000' }) -- pitch black
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = '#000000' })
vim.api.nvim_set_hl(0, 'SignColumn', { bg = '#000000' })
vim.api.nvim_set_hl(0, 'Keyword', { fg = '#C9A177' }) -- coffee brown
vim.api.nvim_set_hl(0, 'Number', { fg = '#F5E6CA' }) -- cream
vim.api.nvim_set_hl(0, 'Boolean', { fg = '#F5E6CA' })
vim.api.nvim_set_hl(0, 'Function', { fg = '#B48EAD' }) -- purple

-- line numbers
vim.opt.number = true

-- cursor
vim.opt.cursorline = true
