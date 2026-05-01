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
				sh = { "shfmt" },
				bash = { "shfmt" },
				c = { "clang-format" },
				cpp = { "clang-format" },
				java = { "google-java-format" },
				zsh = { "shfmt", "shellcheck" },
				json = { "jq" },
				yaml = { "prettier" },
				markdown = { "prettier" },
			},
		},
	},
}
