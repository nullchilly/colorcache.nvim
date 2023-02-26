local M = {}

local root = vim.fn.stdpath "cache" .. "/colorcache"
vim.opt.rtp:prepend(root)
-- vim.opt.rtp:remove(root)
local colors_root = root .. "/colors/"
local cache_root = root .. "/cache/"

local function ensure(path)
	if vim.fn.isdirectory(path) == 0 then vim.fn.mkdir(path, "p") end
end
ensure(colors_root)
ensure(cache_root)

local function file_exists(name)
	local f = io.open(name, "r")
	return f ~= nil and io.close(f)
end

local function write(path, content)
	local file = io.open(path, "wb")
	if file then
		file:write(content)
		file:close()
	end
end

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

local exists

vim.api.nvim_create_augroup("FastColor", { clear = true })
vim.api.nvim_create_autocmd("ColorSchemePre", {
	group = "FastColor",
	callback = function(O)
		-- vim.cmd([[highlight clear]])
		-- vim.g.colors_name = nil
		name = O.match
		local cache_path = cache_root .. name
		exists = file_exists(cache_path)
		if not exists then
			vim.api.nvim_set_hl = function(id, group, opts)
				if cache[name] == nil then
					cache[name] = {
						string.format(
							[[
return string.dump(function()
if vim.g.colors_name then vim.cmd("hi clear") end
vim.o.termguicolors = true
vim.g.colors_name = "%s"
vim.g.background = "dark"]],
							name,
							name
						),
					}
				end
				-- table.insert(
				-- 	cache[name],
				-- 	string.format([[vim.api.nvim_set_hl(%s, "%s", %s)]], id, group, inspect(opts))
				-- )
				hl(id, group, opts)
				cnt = cnt + 1
			end
		end
	end,
})

vim.api.nvim_create_autocmd("ColorScheme", {
	group = "FastColor",
	callback = function()
		if not exists then
			vim.api.nvim_set_hl = hl
			if #cache[name] < 100 then -- Somehow bufferline got in the way?
				print "vimscript"
				local now = vim.loop.hrtime
				local start = now()
				local s = vim.fn.execute "verbose hi"
				local i = 1
				-- SpecialKey     xxx ctermfg=238 guifg=#475258\n\tLast set from ~/.local/share/nvim/lazy/everforest/autoload/everforest.vim line 170\n
				local len = #s
				while i <= len do
					i = i + 1

					-- Highlight name
					local hlgroup = ""
					while i <= len do
						local cur = string.sub(s, i, i)
						if cur == " " then break end
						hlgroup = hlgroup .. cur
						i = i + 1
						-- print(i)
					end
					-- print("Group: " .. hlgroup)

					-- Options list
					while true do
						i = i + 1
						local cur = string.sub(s, i, i)
						if cur == "x" then
							i = i + 3
							break
						end
					end

					local key
					local cleared
					local opts = {}
					local args = ""
					while i <= len do
						i = i + 1
						local cur = string.sub(s, i, i)
						if cur == " " or cur == "\n" then
							if args == "cleared" then
								-- print("Cleared: " .. hlgroup)
								cleared = true
								break
							elseif args == "links" then
								i = i + 2
								break
							end
							print(key, args)
							local switch = {
								guifg = function() opts.fg = args end,
								guibg = function() opts.bg = args end,
								guisp = function() opts.sp = args end,
								ctermfg = function() opts[key] = tonumber(args) end,
								ctermbg = function() opts[key] = tonumber(args) end,
								blend = function() opts[key] = tonumber(args) end,
								cterm = function()
									if args == "" then return end
									vim.pretty_print(args)
									args = vim.split(args, ",")
									opts.cterm = {}
									for _, style in ipairs(args) do
										-- if style == "reverse" then
										-- 	opts.cterm[1] = "reverse"
										-- 	break
										-- else
										opts.cterm[style] = true
										-- end
									end
								end,
								gui = function()
									if args == "" then return end
									args = vim.split(args, ",")
									for _, style in ipairs(args) do
										opts[style] = true
									end
								end,
							}
							local f = switch[key]
							if f then
								f()
							elseif key then
								opts[key] = args
							end
							if cur == "\n" then break end
							args = ""
						elseif cur == "=" then
							key = args
							args = ""
						else
							args = args .. cur
						end
					end

					-- Highlight link
					local link = ""
					if string.sub(s, i + 1, i + 1) == " " then
						while i <= len do
							i = i + 1
							local cur = string.sub(s, i, i)
							if cur == "\n" then break end
							link = link .. cur
							if cur == " " then link = "" end
						end
						-- print("Link: " .. link)
					end

					-- Last set from
					local src = ""
					if string.sub(s, i + 1, i + 1) == "\t" then
						while i <= len do
							i = i + 1
							local cur = string.sub(s, i, i)
							if cur == "\n" then break end
							src = src .. cur
						end
						-- print("Source: " .. src)
					end

					if not cleared then
						-- print(hlgroup)
						-- if hlgroup == "gitcommitSelectedType" then
						-- 	break
						-- end
						if link ~= "" then opts = { link = link } end
						table.insert(
							cache[name],
							string.format([[vim.api.nvim_set_hl(%s, "%s", %s)]], 0, hlgroup, vim.inspect(opts))
						)
						print(hlgroup .. " " .. inspect(opts) .. " " .. src)
					end
				end
				print((now() - start) / 1000000)
			end
			table.insert(cache[name], "end)")
			local cache_path = cache_root .. name
			local colors_path = colors_root .. name .. ".vim"

			write(cache_path .. ".lua", table.concat(cache[name], "\n"))
			write(cache_path, loadstring(table.concat(cache[name], "\n"), "=")())
			write(colors_path, string.format([[lua require("fastcolor").load("%s")]], name))
		end
	end,
})

function M.compile() end

local lock = false -- Avoid g:colors_name reloading

function M.load(colorscheme)
	if lock then return end
	print("Loading from fastcolor: ", colorscheme)
	local compiled_path = cache_root .. colorscheme
	lock = true
	local f = loadfile(compiled_path)
	if not f then
		M.compile()
		f = loadfile(compiled_path)
	end
	---@diagnostic disable-next-line: need-check-nil
	f()
	lock = false
end

return M
