local M = {}

M.read_file_sync = function(path)
  local fd = assert(vim.loop.fs_open(path, "r", 438))
  local stat = assert(vim.loop.fs_fstat(fd))
  local data = assert(vim.loop.fs_read(fd, stat.size, 0))
  assert(vim.loop.fs_close(fd))
  return data
end

M.get_parser = function(result_header)
  -- TODO: do this correctly
  local ext_to_type = {}
  ext_to_type[".lua"] = "lua"
  ext_to_type[".rs"] = "rust"
  ext_to_type[".md"] = "markdown"
  ext_to_type[".vim"] = "vim"

  local ext = result_header:match "^.+(%..+)$"
  local ft = ext_to_type[ext]
  if ft == nil then
    ft = ext:sub(2, -1)
  end

  return ft
end

return M
