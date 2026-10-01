vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0

-- lazy.neovim load
vim.opt.rtp:prepend(vim.fn.stdpath('data') .. '/lazy/lazy.nvim')

-- allow termguicolors
vim.opt.termguicolors = true

-- plugins
require('lazy').setup({
  spec = {
    { import = 'plugins' },
  },
  rocks = { enabled = false },
})

-- change in specific colour overrides
vim.api.nvim_set_hl(0, 'Normal', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'NormalFloat', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'SignColumn', { bg = 'NONE' })
vim.api.nvim_set_hl(0, 'Keyword', { fg = '#C9A177' }) -- coffee brown
vim.api.nvim_set_hl(0, 'Number', { fg = '#F5E6CA' }) -- cream
vim.api.nvim_set_hl(0, 'Boolean', { fg = '#F5E6CA' })
vim.api.nvim_set_hl(0, 'Function', { fg = '#B48EAD' }) -- purple

-- line numbers
vim.opt.number = true

-- cursor
vim.opt.cursorline = true
