-- local root = debug.getinfo(1).source:sub(2, -21)
local root = vim.fn.stdpath("cache") .. "/colorcache/"
if vim.fn.isdirectory(root) == 0 then
	vim.fn.mkdir(root)
end
P(debug.getinfo(1).source:sub(2, -21))

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
		path = root .. name .. ".vim"
		vim.api.nvim_set_hl = function(id, group, opts)
			if cache[name] == nil then
				cache[name] = {}
			end
			table.insert(cache[name], string.format("vim.api.nvim_set_hl(%s, %s, %s)", id, group, inspect(opts)))
			hl(id, group, opts)
			cnt = cnt + 1
		end
	end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
	callback = function()
		vim.api.nvim_set_hl = hl
		P(cache[name])
		print(path)
		local file = io.open(path, "wb")
		if file then
			file:write(table.concat(cache[name], "\n"))
			file:close()
		end
		cache[name] = {}
		cnt = 0
	end,
})

vim.api.nvim_create_user_command("Coc", function()
	print(root)
end, {})
