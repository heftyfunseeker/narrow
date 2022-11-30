local api = vim.api

-- this is really a canvas, or the actual draw api :P
local Window = {}
Window.__index = Window

local namespace_id = api.nvim_create_namespace("narrow/window")
local entry_namespace_id = api.nvim_create_namespace("narrow/window/entry")

function Window:new()


  local new_obj = {
    buf_options = {},
    win_options = {},
    win_config = {
      style = "minimal",
      relative = "editor",
      width = -1,
      height = -1,
      row = -1,
      col = -1,
    },
    buf = nil,
    win = nil,
  }

  return setmetatable(new_obj, self)
end

function Window:drop()
  if api.nvim_buf_is_valid(self.buf) then
    api.nvim_buf_delete(self.buf, { force = true })
  end
  self.buf = nil
  self.window = nil
end

function Window:set_pos(col, row)
  self.win_config.col = col
  self.win_config.row = row
  return self
end

function Window:set_dimensions(width, height)
  self.win_config.width = width
  self.win_config.height = height
  return self
end

function Window:get_dimensions()
  return self.win_config.width, self.win_config.height
end

function Window:set_border(border)
  self.win_config.border = border
  return self
end

function Window:set_buf_option(option_name, option_value)
  self.buf_options[option_name] = option_value
  return self
end

function Window:set_win_option(option_name, option_value)
  self.win_options[option_name] = option_value
  return self
end

function Window:set_window_highlights(normal_float, float_border)
  self.normal_float = normal_float
  self.float_border = float_border
  return self
end

function Window:get_config()
  return self.win_config
end

function Window:render()
  if self.buf and self.win then
    api.nvim_win_set_config(self.win, self:get_config())
    return
  end

  local buffer = api.nvim_create_buf(false, true)
  for option_name, option_value in pairs(self.buf_options) do
    api.nvim_buf_set_option(buffer, option_name, option_value)
  end

  local window = api.nvim_open_win(buffer, true, self:get_config())
  for option_name, option_value in pairs(self.win_options) do
    api.nvim_win_set_option(window, option_name, option_value)
  end

  self.buf = buffer
  self.win = window

  if self.normal_float and self.float_border then
    local window_ns = api.nvim_create_namespace("narrow-result-window")
    api.nvim_set_hl(window_ns, "FloatBorder", { link = self.float_border })
    api.nvim_set_hl(window_ns, "NormalFloat", { link = self.normal_float })
    api.nvim_win_set_hl_ns(window, window_ns)
  end

  return self
end

function Window:set_lines(lines)
  self.lines = lines
  api.nvim_buf_set_lines(self.buf, 0, -1, true, lines)
end

function Window:clear(additional_namespaces, only_namespaces)
  api.nvim_buf_clear_namespace(self.buf, namespace_id, 0, -1)
  api.nvim_buf_clear_namespace(self.buf, entry_namespace_id, 0, -1)

  if additional_namespaces == nil then return end

  for _, namespace in ipairs(additional_namespaces) do
    api.nvim_buf_clear_namespace(self.buf, namespace, 0, -1)
  end

  if not only_namespaces then
    api.nvim_buf_set_lines(self.buf, 0, -1, true, {})
  end
end

-- returns the lines that were used in the last call to set_lines
-- use get_buffer_lines to get currently drawn lines
function Window:get_lines()
  return self.lines
end

function Window:get_buffer_lines(start_line, end_line)
  return api.nvim_buf_get_lines(self.buf, start_line, end_line, true)
end

function Window:add_highlight(hl_name, pos)
  -- @todo: namespaces
  api.nvim_buf_add_highlight(self.buf, -1, hl_name, pos.row, pos.col_start, pos.col_end)
end

function Window:add_virtual_text(text, hl_name, pos)
  local opts = {
    virt_text = { { text, hl_name } },
    virt_text_pos = pos.pos_type,
    strict = false,
    virt_text_win_col = pos.col,
  }
  api.nvim_buf_set_extmark(self.buf, namespace_id, pos.row, pos.col, opts)
end

function Window:add_entry(entry_id, pos, namespace)
  if namespace == nil then
    namespace = entry_namespace_id
  end

  local opts = {
    virt_text = {},
    id = entry_id,
    virt_text_pos = "overlay",
    strict = false,
  }
  api.nvim_buf_set_extmark(self.buf, namespace, pos.row, 0, opts)
end

-- List of [extmark_id, row, col] tuples in "traversal order".
function Window:get_entry_at_cursor(namespace)
  if namespace == nil then
    namespace = entry_namespace_id
  end

  local row = api.nvim_win_get_cursor(self.win)[1] - 1
  return self:get_entry_at_row(row, namespace)
end

function Window:get_entry_at_row(row, namespace)
  if namespace == nil then
    namespace = entry_namespace_id
  end

  local entries = api.nvim_buf_get_extmarks(self.buf, namespace, { row, 0 }, { row, -1 }, { limit = 1 })
  return entries[1]
end

function Window:get_all_entries(namespace)
  if namespace == nil then
    namespace = entry_namespace_id
  end

  -- we could eventually support entry
  return api.nvim_buf_get_extmarks(self.buf, namespace, 0, -1, {})
end

return Window
