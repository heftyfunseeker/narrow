local Style = require("narrow.gui.style")

local Toggle = {}
Toggle.__index = Toggle

function Toggle:new(label, is_on, is_hovered)
  local label_hl
  if is_hovered then label_hl = "Function" else label_hl = "Comment" end

  local icon_hl
  if is_on then icon_hl = "Identifier" else icon_hl = "Comment" end

  return Style.join.horizontal({
    Style:new():add_highlight(icon_hl):margin_right(1):render("●"),
    Style:new():add_highlight(label_hl):render(label)
  })
end

return Toggle
