return {
  {'nvim-treesitter/nvim-treesitter-textobjects',
    dependencies = 'nvim-treesitter/nvim-treesitter',
    build=":TSUpdate",
    event = "BufReadPost",
    keys = {
      { "<c-space>", desc = "Increment selection" },
      { "<c-s>", desc = "Increment selection by scope" },
      { "<bs>", desc = "Schrink selection", mode = "x" },
    },
    ---@type TSConfig
    opts = {
      highlight = { enable = true },
      indent = { enable = true, disable = {"python","c", "cpp", "yaml"} },
      context_commentstring = { enable = true, enable_autocmd = false,config = {
        -- Languages that have a single comment style
        typescript = "// %s",
        css = "/* %s */",
        scss = "/* %s */",
        html = "<!-- %s -->",
        svelte = "<!-- %s -->",
        vue = "<!-- %s -->",
        json = "",
      } },
      ensure_installed = {
        "bash",
        "vimdoc",
        "html",
        "javascript",
        "json",
        "lua",
        "markdown",
        "markdown_inline",
        "python",
        "query",
        "regex",
        "tsx",
        "typescript",
        "vim",
        "yaml",
        "c",
        "cpp",
        "cuda",
        "gitignore",
        "gitattributes",
        "go",
        "latex",
        "r",
        "sparql",
        "sql",
        "terraform",
        "dockerfile"
      },
      incremental_selection = {
        enable = true,
        keymaps = {
          init_selection = "<C-space>",
          node_incremental = "<C-space>",
          scope_incremental = "<c-s>",
          node_decremental = "<bs>",
        },
      },
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
          keymaps = {
            -- You can use the capture groups defined in textobjects.scm
            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
            ['iC'] = '@call.inner',
            ['aC'] = '@call.outer',
            ['iA'] = '@assignment.inner',
            ['aA'] = '@assignment.outer',
            ['il'] = '@loop.inner',
            ['al'] = '@loop.outer',
            ['ii'] = '@conditional.inner',
            ['ai'] = '@conditional.outer',
            ['aS'] = '@statement.outer',
          },
        },
        move = {
          enable = true,
          set_jumps = true, -- whether to set jumps in the jumplist
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = '@class.outer',
            [']s'] = '@statement.outer',
            [']i'] = '@conditional.outer',
            [']l'] = '@loop.outer',
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
            [']S'] = '@statement.outer',
            [']I'] = '@conditional.outer',
            [']L'] = '@loop.outer',
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer',
            ['[s'] = '@statement.outer',
            ['[i'] = '@conditional.outer',
            ['[l'] = '@loop.outer',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
            ['[S'] = '@statement.outer',
            ['[I'] = '@conditional.outer',
            ['[L'] = '@loop.outer',
          },
        },
        swap = {
          enable = true,
          swap_next = {
            ['<leader>a'] = '@parameter.inner',
          },
          swap_previous = {
            ['<leader>A'] = '@parameter.inner',
          },
        },
      },
    },
    ---@param opts TSConfig
    config = function(plugin, opts)
      require("nvim-treesitter.configs").setup(opts)
    end,
  },
 {
    "RRethy/vim-illuminate",
    event = "BufReadPost",
    opts = { delay = 200 },
    config = function(_, opts)
      require("illuminate").configure(opts)
    end,
    keys = {
      { "]r", function() require("illuminate").goto_next_reference(false) end, desc = "Next Reference", },
      { "[r", function() require("illuminate").goto_prev_reference(false) end, desc = "Prev Reference" },
    },
  },


}

