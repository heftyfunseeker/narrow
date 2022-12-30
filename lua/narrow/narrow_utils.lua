local M = {
  array = {}
}


M.string_to_lines = function(str)
  local vals = vim.split(str, "\n")
  local lines = {}
  for _, line in pairs(vals) do
    table.insert(lines, line)
  end
  return lines
end

M.read_file_sync = function(path)
  local fd = assert(vim.loop.fs_open(path, "r", 438))
  local stat = assert(vim.loop.fs_fstat(fd))
  local data = assert(vim.loop.fs_read(fd, stat.size, 0))
  assert(vim.loop.fs_close(fd))
  return data
end

M.write_file_sync = function(path, data)
  local fd = assert(vim.loop.fs_open(path, "w", 438))
  local stat = assert(vim.loop.fs_fstat(fd))
  local data = assert(vim.loop.fs_write(fd, data))
  assert(vim.loop.fs_close(fd))
  return data
end

M.get_file_extension = function(file_path)
  if file_path == nil then
    return nil
  end
  local ext = file_path:match("^.+(%..+)$")
  if ext then
    ext:sub(2)
  end
end

-- @ret index of element, -1 if not found
M.array.index_of = function(array, target)
  for i, curr in ipairs(array) do
    if curr == target then
      return i
    end
  end
  return -1
end

M.array.shallow_copy = function(source)
  local copy = {}
  for k, v in pairs(source) do
    copy[k] = v
  end

  return copy
end

local function _clone(source, target)
  for k, v in pairs(source) do
    if type(v) == "table" then
      target[k] = {}
      _clone(v, target[k])
    else
      target[k] = v
    end
  end
end

M.array.clone = function(source)
  local target = {}
  _clone(source, target)
  return target
end

M.hl_string = function(str, ft)
  --@todo use this to check for parser availability
  -- local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")
  local parser = vim.treesitter.get_string_parser(str, ft)
  local tree = parser:parse()[1]

  local query = vim.treesitter.get_query(ft, "highlights")

  local hl_infos = {}
  for id, node, _ in query:iter_captures(tree:root(), str, 0, 1) do
    local hl_name = "@" .. query.captures[id] -- name of the capture in the query
    local row1, col1, row2, col2 = node:range() -- range of the capture
    if hl_name ~= "@spell" and hl_name ~= "@error" then
      table.insert(hl_infos, { hl_name = hl_name, pos = { row1 = row1, col1 = col1, row2 = row2, col2 = col2 } })
    end
  end

  return hl_infos
end

return M
