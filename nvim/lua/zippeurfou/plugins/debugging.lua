return {
  {
    'nvim-neotest/neotest-python',
    dependencies = {
      { 'nvim-neotest/neotest' },
    },
  },
  {
    'nvim-neotest/neotest',
    config = function()
      require("neotest").setup {
        log_level = vim.log.levels.DEBUG,
        quickfix = {
          open = false,
        },
        status = {
          virtual_text = true,
          signs = true,
        },
        adapters = {
          require "neotest-python" {
            -- Extra arguments for nvim-dap configuration
            -- See https://github.com/microsoft/debugpy/wiki/Debug-configuration-settings for values
            dap = {
              justMyCode = false,
              console = "integratedTerminal",
            },
            -- args = { "--log-level", "DEBUG", "--quiet" },
            -- runner = "pytest",
            -- runner = "unittest",
          },
        },
      }
    end,
    dependencies = {
      { 'nvim-neotest/neotest-python' },
    },
  },
  {
    'mfussenegger/nvim-dap',
  },
  {
    'mfussenegger/nvim-dap-python',
    config = function()
      local mason_path = vim.fn.glob(vim.fn.stdpath "data" .. "/mason/")
      pcall(function()
        require("dap-python").setup(mason_path .. "packages/debugpy/venv/bin/python")
      end)
    end,
    dependencies = {
      { 'mfussenegger/nvim-dap' },
    }
  },
  {
    'rcarriga/nvim-dap-ui',
    config = function()
      require("dapui").setup({
        layouts = { {
          elements = { {
            id = "scopes",
            size = 0.25
          }, {
            id = "breakpoints",
            size = 0.25
          }, {
            id = "stacks",
            size = 0.25
          }, {
            id = "watches",
            size = 0.25
          } },
          position = "left",
          size = 40
        }, {
          elements = { {
            id = "repl",
            size = 1
          } },
          position = "bottom",
          size = 10
        }, {
          elements = { {
            id = "console",
            size = 1
          } },
          position = "bottom",
          size = 10
        } }
      })
    end,
    dependencies = {
      { 'mfussenegger/nvim-dap',
        'nvim-neotest/nvim-nio'
      },
    }
  },
  {
    'LiadOz/nvim-dap-repl-highlights',
    config = function()
      require('nvim-dap-repl-highlights').setup()
    end,
    dependencies = {
      { 'mfussenegger/nvim-dap' },
    }
  },
  { "rcarriga/cmp-dap"
  },
  {
    'zippeurfou/nvim-dap-virtual-text',
    config = function()
      require("nvim-dap-virtual-text").setup {
        enabled = true,                     -- enable this plugin (the default)
        enabled_commands = true,            -- create commands DapVirtualTextEnable, DapVirtualTextDisable, DapVirtualTextToggle, (DapVirtualTextForceRefresh for refreshing when debug adapter did not notify its termination)
        highlight_changed_variables = true, -- highlight changed values with NvimDapVirtualTextChanged, else always NvimDapVirtualText
        highlight_new_as_changed = false,   -- highlight new variables in the same way as changed variables (if highlight_changed_variables)
        show_stop_reason = true,            -- show stop reason when stopped for exceptions
        commented = true,                   -- prefix virtual text with comment string
        only_first_definition = false,      -- only show virtual text at first definition (if there are multiple)
        all_references = true,              -- show virtual text on all all references of the variable (not only definitions)
        clear_on_continue = false,
        -- experimental features:
        -- virt_text_pos = 'eol', -- position of virtual text, see `:h nvim_buf_set_extmark()`
        all_frames = true,  -- show virtual text for all stack frames not only current. Only works for debugpy on my machine.
        virt_lines = false, -- show virtual lines instead of virtual text (will flicker!)
        -- virt_text_win_col = nil -- position the virtual text at a fixed window column (starting from the first text column) ,
        -- e.g. 80 to position at column 80, see `:h nvim_buf_set_extmark()`
      }
    end,
    branch = "nvim-pairs-error-fix",
  },
  dependencies = {
    { 'mfussenegger/nvim-dap' },
  },
  branch = "master",
}
