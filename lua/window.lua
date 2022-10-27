local api = vim.api

Window = {}

function Window:new()
  local new_obj = {
    buf_options = {},
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
  self.__index = self
  return setmetatable(new_obj, self)
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

function Window:set_border(border)
  self.win_config.border = border
  return self
end

function Window:set_buf_option(option_name, option_value)
  self.buf_options[option_name] = option_value
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

  self.buf = buffer
  self.win = window

  return self
end

function Window:set_lines(start_line, end_line, replacement)
  api.nvim_buf_set_lines(self.buf, start_line, end_line, true, replacement)
end

function Window:get_lines(start_line, end_line)
  return api.nvim_buf_get_lines(self.buf, start_line, end_line, true)
end

return Window
