return {
  'nvim-treesitter/nvim-treesitter',

  branch = 'main',
  build = ':TSUpdate',

  config = function()
    require('nvim-treesitter').install({
      'lua',
      'bash',
      'vim',
      'markdown',
    })

    vim.api.nvim_create_autocmd('FileType', {
      pattern = { 'lua', 'bash', 'vim', 'markdown' },

      callback = function()
        vim.treesitter.start()
      end,
    })
  end,
}
