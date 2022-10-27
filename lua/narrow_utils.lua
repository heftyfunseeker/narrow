local M = {}


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

M.get_parser = function(result_header)
  -- TODO: do this correctly
  local ext_to_type = {}
  ext_to_type[".lua"] = "lua"
  ext_to_type[".rs"] = "rust"
  ext_to_type[".md"] = "markdown"
  ext_to_type[".vim"] = "vim"

  local ext = M.get_file_extension(result_header)
  local ft = ext_to_type[ext]
  if ft == nil then
    ft = ext:sub(2, -1)
  end

  return ft
end

M.hl_buffer = function(state, result_header)
  local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")
  local ft_parser = nil
  local ft = M.get_parser(result_header)
  if ts_parsers.has_parser(ft) then
    ft_parser = vim.treesitter._create_parser(state.results_buf, ft)
  end
  if ft_parser ~= state.current_parser then
    if state.current_hl then
      state.current_hl:destroy()
      state.current_hl = nil
    end
    state.current_parser = ft_parser
  end

  if ft_parser then
    state.current_hl = vim.treesitter.highlighter.new(ft_parser)
  else
    vim.api.nvim_buf_set_option(state.preview_buf, "syntax", ft)
  end
end

M.hl_results = function(state, result_header)
  local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")
  local ft_parser = nil
  local ft = M.get_parser(result_header)
  if ts_parsers.has_parser(ft) then
    ft_parser = vim.treesitter._create_parser(state.results_buf, ft)
  end
  if ft_parser ~= state.current_parser then
    if state.current_hl then
      state.current_hl:destroy()
      state.current_hl = nil
    end
    state.current_parser = ft_parser
  end

  if ft_parser then
    state.current_hl = vim.treesitter.highlighter.new(ft_parser)
  else
    vim.api.nvim_buf_set_option(state.preview_buf, "syntax", ft)
  end
end

return M
