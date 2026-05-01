return {
  {
    'mfussenegger/nvim-lint',
    event = { 'BufReadPre', 'BufNewFile' },
    config = function()
      local lint = require('lint')

      lint.linters_by_ft = {
        sh = { 'shellcheck' },
        bash = { 'shellcheck' },
        python = { 'ruff' },
      }

      local lint_augroup = vim.api.nvim_create_augroup('nvim-lint', { clear = true })
      vim.api.nvim_create_autocmd({ 'BufWritePost', 'BufReadPost', 'InsertLeave' }, {
        group = lint_augroup,
        callback = function()
          -- Skip read-only / non-modifiable buffers (e.g. LSP hover popups).
          if vim.bo.modifiable then lint.try_lint() end
        end,
      })
    end,
  },
}
