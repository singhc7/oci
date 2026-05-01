-- [[ Basic Autocommands ]]
--  See `:help lua-guide-autocommands`

-- Highlight when yanking (copying) text
--  Try it with `yap` in normal mode
--  See `:help vim.hl.on_yank()`
vim.api.nvim_create_autocmd('TextYankPost', {
  desc = 'Highlight when yanking (copying) text',
  group = vim.api.nvim_create_augroup('kickstart-highlight-yank', { clear = true }),
  callback = function() vim.hl.on_yank() end,
})

-- jump to last edit position on opening file
vim.api.nvim_create_autocmd('BufReadPost', {
  pattern = '*',
  callback = function(ev)
    if vim.fn.line "'\"" > 1 and vim.fn.line "'\"" <= vim.fn.line "$" then
      -- except for in git commit messages
      -- https://stackoverflow.com/questions/31449496/vim-ignore-specifc-file-in-autocommand
      if not vim.fn.expand('%:p'):find('.git', 1, true) then
        vim.cmd 'exe "normal! g\'\\""'
      end
    end
  end,
})

-- shorter columns in text because it reads better that way
local text = vim.api.nvim_create_augroup('text', { clear = true })
for _, pat in ipairs { 'text', 'markdown', 'mail', 'gitcommit' } do
  vim.api.nvim_create_autocmd('Filetype', {
    pattern = pat,
    group = text,
    command = 'setlocal spell tw=72 colorcolumn=73',
  })
end
--- tex has so much syntax that a little wider is ok
vim.api.nvim_create_autocmd('Filetype', {
  pattern = 'tex',
  group = text,
  command = 'setlocal spell tw=80 colorcolumn=81',
})

-- Auto-resize splits when terminal window is resized
vim.api.nvim_create_autocmd('VimResized', {
  desc = 'Equalize splits on terminal resize',
  group = vim.api.nvim_create_augroup('auto-resize-splits', { clear = true }),
  command = 'wincmd =',
})

-- Trim trailing whitespace on save
vim.api.nvim_create_autocmd('BufWritePre', {
  desc = 'Remove trailing whitespace on save',
  group = vim.api.nvim_create_augroup('trim-whitespace', { clear = true }),
  callback = function()
    local pos = vim.api.nvim_win_get_cursor(0)
    vim.cmd [[%s/\s\+$//e]]
    vim.api.nvim_win_set_cursor(0, pos)
  end,
})
