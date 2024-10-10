return {
	-- lspconfig
	{
		"neovim/nvim-lspconfig",
		event = "BufReadPre",
		dependencies = {
			{ "folke/neoconf.nvim", cmd = "Neoconf", config = true },
			{ "folke/neodev.nvim", opts = { experimental = { pathStrict = true } } },
			"mason.nvim",
			"williamboman/mason-lspconfig.nvim",
			"hrsh7th/cmp-nvim-lsp",
		},
		---@class PluginLspOpts
		opts = {
			-- options for vim.diagnostic.config()
			diagnostics = {
				underline = true,
				update_in_insert = false,
				virtual_text = { spacing = 4, prefix = "●" },
				severity_sort = true,
			},
			-- Automatically format on save
			autoformat = true,
			-- options for vim.lsp.buf.format
			-- `bufnr` and `filter` is handled by the LazyVim formatter,
			-- but can be also overriden when specified
			format = {
				formatting_options = nil,
				timeout_ms = nil,
			},
			servers = {
				jsonls = {},
				bashls = {},
				pyright = {
					settings = {
						python = {
							analysis = {
								autoSearchPaths = true,
								-- diagnosticMode = "workspace",
								diagnosticMode = "openFilesOnly",
								useLibraryCodeForTypes = true,
								autoImportCompletions = true,
								typeCheckingMode = "basic",
								stubPath = "",
								inlayHints = {
									variableTypes = true,
									functionReturnTypes = true,
								},
								-- diagnosticSeverityOverrides = {
								--   reportMissingTypeStubs = "none",
								--   reportUnusedExpression = "information",
								--   reportPrivateUsage = "warning",
								--   reportUnknownMemberType = "none",
								-- },
							},
						},
					},
				},
				-- ruff_lsp = {},
				-- pylsp = {
				--   settings = {
				--     pylsp = {
				--       plugins = {
				--         -- pylint = { enabled = true, executable = "pylint" },
				--         autopep8 = { enabled = false},
				--         pyflakes = { enabled = false },
				--         pycodestyle = { enabled = false },
				--         jedi_completion = { enabled= false, fuzzy = false },
				--         -- pylsp_isort = { enabled = true },
				--         pylsp_mypy = { enabled = true,live_mode = true },
				--         pyls_memestra = {enabled = false},
				--         -- mypy = { enabled = false },
				--         ruff = {enabled = true, lineLength=100,  cache_config = false,},
				--         black = {enabled = true, line_length=100, cache_config = false,},
				--         rope_autoimport = {enabled = true},
				--         rope_completion = { enabled = true },
				--         rope = {enabled = true},
				--         lsp_rope = {enabled = true},
				--         pydocstyle = {enabled = false},
				--       },
				--     },
				--   },
				-- },
				lua_ls = {
					settings = {
						Lua = {
							diagnostics = {
								-- Get the language server to recognize the `vim` global
								globals = { "vim" },
							},
							workspace = {
								checkThirdParty = false,
								library = {
									[vim.fn.expand("$VIMRUNTIME/lua")] = true,
									[vim.fn.expand("$VIMRUNTIME/lua/vim/lsp")] = true,
								},
							},
							completion = {
								callSnippet = "Replace",
							},
						},
					},
				},
			},
			-- you can do any additional lsp server setup here
			-- return true if you don't want this server to be setup with lspconfig
			---@type table<string, fun(server:string, opts:_.lspconfig.options):boolean?>
			setup = {
				-- example to setup with typescript.nvim
				-- tsserver = function(_, opts)
				--   require("typescript").setup({ server = opts })
				--   return true
				-- end,
				-- Specify * to use this function as a fallback for any server
				-- ["*"] = function(server, opts) end,
			},
		},
		---@param opts PluginLspOpts
		config = function(plugin, opts)
			-- setup autoformat
			-- require("lazyvim.plugins.lsp.format").autoformat = opts.autoformat

			-- setup formatting and keymaps
			-- require("lazyvim.util").on_attach(function(client, buffer)
			--   require("lazyvim.plugins.lsp.format").on_attach(client, buffer)
			--   require("lazyvim.plugins.lsp.keymaps").on_attach(client, buffer)
			-- end)

			-- diagnostics
			-- for name, icon in pairs(require("lazyvim.config").icons.diagnostics) do
			--   name = "DiagnosticSign" .. name
			--   vim.fn.sign_define(name, { text = icon, texthl = name, numhl = "" })
			-- end
			-- vim.diagnostic.config(opts.diagnostics)

			local servers = opts.servers
			local capabilities =
				require("cmp_nvim_lsp").default_capabilities(vim.lsp.protocol.make_client_capabilities())

			require("mason-lspconfig").setup({ ensure_installed = vim.tbl_keys(servers) })
			require("mason-lspconfig").setup_handlers({
				function(server)
					local server_opts = servers[server] or {}
					server_opts.capabilities = capabilities
					if opts.setup[server] then
						if opts.setup[server](server, server_opts) then
							return
						end
					elseif opts.setup["*"] then
						if opts.setup["*"](server, server_opts) then
							return
						end
					end
					require("lspconfig")[server].setup(server_opts)
				end,
			})
			-- require('lspconfig').pyright.setup()
		end,
	},
	-- formatters
	-- {
	--   "jose-elias-alvarez/null-ls.nvim",
	--   event = "BufReadPre",
	--   keys = { { "<leader>f", ":lua vim.lsp.buf.format { async = true }<cr>", desc = "Format" } },
	--   dependencies = { "mason.nvim" },
	--   opts = function()
	--     local nls = require("null-ls")
	--     return {
	--       sources = {
	--         -- nls.builtins.formatting.prettierd,
	--         -- nls.builtins.formatting.stylua,
	--         nls.builtins.formatting.black,
	--         -- nls.builtins.formatting.shfmt,
	--         -- nls.builtins.formatting.ruff,
	--         -- nls.builtins.diagnostics.ruff,
	--         -- nls.builtins.diagnostics.flake8,
	--       },
	--     }
	--   end,
	-- },
	{
		"stevearc/conform.nvim",
		opts = {
			formatters_by_ft = {
				lua = { "stylua" },
				python = {
					'ruff_fix', -- To fix lint errors. (ruff with argument --fix)
					"ruff_format", -- To run the formatter. (ruff with argument format)
          "ruff_organize_imports", --organize import
				},
			},
		},
		keys = { { "<leader>f", ':lua require("conform").format({async=true})<cr>', desc = "Format" } },
	},

	-- cmdline tools and lsp servers
	{

		"williamboman/mason.nvim",
		cmd = "Mason",
		keys = { { "<leader>cm", "<cmd>Mason<cr>", desc = "Mason" } },
		opts = {
			ensure_installed = {
				"stylua",
				"shellcheck",
				"shfmt",
				"black",
				"ruff",
				"pyright",
				-- "python-lsp-server",
				-- "ruff-lsp"
			},
		},
		---@param opts MasonSettings | {ensure_installed: string[]}
		config = function(plugin, opts)
			require("mason").setup(opts)
			local mr = require("mason-registry")
			for _, tool in ipairs(opts.ensure_installed) do
				local p = mr.get_package(tool)
				if not p:is_installed() then
					p:install()
				end
			end

			-- vim.lsp.handlers['textDocument/signatureHelp'] = vim.lsp.with(
			--   vim.lsp.handlers.signature_help, {
			--     border = 'rounded',
			--     close_events = {"CursorMoved", "BufHidden", "InsertCharPre"},
			--   }
			-- )
		end,
	},
	{
		"hrsh7th/nvim-cmp",
		config = function()
			local luasnip_ok, luasnip = pcall(require, "luasnip")
			local cmp_ok, cmp = pcall(require, "cmp")
			local vscode_snippets_ok, vscode_snippets = pcall(require, "luasnip.loaders.from_vscode")

			vscode_snippets.lazy_load()

			-- Set completeopt to have a better completion experience
			vim.o.completeopt = "menu,menuone,noinsert,noselect"
			vim.o.pumheight = 15

			-- Setup nvim-cmp.
			local check_backspace = function()
				local col = vim.fn.col(".") - 1
				return col == 0 or vim.fn.getline("."):sub(col, col):match("%s")
			end

			local has_words_before = function()
				local line, col = unpack(vim.api.nvim_win_get_cursor(0))
				return col ~= 0
					and vim.api.nvim_buf_get_lines(0, line - 1, line, true)[1]:sub(col, col):match("%s") == nil
			end

			local function handle_tab(fallback)
				if cmp.visible() then
					cmp.select_next_item()
				elseif luasnip.expandable() then
					luasnip.expand()
				elseif luasnip.expand_or_jumpable() then
					luasnip.expand_or_jump()
				elseif check_backspace() then
					fallback()
				else
					return false
				end
				return true
			end

			local function handle_tab_command(fallback)
				if not handle_tab(fallback) then
					cmp.complete()
				end
			end

			local function handle_tab_insert(fallback)
				if not handle_tab(fallback) then
					fallback()
				end
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
						-- preset = 'codicons',

						before = function(entry, vim_item)
							-- vim_item.kind = lspkind.presets.default[vim_item.kind]
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
					-- REQUIRED - you must specify a snippet engine
					expand = function(args)
						luasnip.lsp_expand(args.body) -- For `luasnip` users.
					end,
				},
				completion = { autocomplete = false },
				window = {
					completion = cmp.config.window.bordered(),
					documentation = merge(cmp.config.window.bordered(), {
						max_height = 15,
						max_width = 60,
						-- border="double"
					}),
				},
				mapping = {
					["<C-u>"] = cmp.mapping(cmp.mapping.scroll_docs(-4), { "i", "c" }),
					["<C-d>"] = cmp.mapping(cmp.mapping.scroll_docs(4), { "i", "c" }),
					["<C-Space>"] = cmp.mapping(cmp.mapping.complete(), { "i", "c" }),
					["<C-p>"] = cmp.mapping(cmp.mapping.select_prev_item(), { "i" }),
					["<C-n>"] = cmp.mapping(cmp.mapping.select_next_item(), { "i" }),
					-- ['<C-e>'] = cmp.mapping.close(),
					-- ['<C-e>'] = cmp.config.disable,
					["<C-e>"] = cmp.mapping.abort(),
					["<CR>"] = cmp.mapping.confirm({ select = true }),
					["<NL>"] = cmp.mapping.confirm({ select = false }),
					["<Tab>"] = cmp.mapping({
						i = super_tab,
						s = super_tab,
						c = tab_or_next,
					}),
					["<S-Tab>"] = cmp.mapping({
						i = super_tab_shift,
						s = super_tab_shift,
						c = tab_or_prev,
					}),
				},
				experimental = {
					ghost_text = {
						hl_group = "LspCodeLens",
					},
				},
				enabled = function()
					return vim.api.nvim_buf_get_option(0, "buftype") ~= "prompt" or require("cmp_dap").is_dap_buffer()
				end,
				sources = cmp.config.sources({
					-- { name = "cody", max_item_count = 5 },
					{
						name = "nvim_lsp",
						max_item_count = 15,
						entry_filter = function(entry, context)
							-- local log = function(message)
							--   local log_file_path = './debug.txt'
							--   local log_file = io.open(log_file_path, "a")
							--   io.output(log_file)
							--   io.write(message.."\n")
							--   io.close(log_file)
							-- end
							local kind = entry:get_kind()
							local node = ts_utils.get_node_at_cursor():type()
							local is_parent_class = (ts_utils.get_node_at_cursor():parent() ~= nil)
								and (ts_utils.get_node_at_cursor():parent():type() == "class_definition")
							-- if node == "ERROR" and kind == 6 then
							-- log("Got an issue")
							-- log('END')
							-- end
							if (node == "argument_list" or node == "ERROR") and context.filetype == "python" then
								local str = entry:get_word()
								local txt = string.sub(str, string.len(str))
								-- 6 == "Variable"
								-- if we have a variable and it finish with = we show it
								if kind == 6 and txt == "=" then
									return true
								-- 7 == "Class"
								-- if we have an error
								elseif kind == 7 and is_parent_class then
									return true
								else
									return false
								end
							end
							return true
						end,
					},
					-- { name = "nvim_lsp_signature_help", max_item_count = 5 },
					{ name = "luasnip", max_item_count = 5 },
					{ name = "treesitter", max_item_count = 5 },
					{ name = "buffer", max_item_count = 5 },
					{ name = "nvim_lua" },
					{ name = "path" },
					{ name = "cody", max_item_count = 2 },
					-- { name = 'nvim_lsp' },
					-- { name = 'luasnip' }, -- For luasnip users.
					-- { name = "buffer" },
					-- { name = "path" },
				}),
			})

			-- Use buffer source for `/`.
			cmp.setup.cmdline("/", {
				sources = {
					{ name = "buffer" },
				},
			})
			-- Add cmp completion
			cmp.setup.filetype({ "dap-repl", "dapui_watches", "dapui_hover" }, {
				sources = {
					{ name = "dap" },
					{ name = "path" },
				},
			})

			-- Use cmdline & path source for ':'.
			cmp.setup.cmdline(":", {
				sources = cmp.config.sources({
					{ name = "path" },
				}, {
					{ name = "cmdline" },
				}),
			})
		end,
		dependencies = {
			{ "hrsh7th/nvim-cmp" },
			{ "hrsh7th/cmp-nvim-lsp" },
			{ "hrsh7th/cmp-buffer" },
			{ "hrsh7th/cmp-path" },
			{ "ray-x/cmp-treesitter" },
			{ "hrsh7th/cmp-cmdline" },
			{ "L3MON4D3/LuaSnip" },
			{ "hrsh7th/cmp-nvim-lua" },
			{ "saadparwaiz1/cmp_luasnip" },
			{ "rafamadriz/friendly-snippets" },
			-- {"hrsh7th/cmp-nvim-lsp-signature-help"},
			{ "onsails/lspkind.nvim" },
		},
	},
	{
		"nvimdev/lspsaga.nvim",
		event = "BufRead",
		keys = {
			{ "gh", "<cmd>Lspsaga finder<CR>", desc = "LSP Finder" },
			-- Code action
			{
				"<leader>ca",
				"<cmd>Lspsaga code_action<CR>",
				mode = { "n", "v" },
				desc = "[C]ode [A]ction",
			},
			-- Rename
			{ "grr", "<cmd>Lspsaga rename<CR>", desc = "[R]ename in file" },
			-- Rename word in whole project
			{ "grp", "<cmd>Lspsaga rename ++project<CR>", desc = "[R]ename in [P]roject" },
			-- Peek Definition
			-- you can edit the definition file in this float window
			-- also support open/vsplit/etc operation check definition_action_keys
			-- support tagstack C-t jump back
			{ "gdp", "<cmd>Lspsaga peek_definition<CR>", desc = "[D]definition [P]eek" },
			-- Go to Definition
			{ "gdd", "<cmd>Lspsaga goto_definition<CR>", desc = "[D]efinition Go" },
			-- Show line diagnostics you can pass argument ++unfocus to make
			-- show_line_diagnostics float window unfocus
			{ "<leader>sl", "<cmd>Lspsaga show_line_diagnostics<CR>", desc = "[S]how [L]ine diagnostics" },
			-- Show cursor diagnostic
			-- also like show_line_diagnostics  support pass ++unfocus
			{ "<leader>sc", "<cmd>Lspsaga show_cursor_diagnostics<CR>", desc = "[S]how [C]ursor diagnostics" },
			-- Show buffer diagnostic
			{ "<leader>sb", "<cmd>Lspsaga show_buf_diagnostics<CR>", desc = "[S]how [B]uffer diagnostics" },
			-- Diagnostic jump can use `<c-o>` to jump back
			{ "[e", "<cmd>Lspsaga diagnostic_jump_prev<CR>", desc = "Go to Diagnostic Previous" },
			{ "]e", "<cmd>Lspsaga diagnostic_jump_next<CR>", desc = "Go to Diagnostic Next" },
			-- Diagnostic jump with filter like Only jump to error
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
			-- Toggle Outline
			{ "<leader>o", "<cmd>Lspsaga outline<CR>", desc = "[O]utline right bar" },
			-- use o to fold,e to jump to it, q to quit
			-- Hover Doc
			-- if there has no hover will have a notify no information available
			-- to disable it just Lspsaga hover_doc ++quiet
			-- press twice it will jump into hover window
			{ "KD", "<cmd>Lspsaga hover_doc<CR>", desc = "Show Doc Hover" },
			-- if you want keep hover window in right top you can use ++keep arg
			-- notice if you use hover with ++keep you press this keymap it will
			-- close the hover window .if you want jump to hover window must use
			-- wincmd command <C-w>w
			{ "KK", "<cmd>Lspsaga hover_doc ++keep<CR>", desc = "Show doc Keep" },
			-- Callhierarchy
			{ "<Leader>ci", "<cmd>Lspsaga incoming_calls<CR>", desc = "[C]ode Calls [I]ncoming" },
			{ "<Leader>co", "<cmd>Lspsaga outgoing_calls<CR>", desc = "[C]ode Calls [O]utgoing" },
			-- Float terminal
			{
				"<M-d>",
				"<cmd>Lspsaga term_toggle<CR>",
				mode = { "n", "t" },
				desc = "Show Terminal",
			},
		},
		config = function()
			local saga = require("lspsaga")

			saga.setup({
				scroll_preview = {
					scroll_down = "<C-d>",
					scroll_up = "<C-u>",
				},
				definition = {
					edit = "<C-c>o",
					vsplit = "<C-c>v",
					split = "<C-c>i",
					tabe = "<C-c>t",
					quit = "q",
					close = "<Esc>",
				},
			})
			-- saga.init_lsp_saga()
		end,
		dependencies = { { "nvim-tree/nvim-web-devicons" } },
	},
	{
		"folke/trouble.nvim",
		cmd = { "TroubleToggle", "Trouble" },
		opts = { use_diagnostic_signs = true },
		keys = {
			{ "<leader>sd", "<cmd>TroubleToggle document_diagnostics<cr>", desc = "Document Diagnostics (Trouble)" },
			{ "<leader>sw", "<cmd>TroubleToggle workspace_diagnostics<cr>", desc = "Workspace Diagnostics (Trouble)" },
		},
	},
	-- {
	--   'windwp/nvim-autopairs',
	--   config = function()
	--     require("nvim-autopairs").setup()
	--     local cmp_autopairs = require('nvim-autopairs.completion.cmp')
	--     local cmp = require('cmp')
	--     cmp.event:on(
	--       'confirm_done',
	--       cmp_autopairs.on_confirm_done()
	--     )
	--   end,
	-- },
	-- A pretty diagnostics
	{
		"folke/trouble.nvim",
		config = function()
			require("trouble").setup({})
		end,
		dependencies = {
			{ "neovim/nvim-lspconfig" },
		},
	},
	{
		"ray-x/lsp_signature.nvim",
		config = function()
			require("lsp_signature").setup({
				timer_interval = 20,
				bind = true,
				hint_prefix = "",
				extra_trigger_chars = { "=", "," },
				-- floating_window = false,
			})
		end,
	},
	{ "nvim-treesitter/playground" },
}
