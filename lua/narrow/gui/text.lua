local Style = require("narrow.gui.style")

local Text = {
  AlignmentType = {
    center = 0,
    right = 1
  }
}
Text.__index = Text

function Text:new()
  local new_obj = {
    text = nil,
    style = nil,
    alignment_type = nil,
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

function Text:apply_style(style)
  --self.style = style

  return self
end

function Text:set_alignment(alignment_type)
  self.alignment_type = alignment_type

  return self
end

-- set the display col, row. Optionally, treat these values
-- as bytes with `as_bytes` which will index directly with col/row.
function Text:set_pos(col, row, as_bytes)
  self.col = col
  self.row = row
  self.as_bytes = as_bytes

  return self
end

function Text:set_dimensions(width, height)
  self.width = width
  self.height = height

  return self
end

function Text:mark_entry(entry_id, entry_namespace)
  self.entry_id = entry_id
  self.entry_namespace = entry_namespace

  return self
end

function Text:render(canvas)
  local is_virtual_text = false

  local text = self.text
  if self.alignment_type ~= nil then
    text = self:_apply_aligment()
  end

  if self.style ~= nil then
    is_virtual_text = self.style.type == Style.Types.virtual_text
    canvas:add_style(self:_build_style(text))
  end

  if is_virtual_text == false then
    canvas:add_text(text, self.col, self.row, self.as_bytes)
  else
    -- we need to ensure there's a row for the virtual text to write to
    canvas:add_text("", 0, self.row, self.as_bytes)
  end

  if self.entry_id ~= nil then
    canvas:add_entry(self:_build_entry())
  end
end

function Text:_apply_aligment()
  if self.alignment_type == Text.AlignmentType.center then
    return self:_apply_center_alignment()
  elseif self.alignment_type == Text.AlignmentType.right then
    return self:_apply_right_alignment()
  end
  return self.text
end

function Text:_apply_center_alignment()
  local text_len = vim.fn.strdisplaywidth(self.text)
  if self.width < text_len then
    return self.text
  end

  local padding = math.floor((self.width - text_len) * .5)
  local padding_text = string.rep(" ", padding)
  return padding_text .. self.text .. padding_text
end

function Text:_apply_right_alignment()
  local text_len = vim.fn.strdisplaywidth(self.text)
  if self.width < text_len then
    return self.text
  end

  local padding = math.floor(self.width - text_len)
  local padding_text = string.rep(" ", padding)
  return padding_text .. self.text
end

function Text:_build_style(text)
  local style = self.style
  if style.type == Style.Types.highlight then
    local hl_pos = {
      row = self.row,
      col_start = self.col,
      col_end = self.col + #self.text
    }
    return Style:new_hl(style.hl_name, hl_pos)
  end

  local virtual_text_pos = {
    pos_type = style.pos_type,
    row = self.row,
    col = self.col,
  }
  return Style:new_virtual_text(text, style.hl_name, virtual_text_pos)
end

function Text:_build_entry()
  return {
    id = self.entry_id,
    entry_namespace = self.entry_namespace,
    pos = {
      col = self.col,
      row = self.row
    }
  }
end

return Text
