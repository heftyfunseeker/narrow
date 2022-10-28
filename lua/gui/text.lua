local Style = require("gui.style")

Text = {}
Text.__index = Text

function Text:new()
  local new_obj = {
    text = nil,
    style = nil,
    row = -1,
    col = -1,
    width = 0,
    height = 0,
    -- use to mark this as a selectable entry
    entry = nil
  }
  return setmetatable(new_obj, self)
end

function Text:set_text(text)
  self.text = text
  return self
end

function Text:apply_style(style_type, hl_name)
  local style = nil
  if style_type == Style.types.highlight then
    local hl_pos = {
      row = self.row,
      col_start = self.col,
      col_end = string.len(self.text)
    }
    style = Style:new_hl(hl_name, hl_pos)
  else
    local virtual_text_pos = {
      row = self.row,
      col = self.col,
    }
    style = Style:new_virtual_text(self.text, hl_name, virtual_text_pos)
  end

  self.style = style

  return self
end

function Text:set_pos(col, row)
  self.col = col
  self.row = row

  return self
end

function Text:set_dimensions(width, height)
  self.width = width
  self.height = height

  return self
end

function Text:mark_entry(entry_id)
  self.entry = {
    id = entry_id,
    pos = {
      col = self.col,
      row = self.row
    }
  }
  return self
end

function Text:render(canvas)
  local is_virtual_text = false

  if self.style ~= nil then
    is_virtual_text = self.style.type == Style.types.virtual_text
    canvas:add_style(self.style)
  end

  if is_virtual_text == false then
    canvas:add_text(self.text, self.col, self.row)
  end

  if self.entry ~= nil then
    canvas:add_entry(self.entry)
  end
end

return Text
