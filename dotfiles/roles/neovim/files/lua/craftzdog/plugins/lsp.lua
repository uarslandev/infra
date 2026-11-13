require("mason").setup()
require("mason-tool-installer").setup({
	ensure_installed = {
		"tree-sitter-cli",
		"lua-language-server",
		"prettier",
		"prettierd",
		"selene",
		"shellcheck",
		"shfmt",
		"stylua",
		"eslint-lsp",
		"oxlint",
		"oxfmt",
		"tailwindcss-language-server",
		"vtsls",
		"copilot-language-server",
		"rust-analyzer",
		-- infra: our languages on top of craftzdog's list
		"gopls",
		"ansible-language-server",
		"bash-language-server",
		"dockerfile-language-server",
		"json-lsp",
		"css-lsp",
		"powershell-editor-services",
		"solargraph",
		"terraform-ls",
		"yaml-language-server",
		"pyright",
		"ruff",
		"astro-language-server",
		"graphql-language-service-cli",
		"svelte-language-server",
	},
	auto_update = false,
	run_on_start = true,
})

local capabilities = {
	workspace = {
		fileOperations = {
			didRename = true,
			willRename = true,
		},
	},
}
vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(capabilities),
})

-- infra: our languages on top of craftzdog's list.
-- TypeScript is served by vtsls (his choice), so ts_ls stays off.
local lsp_servers = {
	"gopls",
	"ansiblels",
	"bashls",
	"dockerls",
	"jsonls",
	"powershell_es",
	"solargraph",
	"terraformls",
	"yamlls",
	"pyright",
	"ruff",
	"astro",
	"graphql",
	"svelte",
}
vim.lsp.enable(lsp_servers)

vim.lsp.enable({
	"eslint",
	"oxlint",
	"lua_ls",
	"cssls",
	"vtsls",
	"tailwindcss",
	"glsl_analyzer",
	"rust_analyzer",
})
