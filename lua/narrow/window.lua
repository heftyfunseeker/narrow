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

function Window:set_z_index(z_index)
  self.win_config.zindex = z_index
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

  if self.buf then
    api.nvim_buf_set_option(self.buf, option_name, option_value)
  end

  return self
end

function Window:set_win_option(option_name, option_value)
  self.win_options[option_name] = option_value

  if self.win then
    api.nvim_win_set_option(self.win, option_name, option_value)
  end

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

  return self
end

function Window:set_lines(lines, start_line, end_line)
  self.lines = lines
  if not start_line then start_line = 0 end
  if not end_line then end_line = -1 end

  api.nvim_buf_set_lines(self.buf, start_line, end_line, true, lines)
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

-- pos: { row, col_start, col_end }
function Window:add_highlight(hl_name, pos)
  -- @todo: namespaces
  if not pos then return end
  api.nvim_buf_add_highlight(self.buf, -1, hl_name, pos.row, pos.col_start, pos.col_end)
end

-- pos: { pos_type, col }
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

function Window:get_cursor_location()
  return api.nvim_win_get_cursor(self.win)
end

function Window:has_focus()
  return api.nvim_get_current_win() == self.win
end

function Window:set_focus()
  return api.nvim_set_current_win(self.win)
end

return Window
