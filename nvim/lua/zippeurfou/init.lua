-- TODO: Figure out if i need to set leader here or in remap

-- Change mapleader
vim.g.mapleader = ","

require("zippeurfou/options")
require("zippeurfou/remap")
require("zippeurfou/autocmd")

local o = vim.opt
-- lazy.nvim setup
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
o.rtp:prepend(lazypath)
require("lazy").setup("zippeurfou.plugins", { install = { colorscheme = { "railscasts" } } })
