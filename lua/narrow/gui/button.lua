local Text = require("narrow.gui.text")

local Button = {}
Button.__index = Button

-- string id used for input handling
function Button:new()
  local new_obj = {
    text = nil,
    style = nil,
    alignment_type = nil,
    row = -1,
    col = -1,
    width = 0,
    height = 1,
    -- use to mark this as a selectable entry
    entry_id = nil
  }
  return setmetatable(new_obj, self)
end

-- a Text component
function Button:set_text(text)
  self.text = text

  return self
end

function Button:set_pos(col, row)
  self.col = col
  self.row = row

  return self
end

function Button:set_dimensions(width, height)
  self.width = width
  self.height = height

  return self
end

function Button:apply_style(style)
  self.style = style

  return self
end

function Button:render(canvas)
  if self.text then
    -- adjust width if not wide enough
    if self.width < string.len(self.text.text) then
      local padding = 4
      self.width = string.len(self.text.text) + padding
    end
  end

  -- render border
  local top = "╭" .. string.rep("─", self.width - 2) .. "╮"
  local bottom = "╰" .. string.rep("─", self.width - 2) .. "╯"
  Text:new()
      :set_text(top)
      :set_pos(self.col, self.row)
      :apply_style(self.style)
      :render(canvas)

  Text:new()
      :set_text(bottom)
      :set_pos(self.col, self.row + self.height + 1)
      :apply_style(self.style)
      :render(canvas)

  for row = 1, self.height do
    local middle = "│" .. string.rep(" ", self.width - 2) .. "│"
    Text:new()
        :set_text(middle)
        :set_pos(self.col, self.row + row)
        :apply_style(self.style)
        :render(canvas)
  end

  -- render button text
  if self.text then
    self.text
        :set_pos(self.col + 2, self.row + 1)
        :set_dimensions(self.width - 2, 1)
        :set_alignment(Text.AlignmentType.center)
        :render(canvas)
  end
end

return Button
