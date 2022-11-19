local Button = {}
Button.__index = Button

function Button:new()
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

function Button:set_pos(col, row)
  self.col = col
  self.row = row

  return self
end

function Button:render(canvas)
  -- render border
  --
  -- I could build these with my Text components :)
  local top    = "╭──────────────╮"
  local middle = "│    button    │"
  local bottom = "╰──────────────╯"

  canvas:add_text(top, self.col, self.row)
  canvas:add_text(middle, self.col, self.row + 1)
  canvas:add_text(bottom, self.col, self.row + 2)
end

return Button
