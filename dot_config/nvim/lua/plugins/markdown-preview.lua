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
    -- full-width layout (copy of the default style + width override)
    vim.g.mkdp_markdown_css = vim.fn.expand('~/.config/nvim/markdown-preview.css')
    -- always dark, regardless of system preference
    vim.g.mkdp_theme = 'dark'
    -- reuse one browser tab instead of opening a new one each time
    vim.g.mkdp_combine_preview = 1
    vim.g.mkdp_auto_close = 0
    -- fixed port, so the address stays the same
    vim.g.mkdp_port = '8308'
  end,

  ft = { 'markdown' },
}
