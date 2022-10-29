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
    entry_id = nil
  }
  return setmetatable(new_obj, self)
end

function Text:set_text(text)
  self.text = text
  return self
end

function Text:apply_style(type, props)
  self.style = { type = type, props = props }

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
  self.entry_id = entry_id

  return self
end

function Text:render(canvas)
  local is_virtual_text = false

  if self.style ~= nil then
    is_virtual_text = self.style.type == Style.types.virtual_text
    canvas:add_style(self:_build_style())
  end

  if is_virtual_text == false then
    canvas:add_text(self.text, self.col, self.row)
  end

  if self.entry_id ~= nil then
    canvas:add_entry(self:_build_entry())
  end
end

function Text:_build_style()
  local props = self.style.props

  if self.style.type == Style.types.highlight then
    local hl_pos = {
      row = self.row,
      col_start = self.col,
      col_end = string.len(self.text)
    }
    return Style:new_hl(props.hl_name, hl_pos)
  end

  local virtual_text_pos = {
    pos_type = props.pos_type,
    row = self.row,
    col = self.col,
  }
  return Style:new_virtual_text(self.text, props.hl_name, virtual_text_pos)
end

function Text:_build_entry()
  return {
    id = self.entry_id,
    pos = {
      col = self.col,
      row = self.row
    }
  }
end

return Text
