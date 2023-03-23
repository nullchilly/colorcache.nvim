local root = vim.fn.stdpath "cache" .. "/colorcache"
vim.opt.rtp:prepend(root)
local colors_root = root .. "/colors/"
if vim.fn.isdirectory(colors_root) == 0 then vim.fn.mkdir(colors_root, "p") end

vim.api.nvim_create_augroup("colorcache", { clear = true })

local default_groups

vim.api.nvim_create_autocmd("ColorSchemePre", {
	group = "colorcache",
	callback = function()
		vim.cmd [[hi clear]]
		default_groups = vim.api.nvim_get_hl and vim.api.nvim_get_hl(0, {}) or vim.api.nvim__get_hl_defs(0)
	end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
	group = "colorcache",
	callback = function(opts)
		local colors_name = opts.match
		if colors_name:match "_cache" then return end
		local f = io.open(colors_root, "r")
		if f then
			f:close()
			local lines = {
				string.format(
					[[
if vim.g.colors_name then vim.cmd("hi clear") end
vim.o.termguicolors = true
vim.g.background = "%s"
vim.g.colors_name = "%s"]],
					vim.o.background,
					colors_name
				),
			}
			if vim.api.nvim_get_hl then
				local groups = vim.api.nvim_get_hl(0, {})
				for group, color in pairs(groups) do
					local val = vim.inspect(color)
					if not (val == vim.inspect(default_groups[group])) then
						table.insert(lines, string.format([[vim.api.nvim_set_hl(0, "%s", %s)]], group, val))
					end
				end
			else
				local groups = vim.api.nvim__get_hl_defs(0)
				for group, color in pairs(groups) do
					local val = vim.inspect(color)
					if not (val == vim.inspect(default_groups[group])) and not color[true] then
						table.insert(lines, string.format([[vim.api.nvim_set_hl(0, "%s", %s)]], group, val))
					end
				end
			end

			local colors_path = colors_root .. colors_name .. "_cache.lua"

			f = io.open(colors_path, "wb")
			if f then
				f:write(table.concat(lines, "\n"))
				f:close()
			end
		end
	end,
})
