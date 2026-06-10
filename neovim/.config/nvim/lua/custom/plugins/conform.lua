return {
  { -- Autoformat
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>f",
        function()
          require("conform").format({ async = true, lsp_format = "fallback" })
        end,
        mode = "",
        desc = "[F]ormat buffer",
      },
    },
    ---@module 'conform'
    ---@type conform.setupOpts
    opts = {
      notify_on_error = false,
      format_on_save = function(bufnr)
        local disable_filetypes = {}
        if disable_filetypes[vim.bo[bufnr].filetype] then
          return nil
        else
          return {
            timeout_ms = 500,
            lsp_format = "fallback",
          }
        end
      end,
      formatters_by_ft = {
        lua = { "stylua" },
        python = { "ruff_format" },
        sh = { "beautysh" },
        bash = { "beautysh" },
        zsh = { "beautysh" },
        c = { "clang-format" },
        cpp = { "clang-format" },
        java = { "clang-format" },
        json = { "jq" },
        yaml = { "yamlfmt" },
        markdown = { "markdownlint" },
        toml = { "taplo" },
        nix = { "nixfmt" },
      },
      formatters = {
        -- Force stylua to use spaces instead of its default tabs.
        -- This prevents Neovim from rendering tabs as `^` listchars
        -- and keeps indent-blankline's smooth vertical guides intact.
        stylua = {
          prepend_args = { "--indent-type", "Spaces", "--indent-width", "2" },
        },
      },
    },
  },
}
