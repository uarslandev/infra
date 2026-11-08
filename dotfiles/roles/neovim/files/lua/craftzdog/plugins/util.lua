-- File explorer
require("oil").setup({
	columns = {
		"icon",
		{ "permissions", highlight = "Type" },
		{ "size", highlight = "String" },
		{ "mtime", highlight = "Keyword" },
	},
	keymaps = {
		["h"] = { "actions.parent", mode = "n" },
		["q"] = { "actions.close", mode = "n" },
	},
	view_options = {
		show_hidden = true,
	},
	float = {
		border = "rounded",
		win_options = {
			winblend = 0,
		},
		max_width = 200,
	},
	preview_win = {
		update_on_cursor_moved = true,
	},
	lsp_file_methods = {
		enabled = true,
		timeout_ms = 1000,
		autosave_changes = true,
	},
})

require("copilot").setup({
	suggestion = {
		auto_trigger = true,
		keymap = {
			accept = "<C-l>",
			accept_word = "<M-l>",
			accept_line = "<M-S-l>",
			next = "<M-]>",
			prev = "<M-[>",
			dismiss = "<C-]>",
		},
	},
	filetypes = {
		markdown = true,
		help = true,
	},
	-- infra: never send secrets to Copilot. `sops edit` opens decrypted files from a temp dir.
	should_attach = function(buf_id, bufname)
		if not vim.bo[buf_id].buflisted or vim.bo[buf_id].buftype ~= "" then
			return false
		end
		local path = vim.fs.normalize(bufname or "")
		local tmp = vim.fs.normalize(vim.env.TMPDIR or "/tmp")
		local blocked = { "%.sops%.", "%.env$", "/%.env%.", "%.tfvars$", "%.tfstate", "kubeconfig", "%.agekey$", "/%.ssh/" }
		if path:sub(1, #tmp + 1) == tmp .. "/" or path:sub(1, 5) == "/tmp/" then
			return false
		end
		for _, pattern in ipairs(blocked) do
			if path:find(pattern) then
				return false
			end
		end
		return true
	end,
})
