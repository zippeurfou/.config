return {
	{ "ryanoasis/vim-devicons" },
	{ "nvim-tree/nvim-web-devicons", lazy = true },
	{
		"lewis6991/gitsigns.nvim",
		config = function()
			require("gitsigns").setup({
				signs = {
					add = { text = "+" },
					change = { text = "~" },
					delete = { text = "_" },
					topdelete = { text = "‾" },
					changedelete = { text = "~" },
				},
				on_attach = function(bufnr)
					local gitsigns = require("gitsigns")

					local function map(mode, keys, action, description)
						local options = { noremap = true, silent = true, desc = description }
						vim.keymap.set(mode, keys, action, options)
					end

					-- Navigation
					map("n", "]c", function()
						if vim.wo.diff then
							vim.cmd.normal({ "]c", bang = true })
						else
							gitsigns.nav_hunk("next")
						end
					end, "Next Git Chunk")

					map("n", "[c", function()
						if vim.wo.diff then
							vim.cmd.normal({ "[c", bang = true })
						else
							gitsigns.nav_hunk("prev")
						end
					end, "Previous Git Chunk")

					-- Actions
					map("n", "<leader>gs", gitsigns.stage_hunk, "[S]tage Hunk")
					map("n", "<leader>gr", gitsigns.reset_hunk, "[R]eset Hunk")
					map("v", "<leader>gs", function()
						gitsigns.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, "[S]tage Hunk")
					map("v", "<leader>gr", function()
						gitsigns.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
					end, "[R]eset Hunk")
					map("n", "<leader>gS", gitsigns.stage_buffer, "[S]tage Buffer")
					map("n", "<leader>gu", gitsigns.undo_stage_hunk, "[U]ndo Last Stage Hunk")
					map("n", "<leader>gU", gitsigns.reset_buffer_index, "[U]ndo staged Buffer")
					map("n", "<leader>gR", gitsigns.reset_buffer, "[R]eset unstaged Buffer")
					map("n", "<leader>gp", gitsigns.preview_hunk, "[P]review Hunk")
					map("n", "<leader>gb", function()
						gitsigns.blame_line({ full = true })
					end, "[B]lame Line")
					map("n", "<leader>gB", gitsigns.toggle_current_line_blame, "[B]lame Toggle")
					map("n", "<leader>gd", gitsigns.diffthis, "[D]iff This")
					map("n", "<leader>gD", function()
						gitsigns.diffthis("~")
					end, "[D]iff Last Commit")
					-- map('n', '<leader>gd', gitsigns.toggle_deleted,)

					-- Text object
					map({ "o", "x" }, "ih", ":<C-U>Gitsigns select_hunk<CR>")
				end,
			})
		end,
	},
	{
		"sindrets/diffview.nvim",
		config = function()
			require("diffview").setup({})
		end,
	},
	{
		"pwntester/octo.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"nvim-telescope/telescope.nvim",
			-- OR 'ibhagwan/fzf-lua',
			"nvim-tree/nvim-web-devicons",
		},
		config = function()
			require("octo").setup({
				suppress_missing_scope = {
					projects_v2 = true,
				},
			})
		end,
	},
	{
		"j-hui/fidget.nvim",
		tag = "legacy",
		config = function()
			require("fidget").setup({})
		end,
	},
	{
		"Pocco81/true-zen.nvim",
		config = function()
			require("true-zen").setup({})
		end,
	},
	-- {
	--   "luukvbaal/statuscol.nvim", config = function()
	--     -- need to figure out how to make it work
	--     -- local builtin = require("statuscol.builtin")
	--     require("statuscol").setup({
	--       -- configuration goes here, for example:
	--       -- relculright = true,
	--       segments = {
	--         { text = { builtin.foldfunc }, click = "v:lua.ScFa" },
	--         {
	--           sign = { name = { "Diagnostic" }, maxwidth = 2, auto = true },
	--           click = "v:lua.ScSa"
	--         },
	--         -- { text = { builtin.lnumfunc }, click = "v:lua.ScLa", },
	--       --   {
	--           -- sign = { name = { ".*" }, maxwidth = 2, colwidth = 1, auto = true, wrap = true },
	--       --     click = "v:lua.ScSa"
	--       --   },
	--       }
	--     })
	--   end,
	-- },
	{
		"chentoast/marks.nvim",
		config = function()
			require("marks").setup({})
		end,
	},
	{
		"lukas-reineke/indent-blankline.nvim",
		tag = "v2.20.8",
		config = function()
			-- vim.g.indent_blankline_use_treesitter_scope = true
			require("indent_blankline").setup({
				show_current_context = true,
				show_current_context_start = true,
				char = "┊",
				show_trailing_blankline_indent = false,
				-- space_char_blankline = " ",
				use_treesitter = false,
			})
		end,
	},
	{
		"jbyuki/nabla.nvim",
		config = function()
			require("nabla").enable_virt({
				autogen = true, -- auto-regenerate ASCII art when exiting insert mode
				silent = true, -- silents error messages
			})
		end,
		enabled = false,
	},
	{
		"sourcegraph/sg.nvim",
		config = function()
			require("sg").setup({})
			local ok_wk, wk = pcall(require, "which-key")
			if not ok_wk then
				print("plugins/sg.lua: missing requirements")
				return
			end
			-- Cody stuff
			function search_diagnostics_cody()
				local start_line, end_line
				local mode = string.lower(vim.fn.mode())
				if mode == "v" then
					start_line = vim.fn.line("v")
					end_line = vim.fn.line(".")
					if start_line > end_line then
						start_line, end_line = end_line, start_line
					end
				else
					start_line = vim.fn.line(".")
					end_line = start_line
				end

				local bufnr = vim.api.nvim_get_current_buf()
				local all_diagnostics = vim.diagnostic.get(bufnr)
				local diagnostics = {}
				for _, diagnostic in ipairs(all_diagnostics) do
					if diagnostic.lnum + 1 >= start_line and diagnostic.lnum < end_line then
						table.insert(diagnostics, diagnostic)
					end
				end

				if #diagnostics == 0 then
					vim.notify("No diagnostics", vim.log.levels.WARN)
					return
				end

				local index = 1
				if #diagnostics > 1 then
					local inputList = { "Which diagnostic do you want explained?:" }
					for i, diagnostic in ipairs(diagnostics) do
						table.insert(inputList, string.format("%d. %s", i, diagnostic.message))
					end
					index = vim.fn.inputlist(inputList)
					if index <= 0 or index > #diagnostics then
						vim.notify("No diagnostic selected", vim.log.levels.INFO)
						return
					end
				end

				local clean_message = diagnostics[index].message:gsub("[A-Za-z0-9:/\\._%-]+[.][A-Za-z0-9]+", "")
				clean_message = clean_message:gsub("[A-Za-z0-9:/\\._%-]+[/\\][A-Za-z0-9:/\\._%-]+[.][A-Za-z0-9]+", "")
				local msg = "You are an expert coder and helpful assistant who can help debug code diagnostics, such as warning and error messages."
					.. "When appropriate, give solutions with code snippets as fenced codeblocks with a language identifier to enable syntax highlighting.\n"
					.. "This is a the diagnostic message for the code:\n"
					.. clean_message

				require("sg.cody.commands").ask_range(bufnr, start_line - 1, end_line, msg)
			end

			local doc_msg = "Add Docstring and arguments types hints and return types hints to the whole code."
				.. "For types hints leverage the typing package."
				.. "DO NOT ADD NEW PACKAGE IMPORT."
				.. "Follow Google Python Style Guide, add type hints to the arguments in the docstring inside parenthesis."
				.. "Following this convention name (type hints): Description."
				.. "If there is no type hints DO ADD them."
				.. "When applicable, add sections such as Args, Returns, Attributes, Todos, Notes, See Also, Warnings, Raises, etc..."
				.. "Provide clear technical description."
				.. "If the method is missing the class definition DO NOT CREATE ONE BUT KEEP self if provided."
				-- .. "If a class is provided MAKE SURE TO ADD AS MUCH DOCSTRING AS POSSIBLE."
				.. "DO NOT CHANGE ANY CODE OR COMMENTS BESIDE WHAT INSTRUCTED."
				.. "Use tabs instead of space for indentation."
				.. "Strip whitespaces."
				.. "DO NOT MAKE ANYTHING UP, USE FACT ONLY."

			wk.add({
				{
					mode = { "n" },
					{ "<leader>CC", ":CodyChat<CR>", desc = "[C]ody [C]hat" },
					{ "<leader>CD", search_diagnostics_cody, desc = "[C]ody [D]iagnostic Search" },
					{ "<leader>CR", ":CodyChat!<CR>", desc = "[C]ody chat [R]eset" },
					{ "<leader>Ca", ":CodyTaskAccept<CR>", desc = "[C]ody Task [A]ccept" },
					{ "<leader>Cc", ":CodyToggle<cr>", desc = "[C]ody [T]oggle" },
					{ "<leader>Cd", ":CodyTask " .. doc_msg .. "<CR>", desc = "[C]ody [d]ocumentation Generate" },
					{ "<leader>Cn", ":CodyTaskNext<CR>", desc = "[C]ody Task [N]ext" },
					{ "<leader>Cp", ":CodyTaskPrev<CR>", desc = "[C]ody Task [P]revious" },
					{ "<leader>Cr", ":CodyRestart<CR>", desc = "[C]ody [R]estart" },
					{ "<leader>Ct", ":CodyTask ", desc = "[C]ody [T]ask Create" },
					{ "<leader>Cv", ":CodyTaskView<CR>", desc = "[C]ody Task [V]iew" },
				},
				{
					mode = { "v" },
					{ "<leader>C", group = "cody" },
					{
						"<leader>CD",
						search_diagnostics_cody,
						desc = "[C]ody [D]iagnostic Search",
						silent = false,
					},
					{
						"<leader>Ca",
						":CodyAsk ",
						desc = "[C]ody [A]sk",
						silent = false,
					},
					{
						"<leader>Cd",
						":CodyTask " .. doc_msg .. "<CR>",
						desc = "[C]ody [d]ocumentation Generate",
						silent = false,
					},
					{
						"<leader>Ct",
						":CodyTask ",
						desc = "[C]ody [T]ask Create",
						silent = false,
					},
				},
			})

			-- wk.register({
			--   name = '+cody',
			--   c = { ':CodyToggle<cr>', '[C]ody [T]oggle' },
			--   r = { ':CodyRestart<CR>', '[C]ody [R]estart' },
			--   C = { ':CodyChat<CR>', '[C]ody [C]hat' },
			--   R = { ':CodyChat!<CR>', '[C]ody chat [R]eset' },
			--   t = { ':CodyTask ', '[C]ody [T]ask Create' },

			--   a = { ':CodyTaskAccept<CR>', '[C]ody Task [A]ccept' },
			--   p = { ':CodyTaskPrev<CR>', '[C]ody Task [P]revious' },
			--   n = { ':CodyTaskNext<CR>', '[C]ody Task [N]ext' },
			--   -- Custom stuff
			--   d = { ":CodyTask " .. doc_msg .. "<CR>", "[C]ody [d]ocumentation Generate" },
			--   D = { search_diagnostics_cody, "[C]ody [D]iagnostic Search" },
			--   -- Steal stuff from https://github.com/undg/.dot/blob/aed6fb4b2a11463d8004a5b8c384bf07df4e4324/vim/.config/nvim/lua/plugins/sg.lua
			--   -- a = {
			--   --   name = 'automation',
			--   --   s = { ai.text.proofread.get, ai.text.proofread.desc },
			--   --   r = { ai.readme.body.get, ai.readme.body.desc },
			--   --   p = { ai.pull_request.description.get, ai.pull_request.description.desc },
			--   --   g = {
			--   --     name = 'git',
			--   --     C = { ai.commit.open_with_message.get, ai.commit.open_with_message.desc },
			--   --     c = { ai.commit.message.get, ai.commit.message.desc },
			--   --     t = { ai.commit.title.get, ai.commit.title.desc },
			--   --   },
			--   -- },
			-- }, { prefix = '<leader>C', mode = 'n' })

			-- wk.register({
			--   name = '+cody',
			--   a = { ':CodyAsk ', '[C]ody [A]sk' },
			--   t = { ':CodyTask ', '[C]ody [T]ask Create' },
			--   -- Custom stuff
			--   d = { ":CodyTask " .. doc_msg .. "<CR>", "[C]ody [d]ocumentation Generate" },
			--   D = { search_diagnostics_cody, "[C]ody [D]iagnostic Search" },
			-- }, { prefix = '<leader>C', mode = 'v', silent = false })
		end,
		dependencies = {
			"nvim-lua/plenary.nvim", --[[ "nvim-telescope/telescope.nvim ]]
		},

		-- If you have a recent version of lazy.nvim, you don't need to add this!
		build = "nvim -l build/init.lua",
	},
	{
		"github/copilot.vim",
		lazy = false,
		init = function()
		end,
	},
	{
		"nvim-lualine/lualine.nvim",
		event = "VeryLazy",
		opts = function()
			return {
				sections = { lualine_c = { "buffers" } },
				disabled_filetypes = {
					"dapui_watches",
					"dapui_breakpoints",
					"dapui_scopes",
					"dapui_console",
					"dapui_stacks",
					"dap-repl",
				},
			}
		end,
	},
	-- {
	--   -- "ellisonleao/gruvbox.nvim",
	--   "morhetz/gruvbox",
	--   lazy=true,
	--    -- priority = 1000,
	--   config = function()
	--     -- vim.g.gruvbox_contrast_dark='dark'
	--   -- vim.o.background = "dark" -- or "light" for light mode
	--   -- require("gruvbox").setup({
	--       -- inverse = false,
	--       -- invert_selection = false,
	--     -- })
	--   -- vim.cmd("colorscheme gruvbox")
	--   end,
	-- },
	{ "bluz71/vim-nightfly-colors", lazy = true },
	{ "EdenEast/nightfox.nvim", lazy = true },
	{
		"folke/tokyonight.nvim",
		config = function()
			require("tokyonight").setup({
				on_highlights = function(hl, c)
					hl.CursorLineNr = { fg = c.dark5 } -- # Use the old color. I don't like the orange
				end,
			})
			vim.cmd("colorscheme tokyonight-night")
		end,
	},
	{
		"hat0uma/csvview.nvim",
		config = function()
			require("csvview").setup()
		end,
	},
	{
		"folke/todo-comments.nvim",
		dependencies = { "nvim-lua/plenary.nvim" },
		opts = {
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
		},
	},
}
