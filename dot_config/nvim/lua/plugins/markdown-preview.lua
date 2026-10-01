return {
  -- Markdown preview in your browser
  'iamcco/markdown-preview.nvim',

  cmd = {
    'MarkdownPreviewToggle',
    'MarkdownPreview',
    'MarkdownPreviewStop',
  },

  build = 'cd app && ./install.sh',

  init = function()
    vim.g.mkdp_filetypes = { 'markdown' }
  end,

  ft = { 'markdown' },
}
