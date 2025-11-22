return {
	-- show help when typing stuff. Help me :)
	{
		"folke/which-key.nvim",
		opts = {
			icons = {
				mappings = false,
			},
		},
		config = function()
			require("which-key").setup({ icons = { mappings = false } })
			local wk = require("which-key")
			wk.add({
				{
					mode = { "n", "v" },
					{ "<leader><tab>", group = "tabs" },
					{ "<leader>C", group = "cody" },
					{ "<leader>D", group = "debug" },
					{ "<leader>H", group = "harpoon" },
					{ "<leader>T", group = "telescope" },
					{ "<leader>Tc", group = "colorscheme" },
					{ "<leader>Tf", group = "find" },
					{ "<leader>Tl", group = "lsp" },
					{ "<leader>Tg", group = "git" },
					{ "<leader>Ts", group = "search" },
					{ "<leader>c", group = "code" },
					{ "<leader>g", group = "git" },
					{ "<leader>i", group = "iron" },
					{ "<leader>is", group = "send" },
					{ "<leader>p", group = "paste" },
					{ "<leader>s", group = "showdiagnostic" },
					{ "<leader>z", group = "zen" },
					{ "K", group = "hoverdoc" },
					{ "[", group = "prev" },
					{ "]", group = "next" },
					{ "g", group = "goto" },
					{ "gd", group = "gotodefinition" },
					{ "gr", group = "rename" },
					{ "gz", group = "surround" },
					{
						"<leader>W",
						group = "windows",
						expand = function()
							return require("which-key.extras").expand.win()
						end,
					},
					-- Use Telescope inseated
					-- {
					-- 	"<leader>B",
					-- 	group = "buffers",
					-- 	expand = function()
					-- 		return require("which-key.extras").expand.buf()
					-- 	end,
					-- },
				},
			})
			-- wk.register({
			--   mode = { "n", "v" },
			-- ["g"] = { name = "+goto" },
			--   ["gd"] = { name = "+gotodefinition" },
			--   ["gr"] = { name = "+rename" },
			--   ["gz"] = { name = "+surround" },
			--   ["]"] = { name = "+next" },
			--   ["["] = { name = "+prev" },
			--   ["K"] = { name = "+hoverdoc" },
			--   ["<leader>g"] = { name = "+git" },
			--   ["<leader>D"] = { name = "+debug" },
			--   ["<leader>i"] = { name = "+iron" },
			--   ["<leader>is"] = { name = "+send" },
			--   ["<leader>c"] = { name = "+code" },
			--   ["<leader>C"] = { name = "+cody" },
			--   ["<leader>H"] = { name = "+harpoon" },
			--   ["<leader>p"] = { name = "+paste" },
			--   ["<leader>s"] = { name = "+showdiagnostic" },
			--   ["<leader>z"] = { name = "+zen" },
			--   ["<leader>T"] = { name = "+telescope" },
			--   ["<leader>Tf"] = { name = "+find" },
			--   ["<leader>Ts"] = { name = "+search" },
			--   ["<leader>Tg"] = { name = "+git" },
			--   ["<leader>Tc"] = { name = "+colorscheme" },
			-- })
		end,
	},
	-- show colors when typing :ColorizerAttachToBuffer
	{ "norcalli/nvim-colorizer.lua" },
	-- autocomplete
	{
		"David-Kunz/gen.nvim",
		config = function()
			require("gen").model = "zephyr" -- default 'mistral:instruct', best model? codellama:34b-code-q4_K_M
			-- require('gen').model = 'codellama:7b-code-q4_K_M' -- default 'mistral:instruct', best model? codellama:34b-code-q4_K_M
		end,
	},
	-- strip whitespace
	{
		"echasnovski/mini.trailspace",
		config = function()
			require("mini.trailspace").setup({})
		end,
	},
	-- comment with gcc and co using native nvim + treesitter
	{
		"folke/ts-comments.nvim",
		opts = {},
		event = "VeryLazy",
		enabled = vim.fn.has("nvim-0.10.0") == 1,
	},
	{
		"kkoomen/vim-doge",
		build = function()
			vim.cmd(":call doge#install()")
		end,
		config = function()
			vim.g.doge_mapping = "<Leader>h"
			vim.g.doge_doc_standard_python = "google"
		end,
	},
	{
		"iamcco/markdown-preview.nvim",
		config = function()
			vim.fn["mkdp#util#install"]()
		end,
	},
	{
		"MeanderingProgrammer/render-markdown.nvim",
		-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.nvim' }, -- if you use the mini.nvim suite
		-- dependencies = { 'nvim-treesitter/nvim-treesitter', 'echasnovski/mini.icons' }, -- if you use standalone mini plugins
		dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" }, -- if you prefer nvim-web-devicons
		---@module 'render-markdown'
		---@type render.md.UserConfig
		opts = {},
	},
	{
		"mistricky/codesnap.nvim",
		build = "make",
		keys = {
			{ "<leader>S", "<cmd>CodeSnap<cr>", mode = "x", desc = "Screenshot Clipboard" },
			{ "<leader>s", "<cmd>CodeSnapSave<cr>", mode = "x", desc = "Sreenshot File" },
		},
		opts = {
			save_path = "~/Code Screenshots",
			has_breadcrumbs = false,
			bg_theme = "grape",
			watermark = "",
			mac_window_bar = false,
		},
	},
	{
		"quarto-dev/quarto-nvim",
		dependencies = {
			"jmbuhr/otter.nvim",
			"nvim-treesitter/nvim-treesitter",
		},
	},
}
