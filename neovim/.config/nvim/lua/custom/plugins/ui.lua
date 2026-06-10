return {
	{
		"Mofiqul/vscode.nvim",
		lazy = false, -- load at start
		priority = 1000, -- load first
		opts = {
			-- Enables transparent background
			transparent = true,

			-- Enables italic comment formatting
			italic_comments = true,

			-- Enables underline for links
			underline_links = true,

			-- Disables background colors for file explorers
			disable_nvimtree_bg = true,
		},
		config = function(_, opts)
			-- 1. Setup the theme options first
			require("vscode").setup(opts)
			-- 2. Execute the colorscheme command
			vim.cmd("colorscheme vscode")
		end,
	},

	-- Highlight todo, notes, etc in comments
	{
		"folke/todo-comments.nvim",
		event = "VimEnter",
		dependencies = { "nvim-lua/plenary.nvim" },
		---@module 'todo-comments'
		---@type TodoOptions
		---@diagnostic disable-next-line: missing-fields
		opts = { signs = false },
	},

	{ -- Collection of various small independent plugins/modules
		"nvim-mini/mini.nvim",
		config = function()
			-- Better Around/Inside textobjects
			require("mini.ai").setup({ n_lines = 500 })

			-- Add/delete/replace surroundings
			require("mini.surround").setup()

			-- Auto-pairs (replaces nvim-autopairs; same plugin family)
			require("mini.pairs").setup()

			-- Statusline (replaces Lightline; same plugin family as the rest)
			require("mini.statusline").setup({ use_icons = vim.g.have_nerd_font })

			-- VS Code Statusline Overrides
			-- Mode Indicators
			vim.api.nvim_set_hl(0, "MiniStatuslineModeNormal", { fg = "#ffffff", bg = "#007acc", bold = true }) -- VS Code Blue
			vim.api.nvim_set_hl(0, "MiniStatuslineModeInsert", { fg = "#ffffff", bg = "#cc6633", bold = true }) -- VS Code Orange
			vim.api.nvim_set_hl(0, "MiniStatuslineModeVisual", { fg = "#ffffff", bg = "#68217a", bold = true }) -- VS Code Purple
			vim.api.nvim_set_hl(0, "MiniStatuslineModeReplace", { fg = "#ffffff", bg = "#c586c0", bold = true })
			vim.api.nvim_set_hl(0, "MiniStatuslineModeCommand", { fg = "#ffffff", bg = "#007acc", bold = true })

			-- Base Sections
			vim.api.nvim_set_hl(0, "MiniStatuslineDevinfo", { fg = "#cccccc", bg = "#2d2d2d" })
			vim.api.nvim_set_hl(0, "MiniStatuslineFilename", { fg = "#ffffff", bg = "#1e1e1e" }) -- Main editor background
			vim.api.nvim_set_hl(0, "MiniStatuslineFileinfo", { fg = "#cccccc", bg = "#2d2d2d" })
			vim.api.nvim_set_hl(0, "MiniStatuslineInactive", { fg = "#858585", bg = "#1e1e1e" })
		end,
	},
}
