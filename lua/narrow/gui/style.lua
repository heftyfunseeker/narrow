Style = {
  Types = {
    highlight = 0,
    virtual_text = 1,
  }
}

Style.__index = Style

-- name: name of highlight
-- pos: { row, col_start, col_end }
function Style:new_hl(name, pos)
  local new_obj = {
    type = Style.Types.highlight,
    name = name,
    pos = pos,
  }
  return setmetatable(new_obj, self)
end

-- name: name of highlight
-- pos: { row, col }
function Style:new_virtual_text(text, name, pos)
  local new_obj = {
    type = Style.Types.virtual_text,
    text = text,
    name = name,
    pos = pos,
  }
  return setmetatable(new_obj, self)
end

return Style
