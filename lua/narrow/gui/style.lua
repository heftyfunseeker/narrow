local TextBlock = require("narrow.gui.text_block")

Style = {
  -- modules and constants/enums
  join = {},
  align = {
    horizontal = {
      Left = 0,
      Center = 1,
      Right = 2,
    }
  }
}

Style.__index = Style

function Style:new()
  local new_obj = {
    width = nil,
    height = nil,
    margin = {
      left = nil,
      right = nil,
      top = nil,
      bottom = nil,
    },
    horizontal_align = nil,
    has_border = false,
    hl_name = nil,
  }
  return setmetatable(new_obj, self)
end

function Style:set_width(width)
  self.width = width
  return self
end

function Style:set_height(height)
  self.height = height
  return self
end

function Style:margin_right(n)
  self.margin.right = n
  return self
end

function Style:margin_left(n)
  self.margin.left = n
  return self
end

-- api.nvim_buf_add_highlight(self.buf, -1, hl_name, pos.row, pos.col_start, pos.col_end)
function Style:add_highlight(hl_name)
  self.hl_name = hl_name
  return self
end

function Style:mark_selectable(on_selected)
  self.on_selected = on_selected
  return self
end

function Style:border()
  self.has_border = true
  return self
end

function Style:align_horizontal(horizontal_align)
  self.horizontal_align = horizontal_align
  return self
end

-- 1. apply padding
-- 2. apply border
-- 3. appy margin
function Style:render(text)
  local text_block = {}
  if type(text) == "string" then
    text_block = TextBlock:from_string(text)
  elseif type(text) == "table" then -- @todo: make this safer
    text_block = text
  else
    print("Error: can't render" .. text .. ". Only Strings and TextBlocks are accepted")
  end

  -- apply height first so we have the same number of lines when applying width
  self:_apply_horizontal_alignment(text_block)
  -- @todo: _apply_vertical_alignment
  text_block:apply_height(self.height)

  text_block:apply_highlight(self.hl_name)
  text_block:mark_selectable(self.on_selected)

  text_block = self:apply_border(text_block)
  text_block = self:apply_margin(text_block)

  return text_block
end

function Style:_apply_horizontal_alignment(text_block)
  local align_type = self.horizontal_align
  if not align_type then
    align_type = Style.align.horizontal.Left
  end

  local padding_pos
  if align_type == Style.align.horizontal.Right then
    padding_pos = TextBlock.padding.position.Front
  elseif align_type == Style.align.horizontal.left then
    padding_pos = TextBlock.padding.position.Back
  end

  text_block:apply_width(self.width, padding_pos)
end

function Style:apply_margin(text_block)
  local rows = text_block:height()
  if self.margin.left then
    -- @todo: should we appy this technique for join.horizontal? Each block has max height (of the set) applied. And then local max width applied
    local left_block = TextBlock:new():apply_height(rows):apply_width(self.margin.left)
    text_block = Style.join.horizontal({ left_block, text_block })
  end

  if self.margin.right then
    local right_block = TextBlock:new():apply_height(rows):apply_width(self.margin.right)
    text_block = Style.join.horizontal({ text_block, right_block })
  end

  return text_block
end

function Style:apply_border(text_block)
  if not self.has_border then return text_block end

  local width = text_block:width()
  local height = text_block:height()

  local top = TextBlock:from_string("╭" .. string.rep("─", width) .. "╮")
  local side = TextBlock:from_string("│")
  for _ = 1, height - 1, 1 do
    side:add_line("│")
  end

  local bordered_block = {}
  table.insert(bordered_block, top)

  local middle = Style.join.horizontal({ side, text_block, side })
  table.insert(bordered_block, middle)

  local bottom = TextBlock:from_string("╰" .. string.rep("─", width) .. "╯")
  table.insert(bordered_block, bottom)

  return Style.join.vertical(bordered_block)
end

Style.join.horizontal = function(text_blocks)
  local string_builder = {}
  local line_highlights = {}
  local on_selected_marks = {}

  local max_height = 0
  for _, text_block in ipairs(text_blocks) do
    max_height = math.max(max_height, text_block:height())
  end

  for _, text_block in ipairs(text_blocks) do
    text_block:apply_height(max_height)
    text_block:apply_width()
  end

  for _, text_block in ipairs(text_blocks) do
    for row, line in ipairs(text_block) do
      local col_byte_offset = 0

      if string_builder[row] == nil then
        string_builder[row] = {}
      else
        for _, prev_line in ipairs(string_builder[row]) do
          col_byte_offset = col_byte_offset + #prev_line
        end
      end
      table.insert(string_builder[row], line.text)

      if line_highlights[row] == nil then
        line_highlights[row] = {}
      end

      if on_selected_marks[row] == nil then
        on_selected_marks[row] = {}
      end

      -- shift highlights in this column by num preceding bytes
      for _, hl in ipairs(line.highlights) do
        hl.pos.col_start = hl.pos.col_start + col_byte_offset
        hl.pos.col_end = hl.pos.col_end + col_byte_offset
        table.insert(line_highlights[row], hl)
      end

      -- shift on_selected marks in this column by num preceding bytes
      for _, on_selected in ipairs(line.on_selected) do
        on_selected.pos.col_start = on_selected.pos.col_start + col_byte_offset
        on_selected.pos.col_end = on_selected.pos.col_end + col_byte_offset
        table.insert(on_selected_marks[row], on_selected)
      end
    end
  end

  local new_text_block = TextBlock:new()
  for row, builder in pairs(string_builder) do
    local line = table.concat(builder)
    table.insert(new_text_block, { text = line, highlights = line_highlights[row], on_selected = on_selected_marks[row] })
  end

  return new_text_block
end

Style.join.vertical = function(text_blocks)
  local new_text_block = TextBlock:new()
  for _, text_block in ipairs(text_blocks) do
    for _, line in ipairs(text_block) do
      table.insert(new_text_block, line)
    end
  end

  return new_text_block
end
