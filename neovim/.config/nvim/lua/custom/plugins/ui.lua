return {
  {
    'Mofiqul/adwaita.nvim',
    lazy = false, -- load at start
    priority = 1000, -- load first
    config = function()
      vim.g.adwaita_darker = true
      vim.cmd [[colorscheme adwaita]]
    end,
  },

  -- Highlight todo, notes, etc in comments
  {
    'folke/todo-comments.nvim',
    event = 'VimEnter',
    dependencies = { 'nvim-lua/plenary.nvim' },
    ---@module 'todo-comments'
    ---@type TodoOptions
    ---@diagnostic disable-next-line: missing-fields
    opts = { signs = false },
  },

  { -- Collection of various small independent plugins/modules
    'nvim-mini/mini.nvim',
    config = function()
      -- Better Around/Inside textobjects
      require('mini.ai').setup { n_lines = 500 }

      -- Add/delete/replace surroundings
      require('mini.surround').setup()

      -- Auto-pairs (replaces nvim-autopairs; same plugin family)
      require('mini.pairs').setup()

      -- Statusline (replaces lightline; same plugin family as the rest)
      require('mini.statusline').setup { use_icons = vim.g.have_nerd_font }
    end,
  },
}
