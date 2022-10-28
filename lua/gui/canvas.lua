local Style = require("gui.style")

Canvas = {}

function Canvas:new()
  local new_obj = {
    -- sparse array of lines
    lines = {},
    row_max = 0,

    -- array of style objects
    styles = {},

    -- array of entry ids - used to resolve entry lookups
    entries = {}
  }
  self.__index = self
  return setmetatable(new_obj, self)
end

-- Places text at the col, row byte offsets.
-- Pads leading bytes if needed with a space
function Canvas:add_text(text, col, row)
  if row < 0 or col < 0 then
    return
  end

  self.row_max = math.max(row, self.row_max)

  if self.lines[row] == nil then
    self.lines[row] = string.rep(" ", col - 1) .. text
  else
    local line = self.lines[row]
    local line_len = string.len(line)
    if line_len < col then
      line = line .. string.rep(" ", col - line_len - 1) .. text
    else
      line = line:sub(1, col - 1) .. text
    end
    self.lines[row] = line
  end
end

function Canvas:add_style(style)
  table.insert(self.styles, style)
end

function Canvas:add_entry(entry)
  table.insert(self.entries, entry)
end

function Canvas:render_to_window(window)
  -- lines array/obj is sparse, so iterate over it and add filler empty lines where needed
  local render_lines = {}
  for row = 0, self.row_max do
    if self.lines[row] == nil then
      table.insert(render_lines, "")
    else
      table.insert(render_lines, self.lines[row])
    end
  end

  window:set_lines(0, -1, render_lines)

  -- apply styles
  for _, style in ipairs(self.styles) do
    if style.type == Style.types.highlight then
      -- make highlight call to window
      window:add_highlight(style.name, style.pos)
    elseif style.type == Style.types.virtual_text then
      window:add_virtual_text(style.text, style.name, style.pos)
    end
  end

  -- apply entry identifiers
  for _, entry in ipairs(self.entries) do
    window:add_entry(entry.id, entry.pos)
  end
end

return Canvas

-- local header_text = Text:new({ text = line_header, style = "Function" })
-- local result_text = Text:new({ text =  result_text, style = "Normal" })
--
-- local result_entry = HorizontalLayout:new()
--   :set_margin(1)
--   :add_child(header_text)
--   :add_child(result_text)
--
-- local vertical_layout = VerticalLayout:new()
--   :set_margin(0)
--   :add_child(result_entry)
--
-- vertical_layout:render = function(canvas)
--   for each child in children
--     child.render(canvas)
--   end
--
-- end

-- layouts do 2 passes
-- 1. build the lines of text => array of lines
-- 2. perform styling (highlights)
