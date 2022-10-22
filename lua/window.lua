local api = vim.api

local columns = api.nvim_get_option("columns")
local lines = api.nvim_get_option("lines")

Window = {}

function Window:new(width, height, row, col)
  local new_obj = {
    buf_options = {},
    win_options = {
      style = "minimal",
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      noautocmd = true,
    },
  }
  self.__index = self
  return setmetatable(new_obj, self)
end

function Window:set_border(border)
  self.win_options.border = border
  return self
end

function Window:set_buf_option(option_name, option_value)
  self.buf_options[option_name] = option_value
  return self
end

function Window:build()
  local buffer = api.nvim_create_buf(false, true)
  for option_name, option_value in pairs(self.buf_options) do
    api.nvim_buf_set_option(buffer, option_name, option_value)
  end

  -- adjust percentage based dimension
  local width = self.win_options.width
  local height = self.win_options.height
  local row = self.win_options.row
  local col = self.win_options.col

  if width <= 1 then
    self.win_options.width = math.floor(width * columns)
  end
  if col <= 1 then
    self.win_options.col = math.floor(col * columns)
  end

  if height <= 1 then
    self.win_options.height = math.floor(height * lines)
  end
  if row <= 1 then
    self.win_options.row = math.floor(row * lines)
  end

  local window = api.nvim_open_win(buffer, true, self.win_options)

  -- restore original width and height if needed
  -- I'll just end up writing a shallow copy if this pattern balloons
  self.win_options.height = height
  self.win_options.width = width
  self.win_options.col = col
  self.win_options.row = row

  return buffer, window
end

Window.new_results_window = function()
  local window = Window:new(1, .4, .6, 0)

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border({ "", "", "", "│", "╯", "─", "╰", "│", })
      :build()
end

Window.new_hud_window = function()
  local window = Window:new(.65, 2, .52, .35)

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border({ "", "─", "╮", "│", "", "", "", "", })
      :build()
end

Window.new_input_window = function()
  local window = Window:new(.35, 2, .52, 0)

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "prompt")
      :set_buf_option("swapfile", false)
      :set_border({ "╭", "─", "", "", " ", "", "", "│" })
      :build()
end

return Window
