local Util = require("zippeurfou.util")
return {
  {
    "nvim-neo-tree/neo-tree.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    config = function()
      vim.fn.sign_define("DiagnosticSignError",
        { text = " ", texthl = "DiagnosticSignError" })
      vim.fn.sign_define("DiagnosticSignWarn",
        { text = " ", texthl = "DiagnosticSignWarn" })
      vim.fn.sign_define("DiagnosticSignInfo",
        { text = " ", texthl = "DiagnosticSignInfo" })
      vim.fn.sign_define("DiagnosticSignHint",
        { text = "", texthl = "DiagnosticSignHint" })
      require("neo-tree").setup({
        filesystem = {
          hide_gitignored = false,
          hide_hidden = false,
        },
        default_component_configs = {
          git_status = {
            symbols = {
              -- Change type
              added     = "✚", -- or "✚", but this is redundant info if you use git_status_colors on the name
              modified  = "", -- or "", but this is redundant info if you use git_status_colors on the name
              deleted   = "✖", -- this can only be used in the git_status source
              renamed   = "", -- this can only be used in the git_status source
              -- Status type
              untracked = "",
              ignored   = "",
              unstaged  = "",
              staged    = "",
              conflict  = "",
            }
          },
        },
      })
    end,
  },
  { "qpkorr/vim-bufkill", },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    version = false, -- telescope did only one release, so use HEAD for now
    keys = {
      { "<leader>Tb",  "<cmd>Telescope buffers show_all_buffers=true<cr>",       desc = "Switch Buffer" },
      -- find
      { "<leader>Tfb", "<cmd>Telescope buffers<cr>",                             desc = "Buffers" },
      { "<leader>Tff", Util.telescope("files"),                                  desc = "Find Files (root dir)" },
      { "<leader>TfF", Util.telescope("files", { cwd = false }),                 desc = "Find Files (cwd)" },
      { "<leader>Tfr", "<cmd>Telescope oldfiles<cr>",                            desc = "Recent" },
      { "<leader>F", Util.telescope("files"),                                    desc = "Find Files (root dir)" },
      { "<leader>B", "<cmd>Telescope buffers<cr>",                               desc = "Buffers" },
      -- git
      { "<leader>Tgc", "<cmd>Telescope git_commits<CR>",                         desc = "commits" },
      { "<leader>Tgs", "<cmd>Telescope git_status<CR>",                          desc = "status" },
      -- search
      { "<leader>Tsa", "<cmd>Telescope autocommands<cr>",                        desc = "Auto Commands" },
      { "<leader>Tsb", "<cmd>Telescope current_buffer_fuzzy_find<cr>",           desc = "Buffer" },
      { "<leader>Tsc", "<cmd>Telescope command_history<cr>",                     desc = "Command History" },
      { "<leader>TsC", "<cmd>Telescope commands<cr>",                            desc = "Commands" },
      { "<leader>Tsd", "<cmd>Telescope diagnostics<cr>",                         desc = "Diagnostics" },
      { "<leader>Tsg", Util.telescope("live_grep"),                              desc = "Grep (root dir)" },
      { "<leader>S", Util.telescope("live_grep"),                                desc = "[S]earch" },
      { "<leader>TsG", Util.telescope("live_grep", { cwd = false }),             desc = "Grep (cwd)" },
      { "<leader>Tsh", "<cmd>Telescope help_tags<cr>",                           desc = "Help Pages" },
      { "<leader>TsH", "<cmd>Telescope highlights<cr>",                          desc = "Search Highlight Groups" },
      { "<leader>Tsk", "<cmd>Telescope keymaps<cr>",                             desc = "Key Maps" },
      { "<leader>TsM", "<cmd>Telescope man_pages<cr>",                           desc = "Man Pages" },
      { "<leader>Tsm", "<cmd>Telescope marks<cr>",                               desc = "Jump to Mark" },
      { "<leader>Tso", "<cmd>Telescope vim_options<cr>",                         desc = "Options" },
      { "<leader>Tsw", Util.telescope("grep_string"),                            desc = "Word (root dir)" },
      { "<leader>TsW", Util.telescope("grep_string", { cwd = false }),           desc = "Word (cwd)" },
      { "<leader>Tcs", Util.telescope("colorscheme", { enable_preview = true }), desc = "Colorscheme with preview" },
      {"<leader>Tlf",'<cmd>Telescope lsp_document_symbols symbols="function"<cr>',desc = "Function"},
      {"<leader>Tla",'<cmd>Telescope lsp_document_symbols<cr>',desc = "All"},
      {
        "<leader>ss",
        Util.telescope("lsp_document_symbols", {
          symbols = {
            "Class",
            "Function",
            "Method",
            "Constructor",
            "Interface",
            "Module",
            "Struct",
            "Trait",
            "Field",
            "Property",
          },
        }),
        desc = "Goto Symbol",
      },
    },
    opts = {
      defaults = {
        prompt_prefix = " ",
        selection_caret = " ",
        mappings = {
          -- In normal mode ? is which-key
          i = {
            ["<c-t>"] = function(...)
              return require("trouble.providers.telescope").open_with_trouble(...)
            end,
            ["<a-i>"] = function()
              Util.telescope("find_files", { no_ignore = true })()
            end,
            ["<a-h>"] = function()
              Util.telescope("find_files", { hidden = true })()
            end,
            ["<C-d>"] = function(...)
              return require("telescope.actions").cycle_history_next(...)
            end,
            ["<C-u>"] = function(...)
              return require("telescope.actions").cycle_history_prev(...)
            end,
            ["<C-h>"] = "which_key",
          },
        },
      },
    },
  },
  {
    "ThePrimeagen/harpoon",
    config = function()
      local mark = require "harpoon.mark"
      local ui = require "harpoon.ui"
      -- vim.keymap.set("n", ",Ha", mark.add_file)
      -- vim.keymap.set("n", ",Hn", ui.nav_next)
      -- vim.keymap.set("n", ",Hp", ui.nav_prev)
      -- vim.keymap.set("n", ",Hh", ui.toggle_quick_menu)
      require("telescope").load_extension "harpoon"
    end,
    -- enabled = false,
  },
  {
    "nvim-telescope/telescope-dap.nvim",
    dependencies = "nvim-telescope/telescope.nvim",
    config = function()
      require("telescope").load_extension "dap"
    end,
    lazy = true,
  },
  {
    "olacin/telescope-cc.nvim",
    config = function()
      require("telescope").load_extension "conventional_commits"
    end,
    lazy = true,
  },
  {
    'hkupty/iron.nvim',
    config = function()
      local iron = require("iron.core")
      iron.setup {
        config = {
          highlight_last = false,
          scratch_repl = true,
          -- Automatically closes the repl window on process end
          close_window_on_exit = true,
          repl_open_cmd = "horizontal 10 split",
          repl_definition = {
            sh = { command = { "zsh" } },
            python = require("iron.fts.python").ipython
          },
        },
        should_map_plug = true,
        keymaps = {
          send_motion = "<leader>iss",
          visual_send = "<leader>iss",
          send_line = "<leader>isl",
          send_file = "<leader>isf",
          -- repeat_cmd = "<leader>is.",
          cr = "<leader>is<cr>",
          interrupt = "<leader>isi",
          exit = "<leader>isq",
          clear = "<leader>isl",
        },
        highlight = false,
        ignore_blank_lines = true, -- ignore blank lines when sending visual select lines
      }
    end,
  },
  {
    "rmagatti/auto-session",
    config = function()
      require("auto-session").setup {}
    end,
  },
  {
    'stevearc/oil.nvim',
    opts = {},
    -- Optional dependencies
    dependencies = { "nvim-tree/nvim-web-devicons" },
  },
}
