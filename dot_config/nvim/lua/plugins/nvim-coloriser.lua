return {
  "catgoose/nvim-colorizer.lua",
  event = "BufReadPre",
  config = function()
    require("colorizer").setup({
      filetypes = { "*" },
      options = {
        parsers = {
          css = true,
        },
      },
    })
  end
}
