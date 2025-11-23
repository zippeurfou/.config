-- LSP and Completion Configuration
-- Uses blink.cmp with lspkind.nvim for VSCode-style icons

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
					on_attach = function(client, _)
						client.server_capabilities.definitionProvider = false
					end,
					handlers = { ["textDocument/publishDiagnostics"] = function() end },
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

			-- blink.cmp capabilities
			local capabilities = require("blink.cmp").get_lsp_capabilities()
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

	-- blink.cmp with lspkind.nvim for VSCode-style icons
	{
		"saghen/blink.cmp",
		version = "1.*",
		dependencies = {
			-- Snippet support
			{ "rafamadriz/friendly-snippets" },

			-- DAP REPL completion support
			{ "saghen/blink.compat", version = "*", opts = {} },
			{ "rcarriga/cmp-dap" },

			-- lspkind for VSCode-style icons
			{ "onsails/lspkind.nvim" },

			-- devicons for file-type icons in path completions
			{ "nvim-tree/nvim-web-devicons" },
		},

		opts = {
			keymap = {
				preset = "none",

				-- Keybindings
				["<C-Space>"] = { "show", "hide" },
				["<C-e>"] = { "hide" },
				-- ["<CR>"] = { "accept", "fallback" },
				-- Allow to keep showing completion menu when accepting a path ending with /
				["<CR>"] = {
					function(cmp)
						local item = cmp.get_selected_item()
						-- Only auto-show if it's from path source AND ends with /
						if item and item.source_name:lower() == "path" and item.label:match("/$") then
							cmp.accept()
							-- Small delay to let accept complete before showing again
							vim.defer_fn(function()
								cmp.show()
							end, 50) -- 50ms should be safe
							return true
						else
							return cmp.accept()
						end
					end,
					"fallback",
				},
				["<C-p>"] = { "select_prev", "fallback" },
				["<C-n>"] = { "select_next", "fallback" },

				["<C-u>"] = { "scroll_documentation_up", "fallback" },
				["<C-d>"] = { "scroll_documentation_down", "fallback" },

				-- Tab behavior: Smart tab that checks context
				["<Tab>"] = {
					function(cmp)
						-- Helper function to check if cursor is after a word
						local function has_words_before()
							local line, col = unpack(vim.api.nvim_win_get_cursor(0))
							return col ~= 0
								and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s")
									== nil
						end

						if cmp.snippet_active() then
							return cmp.snippet_forward()
						elseif cmp.is_visible() then
							return cmp.select_next()
						elseif has_words_before() then
							return cmp.show() -- Only show if after a word
						else
							return false -- Let Tab insert normally (fallback)
						end
					end,
					"fallback",
				},
				["<S-Tab>"] = {
					function(cmp)
						if cmp.snippet_active() then
							return cmp.snippet_backward()
						elseif cmp.is_visible() then
							return cmp.select_prev()
						else
							return false -- Fallback to default S-Tab behavior
						end
					end,
					"fallback",
				},
			},

			completion = {
				trigger = {
					show_on_insert_on_trigger_character = false,
					show_in_snippet = false,
					show_on_keyword = false, -- CRITICAL: Prevents auto-show while typing
					show_on_trigger_character = false,
				},

				menu = {
					border = "rounded",
					max_height = 15,

					-- Visual layout with lspkind icons
					draw = {
						columns = {
							{ "label", "label_description", gap = 1 },
							{ "kind_icon", "kind", gap = 1 },
							{ "source_name" },
						},
						components = {
							kind_icon = {
								ellipsis = false,
								text = function(ctx)
									local icon = ctx.kind_icon
									-- Use devicons for Path source, lspkind for everything else
									if ctx.source_name and ctx.source_name:lower() == "path" then
										local dev_icon, _ = require("nvim-web-devicons").get_icon(ctx.label)
										if dev_icon then
											icon = dev_icon
										end
									else
										-- Use lspkind icons for LSP/Snippet/Buffer
										icon = require("lspkind").symbolic(ctx.kind, {
											mode = "symbol",
										})
									end
									return icon .. ctx.icon_gap
								end,
								-- Use devicon highlights for Path, colorscheme highlights for others
								highlight = function(ctx)
									local hl = ctx.kind_hl
									if ctx.source_name and ctx.source_name:lower() == "path" then
										local _, dev_hl = require("nvim-web-devicons").get_icon(ctx.label)
										if dev_hl then
											hl = dev_hl
										end
									end
									return hl
								end,
							},
							kind = {
								ellipsis = false,
								width = { fill = true },
								text = function(ctx)
									return ctx.kind
								end,
								-- Automatic highlight from colorscheme
								highlight = function(ctx)
									return ctx.kind_hl
								end,
							},
							source_name = {
								text = function(ctx)
									-- Source name mapping
									local map = {
										lsp = "[LSP]",
										path = "[Path]",
										snippets = "[Snip]",
										buffer = "[Buf]",
										copilot = "[AI]",
									}
									return map[ctx.source_name] or "[" .. ctx.source_name .. "]"
								end,
								highlight = "Comment",
							},
							label_description = {
								text = function(ctx)
									-- Hide label_description
									return ""
								end,
							},
						},
					},
				},

				documentation = {
					auto_show = true,
					auto_show_delay_ms = 200,
					window = {
						border = "rounded",
						max_height = 15,
						max_width = 60,
					},
				},

				ghost_text = {
					enabled = false, -- Disabled - using copilot.vim for inline suggestions
				},
			},

			sources = {
				default = { "lsp", "path", "snippets", "buffer" },

				-- Enable DAP completion only in DAP buffers
				per_filetype = {
					["dap-repl"] = { "dap", "path" },
					dapui_watches = { "dap", "path" },
					dapui_hover = { "dap", "path" },
				},

				providers = {
					lsp = {
						max_items = 15,
					},
					buffer = {
						max_items = 5,
					},
					snippets = {
						max_items = 5,
					},
					-- DAP completion via blink.compat bridge to cmp-dap
					dap = {
						name = "dap",
						module = "blink.compat.source",
						enabled = function()
							return vim.bo.filetype == "dap-repl"
								or vim.bo.filetype == "dapui_watches"
								or vim.bo.filetype == "dapui_hover"
						end,
					},
				},
			},
			snippets = {
				preset = "default",
			},

			-- Cmdline completion
			cmdline = {
				enabled = true,

				-- Completion behavior for cmdline
				completion = {
					trigger = {
						show_on_keyword = false, -- Don't auto-show while typing
					},
					list = {
						selection = {
							preselect = false, -- Don't auto-select first item
							auto_insert = false, -- Don't auto-insert while navigating
						},
					},
					menu = {
						auto_show = false, -- Don't auto-show menu
					},
				},

				-- Keymap for cmdline (different from file editing)
				keymap = {
					preset = "none",
					["<Tab>"] = { "show", "select_next", "fallback" },
					["<S-Tab>"] = { "select_prev", "fallback" },
					-- ["<CR>"] = { "accept", "fallback" }, -- Accept but don't execute
					-- Allow to keep showing when it finish with /
					["<CR>"] = {
						function(cmp)
							local item = cmp.get_selected_item()
							if item and item.label and item.label:match("/$") then
								cmp.accept()
								-- Small delay to let accept complete before showing again
								vim.defer_fn(function()
									cmp.show()
								end, 50) -- 50ms should be safe
								return true
							else
								return cmp.accept()
							end
						end,
						"fallback",
					},
					["<C-e>"] = { "hide", "fallback" },
				},

				-- Sources for different cmdline modes
				sources = function()
					local type = vim.fn.getcmdtype()
					if type == "/" or type == "?" then
						return { "buffer" }
					end
					if type == ":" then
						return { "cmdline", "path" }
					end
					return {}
				end,
			},
		},

		config = function(_, opts)
			require("blink.cmp").setup(opts)
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
		event = "LspAttach",
		config = function()
			require("lsp_signature").setup({
				timer_interval = 20,
				bind = true,
				hint_prefix = "",
				extra_trigger_chars = { "=", "," },
			})
		end,
	},

	-- optional plugins
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
