local api = vim.api
local Window = require("window")

Layout = {}

function Layout:new()
  local new_obj = {
    results_window = nil,
    entry_header_window = nil,
    input_window = nil,
    hud_window = nil,
  }
  self.__index = self
  return setmetatable(new_obj, self)
end

function Layout:set_entry_header_window(entry_header_window)
  self.entry_header_window = entry_header_window
  return self
end

function Layout:set_results_window(results_window)
  self.results_window = results_window
  return self
end

function Layout:set_input_window(input_window)
  self.input_window = input_window
  return self
end

function Layout:set_hud_window(hud_window)
  self.hud_window = hud_window
  return self
end

function Layout:render()
  local columns = api.nvim_get_option("columns")
  local lines = api.nvim_get_option("lines")

  local entry_header_width = 6
  local entry_header_border_width = 2

  -- results window
  local results_line_percent = 0.6
  local results_pos_x = entry_header_width + entry_header_border_width
  local results_pos_y = math.max(math.floor(results_line_percent * lines), 1)
  local results_height = lines - results_pos_y - 1

  self.results_window
      :set_pos(results_pos_x, results_pos_y)
      :set_dimensions(columns - results_pos_x, results_height)
      :render()

  self.entry_header_window
      :set_pos(0, results_pos_y)
      :set_dimensions(entry_header_width, results_height)
      :render()

  -- input window
  local input_border_chars = 4
  local input_pos_y = results_pos_y - input_border_chars
  local input_width = math.max(math.floor(0.35 * columns), 1)
  local input_height = 2

  self.input_window
      :set_pos(0, input_pos_y)
      :set_dimensions(input_width, input_height)
      :render()

  local hud_width = columns - input_width - 2
  self.hud_window
      :set_pos(input_width + input_border_chars, input_pos_y)
      :set_dimensions(hud_width, input_height)
      :render()

  return self
end

return Layout
