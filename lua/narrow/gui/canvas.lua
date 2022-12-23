local Style = require("narrow.gui.style")

local Canvas = {}

function Canvas:new(window)
  local new_obj = {
    window = window,
    lines = {},
    num_rows = 0,
    selectable_text_blocks = {}
  }
  self.__index = self
  return setmetatable(new_obj, self)
end

function Canvas:render(only_styles)

end

function Canvas:write(text_block)
  for _, line in ipairs(text_block) do
    -- adjust highlights from local text_block row to canvas row
    for _, hl in ipairs(line.highlights) do
      hl.pos.row = self.num_rows
    end

    for _, on_selected in ipairs(line.on_selected) do
      on_selected.pos.row = self.num_rows
    end

    table.insert(self.lines, line)

    self.num_rows = self.num_rows + 1
  end
end

function Canvas:render_new()
  local window_lines = {}
  for _, line in ipairs(self.lines) do
    table.insert(window_lines, line.text)
  end

  self.window:set_lines(window_lines)

  for _, line in ipairs(self.lines) do
    for _, hl in ipairs(line.highlights) do
      self.window:add_highlight(hl.hl_name, hl.pos)
    end
  end
end

-- @todo: lets have the canvas cache all used namespaces to do this book keeping for us
function Canvas:clear()
  self.lines = {}
  self.num_rows = 0

  self.selectable_text_blocks = {}
end

function Canvas:select_at_cursor()
  local cursor = self.window:get_cursor_location()
  local row = cursor[1]
  local col = cursor[2]

  local line = self.lines[row]
  if not line then return nil end

  for _, selectable in ipairs(line.on_selected) do
    if selectable.pos.col_start <= col and selectable.pos.col_end > col then
      return selectable.on_selected()
    end
  end

  return nil
end

function Canvas:get_dimensions()
  return self.window:get_dimensions()
end

return Canvas
