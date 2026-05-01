---@module 'lazy'
---@type LazySpec
return {
  'luukvbaal/nnn.nvim',
  lazy = false,
  keys = {
    { '<leader>e', '<cmd>NnnPicker<CR>', desc = 'NNN Picker (floating)' },
  },
  config = function()
    local builtin = require('nnn').builtin
    require('nnn').setup {
      picker = {
        cmd = 'nnn',
        style = { border = 'rounded' },
      },
      mappings = {
        { '<C-t>', builtin.open_in_tab },
        { '<C-s>', builtin.open_in_split },
        { '<C-v>', builtin.open_in_vsplit },
      },
      replace_netrw = 'picker',
    }
  end,
}
