return {
	-- Main LSP configuration
	{
		"neovim/nvim-lspconfig",
		dependencies = {
			{ "mason-org/mason.nvim", opts = {} },
			"mason-org/mason-lspconfig.nvim",
			"WhoIsSethDaniel/mason-tool-installer.nvim",
			{ "j-hui/fidget.nvim", opts = {} },
			{ "folke/neoconf.nvim", cmd = "Neoconf", config = true },
			{ "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
			-- "saghen/blink.cmp",
		},
		config = function()
			-- diagnostic config
			vim.diagnostic.config({
				underline = { severity = vim.diagnostic.severity.ERROR },
				update_in_insert = false,
				virtual_text = { spacing = 4, prefix = "●", source = true },
				severity_sort = true,
			})

			-- LSP servers
			local servers = {
				jsonls = {},
				bashls = {},
				ruff = { enable = true, init_options = { settings = { organizeImports = false, fixAll = false } } },
				ty = {
					enable = true,
					handlers = { ["textDocument/publishDiagnostics"] = function() end }
				},
				basedpyright = {
					enable = true,
					on_attach = function(client)
            client.server_capabilities.hoverProvider = false
            client.server_capabilities.completionProvider = false
            client.server_capabilities.signatureHelpProvider = false
            client.server_capabilities.definitionProvider = true
            client.server_capabilities.referencesProvider = false
            client.server_capabilities.documentHighlightProvider = false
            client.server_capabilities.documentSymbolProvider = false
            client.server_capabilities.codeActionProvider = false
            client.server_capabilities.codeLensProvider = false
            client.server_capabilities.documentFormattingProvider = false
            client.server_capabilities.documentRangeFormattingProvider = false
            client.server_capabilities.documentOnTypeFormattingProvider = false
            client.server_capabilities.declarationProvider = false
            client.server_capabilities.typeDefinitionProvider = false
            client.server_capabilities.implementationProvider = false
            client.server_capabilities.documentLinkProvider = false
            client.server_capabilities.colorProvider = false
            client.server_capabilities.foldingRangeProvider = false
            client.server_capabilities.selectionRangeProvider = false
            client.server_capabilities.semanticTokensProvider = false
            client.server_capabilities.inlayHintProvider = false
            client.server_capabilities.workspaceSymbolProvider = false
            client.server_capabilities.executeCommandProvider = false
            client.server_capabilities.renameProvider = true
					end,
					settings = {
						python = {
							analysis = {
								typeCheckingMode = "off",
								autoSearchPaths = true,
								useLibraryCodeForTypes = true,
								diagnosticMode = "off",
								autoImportCompletions = false,
							},
							linting = { enabled = false },
						},
					},
					handlers = { ["textDocument/publishDiagnostics"] = function() end },
				},
				yamlls = {
					settings = {
						yaml = {
							validate = true,
							hover = true,
							completion = true,
							format = { enable = true, singleQuote = false, bracketSpacing = true },
							schemaStore = { enable = false, url = "" },
							schemas = {
								["https://json.schemastore.org/github-workflow.json"] = "/.github/workflows/*",
								["https://json.schemastore.org/kustomization.json"] = "kustomization.{yml,yaml}",
							},
						},
					},
				},
				lua_ls = {
					settings = {
						Lua = {
							diagnostics = { globals = { "vim" } },
							workspace = {
								checkThirdParty = false,
								library = {
									[vim.fn.expand("$VIMRUNTIME/lua")] = true,
									[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
								},
							},
							completion = { callSnippet = "Replace" },
						},
					},
				},
			}

			-- cmp capabilities
			local capabilities =
				require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())
			capabilities.general = capabilities.general or {}
			capabilities.general.positionEncodings = { "utf-8", "utf-16" }

			for name, cfg in pairs(servers) do
				cfg.capabilities = capabilities
			end

			-- neoconf overrides
			local neoconf = require("neoconf")
			neoconf.setup()

			local project_servers = neoconf.get("lspconfig")
			if project_servers then
				for server_name, config in pairs(project_servers) do
					servers[server_name] = config
				end
			end

			-- register & enable LSPs using new 0.11 API
			for server_name, config in pairs(servers) do
				vim.lsp.config[server_name] = config
				if config.enable ~= false then
					vim.lsp.enable({ server_name })
				end
			end

			-- mason installer
			local mason_packages = {
				"json-lsp",
				"bash-language-server",
				"ruff",
				"ty",
				"basedpyright",
				"yaml-language-server",
				"lua-language-server",
				"stylua",
			}
			require("mason-tool-installer").setup({ ensure_installed = mason_packages })
		end,
	},

	-- nvim-cmp configuration
	{
		"hrsh7th/cmp-nvim-lsp",
		dependencies = {
			{ "hrsh7th/nvim-cmp" },
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "ray-x/cmp-treesitter" },
			{ "hrsh7th/cmp-cmdline" },
			{ "L3MON4D3/LuaSnip", version = "v2.*", build = "make install_jsregexp" },
			{ "hrsh7th/cmp-nvim-lua" },
			{ "saadparwaiz1/cmp_luasnip" },
			{ "rafamadriz/friendly-snippets" },
			{ "onsails/lspkind.nvim" },
		},
		config = function()
			local _, luasnip = pcall(require, "luasnip")
			local _, cmp = pcall(require, "cmp")
			local _, vscode_snippets = pcall(require, "luasnip.loaders.from_vscode")
			vscode_snippets.lazy_load()

			vim.o.completeopt = "menu,menuone,noinsert,noselect"
			vim.o.pumheight = 15

			local has_words_before = function()
				local line, col = unpack(vim.api.nvim_win_get_cursor(0))
				return col ~= 0
					and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
			end

			local tab_or_next = function(_)
				if cmp.visible() then
					cmp.select_next_item()
				else
					cmp.complete()
				end
			end
			local tab_or_prev = function(_)
				if cmp.visible() then
					cmp.select_prev_item()
				else
					cmp.complete()
				end
			end

			local super_tab = function(fallback)
				if cmp.visible() then
					cmp.select_next_item()
				elseif luasnip.expand_or_jumpable() then
					luasnip.expand_or_jump()
				elseif has_words_before() then
					cmp.complete()
				else
					fallback()
				end
			end

			local super_tab_shift = function(fallback)
				if cmp.visible() then
					cmp.select_prev_item()
				elseif luasnip.jumpable(-1) then
					luasnip.jump(-1)
				else
					fallback()
				end
			end

			local merge = function(a, b)
				return vim.tbl_deep_extend("force", {}, a, b)
			end

			local lspkind = require("lspkind")
			local ts_utils = require("nvim-treesitter.ts_utils")
			local source_mapping = {
				cody = "[Cody]",
				nvim_lsp = "[Lsp]",
				luasnip = "[Snip]",
				buffer = "[Buffer]",
				nvim_lua = "[Lua]",
				treesitter = "[Tree]",
				path = "[Path]",
				nvim_lsp_signature_help = "[Sig]",
			}

			cmp.setup({
				formatting = {
					format = lspkind.cmp_format({
						mode = "symbol_text",
						maxwidth = 40,
						before = function(entry, vim_item)
							vim_item.kind =
								string.format("%s %s", lspkind.presets.default[vim_item.kind], vim_item.kind)
							local menu = source_mapping[entry.source.name]
							vim_item.menu = menu
							vim_item.dup = 0
							return vim_item
						end,
					}),
				},
				snippet = {
					expand = function(args)
						luasnip.lsp_expand(args.body)
					end,
				},
				completion = { autocomplete = false },
				window = {
					completion = cmp.config.window.bordered(),
					documentation = merge(cmp.config.window.bordered(), { max_height = 15, max_width = 60 }),
				},
				mapping = {
					["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
					["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
					["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
					["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i" }),
					["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i" }),
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<NL>"] = cmp.mapping.confirm({ select = false }),
					["<Tab>"] = cmp.mapping({ i = super_tab, s = super_tab, c = tab_or_next }),
					["<S-Tab>"] = cmp.mapping({ i = super_tab_shift, s = super_tab_shift, c = tab_or_prev }),
				},
				experimental = { ghost_text = { hl_group = "LspCodeLens" } },
				enabled = function()
					return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt" or require("cmp_dap").is_dap_buffer()
				end,
				sources = cmp.config.sources({
					{
						name = "nvim_lsp",
						max_item_count = 15,
						entry_filter = function(entry, context)
							local kind = entry:get_kind()
							local node = ts_utils.get_node_at_cursor():type()
							local is_parent_class = (ts_utils.get_node_at_cursor():parent() ~= nil)
								and (ts_utils.get_node_at_cursor():parent():type() == "class_definition")

							if (node == "argument_list" or node == "ERROR") and context.filetype == "python" then
								local str = entry:get_word()
								local txt = string.sub(str, string.len(str))
								if kind == 6 and txt == "=" then
									return true
								elseif kind == 7 and is_parent_class then
									return true
								else
									return false
								end
							end
							return true
						end,
					},
					{ name = "luasnip", max_item_count = 5 },
					{ name = "treesitter", max_item_count = 5 },
					{ name = "buffer", max_item_count = 5 },
					{ name = "nvim_lua" },
					{ name = "path" },
					{ name = "cody", max_item_count = 2 },
				}),
			})

			cmp.setup.cmdline("/", { sources = { { name = "buffer" } } })
			cmp.setup.filetype(
				{ "dap-repl", "dapui_watches", "dapui_hover" },
				{ sources = { { name = "dap" }, { name = "path" } } }
			)
			cmp.setup.cmdline(":", { sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }) })
		end,
	},

	-- Lspsaga
	{
		"nvimdev/lspsaga.nvim",
		event = "BufRead",
		keys = {
			{ "gh", "<cmd>Lspsaga finder<CR>", desc = "LSP Finder" },
			{ "<leader>ca", "<cmd>Lspsaga code_action<CR>", mode = { "n", "v" }, desc = "[C]ode [A]ction" },
			{ "grr", "<cmd>Lspsaga rename<CR>", desc = "[R]ename in file" },
			{ "grp", "<cmd>Lspsaga rename ++project<CR>", desc = "[R]ename in [P]roject" },
			{ "gdp", "<cmd>Lspsaga peek_definition<CR>", desc = "[D]efinition [P]eek" },
			{ "gdd", "<cmd>Lspsaga goto_definition<CR>", desc = "[D]efinition Go" },
			{ "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>", desc = "[S]how [L]ine diagnostics" },
			{ "<leader>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>", desc = "[S]how [C]ursor diagnostics" },
			{ "<leader>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>", desc = "[S]how [B]uffer diagnostics" },
			{ "[e", "<cmd>Lspsaga diagnostic_jump_prev<CR>", desc = "Go to Diagnostic Previous" },
			{ "]e", "<cmd>Lspsaga diagnostic_jump_next<CR>", desc = "Go to Diagnostic Next" },
			{
				"[E",
				function()
					require("lspsaga.diagnostic"):goto_prev({ severity = vim.diagnostic.severity.ERROR })
				end,
				desc = "Go to Diagnostic Error Previous",
			},
			{
				"]E",
				function()
					require("lspsaga.diagnostic"):goto_next({ severity = vim.diagnostic.severity.ERROR })
				end,
				desc = "Go to Diagnostic Error Next",
			},
			{ "<leader>o", "<cmd>Lspsaga outline<CR>", desc = "[O]utline right bar" },
			{ "KD", "<cmd>Lspsaga hover_doc<CR>", desc = "Show Doc Hover" },
			{ "KK", "<cmd>Lspsaga hover_doc ++keep<CR>", desc = "Show doc Keep" },
			{ "<Leader>ci", "<cmd>Lspsaga incoming_calls<CR>", desc = "[C]ode Calls [I]ncoming" },
			{ "<Leader>co", "<cmd>Lspsaga outgoing_calls<CR>", desc = "[C]ode Calls [O]utgoing" },
			{ "<M-d>", "<cmd>Lspsaga term_toggle<CR>", mode = { "n", "t" }, desc = "Show Terminal" },
		},
		config = function()
			require("lspsaga").setup({
				scroll_preview = { scroll_down = "<C-d>", scroll_up = "<C-u>" },
				definition = {
					edit = "<C-c>o",
					vsplit = "<C-c>v",
					split = "<C-c>i",
					tabe = "<C-c>t",
					quit = "q",
					close = "<Esc>",
				},
			})
		end,
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
	},

	-- Trouble
	{
		"folke/trouble.nvim",
		cmd = { "TroubleToggle", "Trouble" },
		opts = { use_diagnostic_signs = true },
		keys = {
			{ "<leader>sd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics (Trouble)" },
			{ "<leader>sw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics (Trouble)" },
		},
	},

	-- conform
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = { "ruff_fix", "ruff_format", "ruff_organize_imports" },
				yaml = { "prettier" },
				typescript = { "prettier" },
				json = { "prettier" },
			},
		},
		keys = { { "<leader>f", ':lua require("conform").format({async=true})<cr>', desc = "Format" } },
	},

	-- lsp_signature
	{
		"ray-x/lsp_signature.nvim",
		config = function()
			require("lsp_signature").setup({
				timer_interval = 20,
				bind = true,
				hint_prefix = "",
				extra_trigger_chars = { "=", "," },
			})
		end,
	},

	-- optional
	{ "nvim-treesitter/playground" },
	{
		"benomahony/uv.nvim",
		config = function()
			require("uv").setup({ keymaps = { prefix = "<leader>U" } })
		end,
	},
	{
		"pmizio/typescript-tools.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {},
	},
}
