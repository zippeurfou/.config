return {
  -- Move with Option kjhl
  {
    'echasnovski/mini.move',
    config = function()
      require('mini.move').setup(
        {
          -- Module mappings. Use `''` (empty string) to disable one.
          mappings = {
            -- M = left option key. need to be setup in profile in mac os
            -- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
            left = '<M-h>',
            right = '<M-l>',
            down = '<M-j>',
            up = '<M-k>',
            -- Move current line in Normal mode
            line_left = '<M-h>',
            line_right = '<M-l>',
            line_down = '<M-j>',
            line_up = '<M-k>',
          },
        }
      )
    end,
  },
  -- search with s/S
  {
    'ggandor/leap.nvim',
    config = function()
      -- require('leap').add_default_mappings()
      local leap = require('leap')
      local special_keys = {
        repeat_search = '<tab>',
        next_phase_one_target = '<tab>',
        next_target = { '<tab>', ';' },
        prev_target = { '<s-tab>', ',' },
        next_group = '<tab>',
        prev_group = '<s-tab>',
        multi_accept = '<tab>',
        multi_revert = '<backspace>',
      }
      leap.opts.special_keys = special_keys
    end,
  },
  -- display  next f and move with f<search> f for next
  {
    'ggandor/flit.nvim',
    dependencies = { 'ggandor/leap.nvim' },
    config = function()
      require('flit').setup()
    end,
  },
  -- vim surround gz+ shortcut
  {
    "echasnovski/mini.surround",
    opts = {
      mappings = {
        add = "gza",            -- Add surrounding in Normal and Visual modes
        delete = "gzd",         -- Delete surrounding
        find = "gzf",           -- Find surrounding (to the right)
        find_left = "gzF",      -- Find surrounding (to the left)
        highlight = "gzh",      -- Highlight surrounding
        replace = "gzr",        -- Replace surrounding
        update_n_lines = "gzn", -- Update `n_lines`
      },
    },
  },
  -- hard time for nice messages for me to do better
  {
    "m4xshen/hardtime.nvim",
    dependencies = { "MunifTanjim/nui.nvim", "nvim-lua/plenary.nvim" },
    opts = {}
  },
  -- move camelcase with <leader>
  {
    'chaoren/vim-wordmotion',
    config = function()
    end
  },
}
