-- All the remap I can do
-- TODO: Figure out how to add the one that are part of plugins

-- Change mapleader
vim.g.mapleader = ","
vim.g.wordmotion_prefix = "<leader>"
local function map(mode, keys, action, description)
	local options = { noremap = true, silent = true, desc = description }
	vim.keymap.set(mode, keys, action, options)
end

-- doge is annoying
vim.g.doge_mapping = "<Leader>h"
map("n", "<leader>st", function()
	MiniTrailspace.trim()
end, "[S][t]rip Whitespace")
-- Copy paste binding
map("x", "<leader>pp", [["_dP]], "Past Previous copied selection")
map({ "x", "n", "v" }, "<leader>pc", '"+p', "Past Clipboard (CTR+V) after")
map({ "x", "n", "v" }, "<leader>pC", '"+P', "Past Clipboard (CTR+V) before")
map({ "n", "v" }, "<leader>y", [["+y]], "Copy to Clipboard (CTR+C)")
map("n", "<leader>Y", [["+Y]], "Copy to Clipboard (CTR+C) whole line")
-- Buffer stuff
map({ "n", "v" }, "<leader>d", [["_d]], "Delete to Buffer ?")
map("n", "<leader>t", ":Neotree toggle<cr>", "Open Explorer Tree")
map("n", "[b", "<cmd>bprevious<cr>", "Prev buffer")
map("n", "]b", "<cmd>bnext<cr>", "Next buffer")
-- map("n", "<leader>n", 'o-<space><space><ESC>"=strftime("%m/%d/%y")<CR>P i:<space>', 'Add Bragg entry')
map("n", "<leader>it", "<cmd>IronRepl<cr>", "[I]ron [T]oggle")
map("n", "<leader>ir", "<cmd>IronRestart<cr>", "[I]ron [R]estart")
map("n", "<leader>if", "<cmd>IronFocus<cr>", "[I]ron [F]ocus")
map("n", "<leader>ih", "<cmd>IronHide<cr>", "[I]ron [H]ide")
map("n", "<leader>zn", ":TZNarrow<CR>", "[Z]en [N]arrow")
map("v", "<leader>zn", ":'<,'>TZNarrow<CR>", "[Z]en [N]arrow")
map("n", "<leader>zf", ":TZFocus<CR>", "[Z]en [F]ocus toggle")
map("n", "<leader>zm", ":TZMinimalist<CR>", "[Z]en [M]inimalist")
map("n", "<leader>za", ":TZAtaraxis<CR>", "[Z]en [A]tarix")
map("n", "<C-w>m", ":TZFocus<CR>", "Maximize window")
-- harpoon
map("n", "<leader>Ha", "<cmd>lua require('harpoon.mark').add_file()<cr>", "[H]arpoon [A]dd file")
map("n", "<leader>Hn", "<cmd>lua require('harpoon.ui').nav_next()<cr>", "[H]arpoon [N]ext")
map("n", "<leader>Hp", "<cmd>lua require('harpoon.ui').nav_prev()<cr>", "[H]arpoon [P]revious")
map("n", "<leader>Ht", "<cmd>lua require('harpoon.ui').toggle_quick_menu()<cr>", "[H]arpoon [T]oggle")
-- tab nav
map("n", "<leader><tab>l", "<cmd>tablast<cr>", "Last Tab")
map("n", "<leader><tab>o", "<cmd>tabonly<cr>", "Close Other Tabs")
map("n", "<leader><tab>f", "<cmd>tabfirst<cr>", "First Tab")
map("n", "<leader><tab><tab>", "<cmd>tabnew<cr>", "New Tab")
map("n", "<leader><tab>]", "<cmd>tabnext<cr>", "Next Tab")
map("n", "<leader><tab>d", "<cmd>tabclose<cr>", "Close Tab")
map("n", "<leader><tab>[", "<cmd>tabprevious<cr>", "Previous Tab")
-- debug stuff
-- neotest
map("n", "<leader>Dm", "<cmd>lua require('neotest').run.run()<cr>", "Test [M]ethod")
map("n", "<leader>DM", "<cmd>lua require('neotest').run.run({strategy = 'dap'})<cr>", "Test [M]ethod DAP")
map("n", "<leader>Df", "<cmd>lua require('neotest').run.run({vim.fn.expand('%')})<cr>", "Test Class")
map(
	"n",
	"<leader>DF",
	"<cmd>lua require('neotest').run.run({vim.fn.expand('%'), strategy = 'dap'})<cr>",
	"Test Class DAP"
)
map("n", "<leader>DS", "<cmd>lua require('neotest').summary.toggle()<cr>", "Test [S]ummary")
-- dap
map("n", "<leader>Db", "<cmd>lua require'dap'.toggle_breakpoint()<cr>", "[B]reakpoint")
map("n", "<leader>Dc", "<cmd>lua require'dap'.continue()<cr>", "[C]ontinue")
map("n", "<leader>Di", "<cmd>lua require'dap'.step_into()<cr>", "[I]nto")
map("n", "<leader>Do", "<cmd>lua require'dap'.step_over()<cr>", "[O]ver")
map("n", "<leader>DO", "<cmd>lua require'dap'.step_out()<cr>", "[O]ut")
map("n", "<leader>Dr", function()
	require("dapui").toggle({ layout = 2, reset = true })
end, "[R]epl toggle")
map("n", "<leader>DR", function()
	require("dap").restart_frame()
end, "[R]estart dap")
map("n", "<leader>DC", function()
	require("dap").run_to_cursor()
end, "Run To [C]ursor")
map("n", "<leader>Dl", "<cmd>lua require'dap'.run_last()<cr>", "[L]ast")
map("n", "<leader>Du", "<cmd>lua require'dapui'.toggle()<cr>", "[U]I")
map("n", "<leader>Dt", "<cmd> lua require'neotest'.output_panel.toggle()<cr>", "[T]erminal")
map("n", "<leader>DT", function()
	require("dapui").toggle({ layout = 3, reset = true })
end, "[T]erminal dap")
map("n", "<leader>De", function()
	require("dap").close()
end, "[E]xit Session")
map("n", "<leader>DE", "<cmd>lua require'dap'.terminate()<cr>", "[E]xit kill")
map({ "n", "v" }, "<leader>Dh", "<cmd>lua require('dap.ui.widgets').hover()<cr>", "[H]over")
map({ "n", "v" }, "<leader>Dp", "<cmd>lua require('dap.ui.widgets').preview()<cr>", "[P]review")
map("v", "<leader>DE", function()
	require("dapui").eval()
end, "[E]valuate Input")
map("v", "<leader>Ds", function()
	require("dap-python").debug_selection()
end, "[S]end selection (Python)")
map("n", "<leader>De", "<cmd>lua require'dap'.terminate()<cr>", "[E]xit")
map("n", "<leader>Ds", function()
	local widgets = require("dap.ui.widgets")
	widgets.centered_float(widgets.scopes)
end, "[S]copes")
map("n", "<leader>Dw", "<cmd>Telescope dap frames<cr>", "[W]idget frames")

map("n", "]t", function()
	require("todo-comments").jump_next()
end, "Next todo comment")

map("n", "[t", function()
	require("todo-comments").jump_prev()
end, "Previous todo comment")
map("n", "<leader>Tt", "<cmd>TodoTelescope<CR>", "Todo")
-- Git stuff
map("n", "<leader>gc", "<cmd>Telescope conventional_commits<cr>", "[C]onventional Commit")
map("n", "<leader>O", "<CMD>Oil<CR>", "Oil")
vim.api.nvim_create_user_command("DiffviewToggle", function(e)
	local view = require("diffview.lib").get_current_view()

	if view then
		vim.cmd("DiffviewClose")
	else
		vim.cmd("DiffviewOpen " .. e.args)
	end
end, { nargs = "*" })
map("n", "<leader>gv", "<cmd>DiffviewToggle<cr>", "Diff [V]iew")
map("n", "<leader>go", "<cmd>Octo<cr>", "[O]cto pr list")

-- map('n','<leader>ga','<cmd>!git add %<cr><cr>','[G]it [A]dd current file')
-- map('n','<leader>gu','<cmd>!git restore --staged %<cr><cr>','[G]it [U]nstage current file')
map("n", "<leader>gP", "<cmd>!git push<cr>", "[P]ush")
map("n", "<leader>u", function()
	local bufnr = vim.api.nvim_get_current_buf()
	local diff_mode = vim.fn.getbufvar(bufnr, "&diff") == 1
	-- Check if the current buffer is in diff mode
	if diff_mode then
		-- If in diff mode, close diff view
		vim.cmd("diffoff | tabclose")
	else
		local filetype = vim.api.nvim_buf_get_option(0, "filetype")
		vim.cmd("tab split | diffthis")
		vim.cmd("aboveleft vnew | r # | normal! 1Gdd")
		vim.cmd("diffthis")
		vim.cmd("setlocal bt=nofile bh=wipe nobl noswf ro ft=" .. filetype)
		vim.cmd("wincmd l")
	end
end, "[U]nsaved Changes DiffView")
-- LSP inlay hints toggle
map("n", "<leader>ch", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, "[C]ode inlay [H]ints toggle")
-- screenshot stuff
map("v", "<leader>S", "<CMD>SSSelected<CR>",  "Screenshot" )
-- Copilot things
vim.keymap.set("i", "<C-J>", 'copilot#Accept("\\<CR>")', {
	expr = true,
	replace_keycodes = false,
})
vim.g.copilot_no_tab_map = true
-- Leap plugin remap
vim.keymap.set({'n', 'x', 'o'}, 's',  '<Plug>(leap-forward)')
vim.keymap.set({'n', 'x', 'o'}, 'S',  '<Plug>(leap-backward)')
vim.keymap.set('n',             'gs', '<Plug>(leap-from-window)')

