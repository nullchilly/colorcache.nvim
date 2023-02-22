local M = {}

local root = vim.fn.stdpath("cache") .. "/colorcache"
vim.opt.rtp:prepend(root)
local colors_root = root .. "/colors/"
local cache_root = root .. "/cache/"

local function ensure(path)
  if vim.fn.isdirectory(path) == 0 then
    vim.fn.mkdir(path, "p")
  end
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
        table.insert(cache[name], string.format([[vim.api.nvim_set_hl(%s, "%s", %s)]], id, group, inspect(opts)))
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
  if lock then
    return
  end
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
