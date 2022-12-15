-- TextBlock: An array of lines where each line is an object {
-- text,
-- highlight: {hl_name, pos},
-- on_select_info: { pos, on_selected }

local TextBlock = {}
TextBlock.__index = TextBlock

function TextBlock:new()
  local new_obj = {}
  return setmetatable(new_obj, self)
end

function TextBlock:from_string(text)
  if type(text) ~= "string" then
    print("Error- TextBlock:new expected type string")
  end

  local new_obj = {}

  local lines = vim.fn.split(text, "\n")
  for _, line in ipairs(lines) do
    table.insert(new_obj, { text = line, highlights = {}, on_selected = {} })
  end

  return setmetatable(new_obj, self)
end

function TextBlock:add_line(text, highlights, on_selected)
  if not highlights then highlights = {} end
  if not on_selected then on_selected = {} end

  table.insert(self, { text = text, highlights = highlights, on_selected = on_selected })
  return self
end

function TextBlock:width()
  local max_width = 0
  for _, line in ipairs(self) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line.text))
  end
  return max_width
end

function TextBlock:height()
  local height = 0
  for _, _ in ipairs(self) do
    height = height + 1
  end
  return height
end

-- pads lines with spaces so that each line has the same display width
-- if width is less than the block's max width, max width is used
function TextBlock:apply_width(width)
  local max_width = self:width()
  if not width or max_width > width then
    width = max_width
  end

  for _, line in ipairs(self) do
    local line_width = vim.fn.strdisplaywidth(line.text)
    line.text = line.text .. string.rep(" ", width - line_width)
  end
  return self
end

function TextBlock:apply_height(height)
  local curr_height = self:height()
  if not height or curr_height >= height then
    return self
  end

  for _ = curr_height, height - 1, 1 do
    table.insert(self, { text = "", highlights = {}, on_selected = {} })
  end
  return self
end

local function make_hl(hl_name, row, col_start, col_end)
  return {
    hl_name = hl_name,
    pos = {
      row = row,
      col_start = col_start,
      col_end = col_end
    }
  }
end

function TextBlock:apply_highlight(hl_name)
  if not hl_name then return end

  for row, line in ipairs(self) do
    line.highlights = { make_hl(hl_name, row, 0, #line.text) }
  end
end

local function make_on_selected(on_selected, row, col_start, col_end)
  return {
    on_selected = on_selected,
    pos = {
      row = row,
      col_start = col_start,
      col_end = col_end
    }
  }
end

function TextBlock:mark_selectable(on_selected)
  if not on_selected then return end

  for row, line in ipairs(self) do
    line.on_selected = { make_on_selected(on_selected, row, 0, #line.text) }
  end
end

return TextBlock
