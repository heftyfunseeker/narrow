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

  local window = api.nvim_open_win(buffer, true, self.win_options)

  return buffer, window
end

Window.new_results_window = function()
  local window = Window:new(
    math.floor(columns),
    math.floor(lines * .5 - 3),
    math.floor(lines * .5) + 1,
    0
  )

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border({ "", "", "", "│", "╯", "─", "╰", "│", })
      :build()
end

Window.new_hud_window = function()
  local window = Window:new(math.floor(columns) - 50, 2, math.floor(lines * .5) - 2, 50)

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border({ "", "─", "╮", "│", "", "", "", "", })
      :build()
end

Window.new_input_window = function()
  local window = Window:new(50, 2, math.floor(lines * .5) - 2, 0)

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "prompt")
      :set_buf_option("swapfile", false)
      :set_border({ "╭", "─", "", "", " ", "", "", "│" })
      :build()
end

Window.new_preview_window = function()
  local window = Window:new(
    math.floor(columns * .4) - 2,
    math.floor(lines * .5 - 3),
    math.floor(lines * .5),
    math.floor(columns * .6) + 1
  )

  return window
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border("solid")
      :build()
end

-- 1. let's create a window class that saves the hardcoded width height position properties
--
-- function Window:resize(win)
--   local win_config = api.nvim_win_get_config(win)
-- end

return Window
