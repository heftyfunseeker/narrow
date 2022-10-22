local api = vim.api

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
    },
    buf = nil,
    win = nil,
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

-- performs a shallow copy of the config with final layout values calculated
function Window:get_config()
  local config = {}

  for k, v in pairs(self.win_options) do
    config[k] = v
  end

  local columns = api.nvim_get_option("columns")
  local lines = api.nvim_get_option("lines")

  -- transform any percentage attributes to final line/col values
  if config.width <= 1 then
    config.width = math.floor(config.width * columns)
  end

  if config.col <= 1 then
    config.col = math.floor(config.col * columns)
  end

  if config.height <= 1 then
    config.height = math.floor(config.height * lines)
  end

  if config.row <= 1 then
    config.row = math.floor(config.row * lines)
  end

  return config
end

function Window:build()
  local buffer = api.nvim_create_buf(false, true)
  for option_name, option_value in pairs(self.buf_options) do
    api.nvim_buf_set_option(buffer, option_name, option_value)
  end

  local window = api.nvim_open_win(buffer, true, self:get_config())

  self.buf = buffer
  self.win = window

  return self
end

function Window:resize()
  api.nvim_win_set_config(self.win, self:get_config())
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
