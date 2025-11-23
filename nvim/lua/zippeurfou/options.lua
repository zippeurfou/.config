local o = vim.opt
o.modelines = 8   -- Number of lines to keep for set command
o.number = true   -- Show line number
o.cursorline = true -- Highlight current line
o.tabstop = 2     -- Make tabs as wide as two spaces
o.shiftwidth = 2  -- indentation with >
o.softtabstop = 2
--Use relative line numbers
o.relativenumber = true
--Start scrolling three lines before the horizontal window border
o.scrolloff = 8
o.listchars:append({ tab = "▸ ", eol = "¬", trail = "·", nbsp = "_" }) -- Show “invisible” characters
--o.listchars = {tab="▸ "}
-- set lcs=tab:▸\ ,trail:·,eol:¬,nbsp:_ old stuff just in case
o.list = true     -- Make sure it is shown
o.expandtab = true -- Use space instead of tabs
o.hlsearch = true -- Highlight searches
o.ignorecase = true -- Ignore case of searches
--Highlight dynamically as pattern is typed
o.incsearch = true
--Always show status line
o.laststatus = 2
--Enable mouse in all modes
o.mouse = "a"
--Disable error bells
o.errorbells = false
o.belloff = "all"
--Don’t reset cursor to start of line when moving around.
o.startofline = false
--Don’t show the intro message when starting Vim
o.shortmess = "atI"
--Show the current mode
o.showmode = true
--Show the filename in the window titlebar
o.title = true
--Show the (partial) command as it’s being typed
o.showcmd = true
o.signcolumn = "yes:4" -- sign column
o.termguicolors = true -- pretty colors
o.timeoutlen = 300     -- Reduce timeout for whichkeys
-- vim.cmd[[colorscheme railscasts]] -- Set my color scheme
o.splitbelow = true    -- horizontal split below by default
o.splitright = true    -- vertical split right by default
o.foldmethod = 'indent'
o.foldlevel = 99
vim.g.python3_host_prog = vim.fn.getenv 'PYENV_ROOT' .. '/versions/neovim3/bin/python'
vim.g.python_host_prog = vim.fn.getenv 'PYENV_ROOT' .. '/versions/neovim2/bin/python'
-- make zsh files recognized as sh for bash-ls & treesitter
vim.filetype.add {
  extension = {
    zsh = "sh",
    sh = "sh", -- force sh-files with zsh-shebang to still get sh as filetype
  },
  filename = {
    [".zshrc"] = "sh",
    [".zshenv"] = "sh",
  },
}
