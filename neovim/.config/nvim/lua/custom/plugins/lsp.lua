return {
  {
    -- Main LSP Configuration
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'mason-org/mason.nvim', opts = {} },
      'mason-org/mason-lspconfig.nvim',
      'WhoIsSethDaniel/mason-tool-installer.nvim',
      { 'j-hui/fidget.nvim', opts = {} },
      'saghen/blink.cmp',
    },
    config = function()
      vim.api.nvim_create_autocmd('LspAttach', {
        group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
        callback = function(event)
          local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
          end

          map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
          map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
          map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

          local client = vim.lsp.get_client_by_id(event.data.client_id)
          if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
              buffer = event.buf,
              group = highlight_augroup,
              callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
              group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
              callback = function(event2)
                vim.lsp.buf.clear_references()
                vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
              end,
            })
          end

          if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function() vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }) end, '[T]oggle Inlay [H]ints')
          end
        end,
      })

      -- Configure diagnostics (Neovim 0.11+ way)
      vim.diagnostic.config {
        signs = {
          text = {
            [vim.diagnostic.severity.ERROR] = ' ',
            [vim.diagnostic.severity.WARN] = ' ',
            [vim.diagnostic.severity.HINT] = '󰠠',
            [vim.diagnostic.severity.INFO] = ' ',
          },
        },
        virtual_text = {
          prefix = '●',
          spacing = 4,
        },
        underline = true,
        update_in_insert = false,
        severity_sort = true,
      }

      -- Set global capabilities for all servers (Neovim 0.11+)
      vim.lsp.config('*', {
        capabilities = require('blink.cmp').get_lsp_capabilities(),
      })

      -- Active LSP servers, scoped to the languages I currently work in:
      -- python, shell, markdown, html, toml, css.
      -- Servers I previously had enabled are kept below in commented blocks
      -- so they can be re-enabled by just uncommenting (and adding the name
      -- back to the `servers` table). See "Disabled servers" further down.
      local servers = {
        pyright = {},   -- python
        ruff = {},      -- python (linter/formatter LSP)
        bashls = {},    -- shell
        marksman = {},  -- markdown
        html = {},      -- html
        cssls = {},     -- css
        taplo = {},     -- toml
      }

      -- ─────────────────────────────────────────────────────────────────
      -- Disabled servers — uncomment the entry and add it to `servers` to
      -- re-enable. Mason will install on next `:Lazy sync`/`:Mason`.
      -- ─────────────────────────────────────────────────────────────────
      --
      -- lua_ls — Lua. Useful when editing this Neovim config itself.
      --   Re-enable if you start hacking on plugins / writing Lua again.
      -- local lua_ls = {
      --   on_init = function(client)
      --     if client.workspace_folders then
      --       local path = client.workspace_folders[1].name
      --       if path ~= vim.fn.stdpath 'config' and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc')) then return end
      --     end
      --     client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
      --       runtime = { version = 'LuaJIT', path = { 'lua/?.lua', 'lua/?/init.lua' } },
      --       workspace = {
      --         checkThirdParty = false,
      --         library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
      --           '${3rd}/luv/library', '${3rd}/busted/library',
      --         }),
      --       },
      --     })
      --   end,
      --   settings = { Lua = {} },
      -- }
      --
      -- yamlls = {},   -- YAML
      -- jsonls = {},   -- JSON
      --
      -- clangd — C/C++.
      -- local clangd = {
      --   root_markers = { '.git', 'compile_commands.json', 'compile_flags.txt', '.' },
      -- }
      --
      -- jdtls — Java.
      -- local jdtls = {
      --   root_markers = { '.git', 'pom.xml', 'build.gradle', '.' },
      --   cmd = {
      --     'jdtls', '-data',
      --     vim.fn.stdpath 'cache' .. '/jdtls-workspace/' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':p:h:t'),
      --   },
      --   settings = {
      --     java = {
      --       signatureHelp = { enabled = true },
      --       contentProvider = { preferred = 'fernflower' },
      --       completion = {
      --         favoriteStaticMembers = {
      --           'org.junit.Assert.*', 'org.junit.Assume.*',
      --           'org.junit.Juipter.api.Assertions.*',
      --           'org.junit.Juipter.api.Assumptions.*',
      --           'org.junit.Juipter.api.DynamicTest.*',
      --           'org.junit.Juipter.api.DynamicContainer.*',
      --           'org.mockito.Mockito.*', 'org.mockito.ArgumentMatchers.*',
      --           'org.mockito.Answers.*',
      --         },
      --       },
      --       sources = { organizeImports = { starThreshold = 9999, staticStarThreshold = 9999 } },
      --     },
      --   },
      -- }

      -- Mason-managed tools (formatters/linters). Conform formats these even
      -- when the matching LSP is disabled — keep them installed so format-on-save
      -- doesn't silently no-op.
      local tools = {
        'shellcheck',          -- shell
        'shfmt',               -- shell
        'prettier',            -- html / css / markdown / yaml
        'jq',                  -- json formatter
        'stylua',              -- lua (this config itself)
        'clang-format',        -- c / c++
        'google-java-format',  -- java
      }

      local ensure_installed = vim.tbl_keys(servers or {})
      vim.list_extend(ensure_installed, tools)
      require('mason-tool-installer').setup { ensure_installed = ensure_installed }

      for name, server in pairs(servers) do
        vim.lsp.config(name, server)
        vim.lsp.enable(name)
      end
    end,
  },
}
