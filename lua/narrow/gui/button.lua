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
    if self.width < vim.fn.strdisplaywidth(self.text.text) then
      local padding = 2
      self.width = vim.fn.strdisplaywidth(self.text.text) + padding
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
      :set_text("│")
      :set_pos(self.col, self.row + 1)
      :apply_style(self.style)
      :render(canvas)

  if self.text then
    self.text
      :set_pos(self.col + 1, self.row + 1)
      :render(canvas)
  end

  local text_len = 0
  if self.text and self.text.text then
    text_len = vim.fn.strdisplaywidth(self.text.text)
  end

  Text:new()
      :set_text("│")
      :set_pos(self.col + text_len + 1, self.row + 1)
      :apply_style(self.style)
      :render(canvas)

  Text:new()
      :set_text(bottom)
      :set_pos(self.col, self.row + 2)
      :apply_style(self.style)
      :render(canvas)

  -- render button text
end

return Button
