-- local root = debug.getinfo(1).source:sub(2, -21)
local root = vim.fn.stdpath("cache") .. "/colorcache"
vim.opt.rtp:prepend(root)
root = root .. "/colors/"
if vim.fn.isdirectory(root) == 0 then
	vim.fn.mkdir(root)
end
-- P(debug.getinfo(1).source:sub(2, -21))

local hl = vim.api.nvim_set_hl
local cnt = 0
local cache = {}
local name

local function inspect(t)
	local list = {}
	for k, v in pairs(t) do
		local q = type(v) == "string" and [["]] or ""
		table.insert(list, string.format([[%s = %s%s%s]], k, q, tostring(v), q))
	end
	return string.format([[{ %s }]], table.concat(list, ", "))
end

local path

vim.api.nvim_create_autocmd("ColorSchemePre", {
	callback = function(O)
		name = O.match
		path = root .. name
		local file = io.open(path .. ".vim", "wb")
		if file then
			file:write([[require("fastcolor").load()]])
			file:close()
		end
		vim.api.nvim_set_hl = function(id, group, opts)
			if cache[name] == nil then
				cache[name] = {
					string.format(
						[[
return string.dump(function()
if vim.g.colors_name then vim.cmd("hi clear") end
vim.o.termguicolors = true
vim.g.colors_name = "%s"
vim.o.background = "dark"]],
						name
					),
				}
			end
			table.insert(cache[name], string.format([[vim.api.nvim_set_hl(%s, "%s", %s)]], id, group, inspect(opts)))
			hl(id, group, opts)
			cnt = cnt + 1
		end
	end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		vim.api.nvim_set_hl = hl
		print(path)
		table.insert(cache[name], "end)")

		local file = io.open(path, "wb")

		if vim.g.fastcolor_debug then -- Debugging purpose
			local deb = io.open(path .. ".lua", "wb")
			deb:write(table.concat(cache[name], "\n"))
			deb:close()
		end

		if file then
			local f = loadstring(table.concat(cache[name], "\n"), "=")
			file:write(f(), "\n")
			file:close()
		end
		cache[name] = {}
		cnt = 0
	end,
})

vim.api.nvim_create_user_command("Coc", function()
	print(root)
end, {})
