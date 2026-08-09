return {
  "nvimdev/guard.nvim",
  dependencies = { "nvimdev/guard-collection" },
  event = "BufReadPre",
  config = function()
    local ft = require("guard.filetype")

    ft("lua"):fmt("stylua")

    ft("sh,bash"):fmt("shfmt"):lint("shellcheck")

    vim.g.guard_config = {
      fmt_on_save = true,
      lsp_as_default_formatter = false,
    }
  end
}
