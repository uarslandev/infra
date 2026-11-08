-- infra: carried over from the previous config
---@type vim.lsp.Config
return {
	settings = {
		ansible = {
			diagnostics = {
				disable = { "name[template]" },
			},
		},
	},
}
