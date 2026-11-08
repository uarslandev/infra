-- infra: filetype rules carried over from the previous config.
-- Kept apart from craftzdog's modules so those stay easy to diff against upstream.

vim.filetype.add({
	extension = {
		tfvars = "terraform",
		tfstate = "json",
		tfplan = "json",
	},
	filename = {
		[".justfile"] = "just",
		["justfile"] = "just",
		["Justfile"] = "just",
	},
	pattern = {
		-- Ansible by location: roles, playbooks, inventories' vars
		[".*/tasks/.*%.ya?ml"] = "yaml.ansible",
		[".*/handlers/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/defaults/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/roles/.*/meta/main%.ya?ml"] = "yaml.ansible",
		[".*/group_vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/host_vars/.*%.ya?ml"] = "yaml.ansible",
		[".*/playbooks/.*%.ya?ml"] = "yaml.ansible",
		[".*/requirements%.ya?ml"] = "yaml.ansible",
	},
})

-- Ansible by content: upgrade plain YAML that looks like a playbook or task list
local ansible_markers = {
	"^%s*-?%s*hosts:",
	"ansible%.builtin%.",
	"ansible%.posix%.",
	"^%s+become:",
	"^%s+notify:",
	"^%s+register:",
	"^%s+changed_when:",
	"^%s+failed_when:",
}

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("InfraAnsibleDetect", { clear = true }),
	pattern = "yaml",
	callback = function(ev)
		for _, line in ipairs(vim.api.nvim_buf_get_lines(ev.buf, 0, 50, false)) do
			for _, marker in ipairs(ansible_markers) do
				if line:match(marker) then
					vim.bo[ev.buf].filetype = "yaml.ansible"
					return
				end
			end
		end
	end,
})
