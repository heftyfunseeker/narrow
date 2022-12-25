-- TextBlock: An array of lines where each line is an object {
-- text,
-- highlight: {hl_name, pos},
-- states: { pos, state }

local TextBlock = {
  padding = {
    position = {
      Front = 0,
      Back = 1,
    }
  }
}
TextBlock.__index = TextBlock

function TextBlock:new()
  local new_obj = {}
  return setmetatable(new_obj, self)
end

function TextBlock:from_string(text, trim_empty)
  if type(text) ~= "string" then
    print("Error- TextBlock:new expected type string")
  end

  local new_obj = {}
  if text == "" then
    table.insert(new_obj, { text = text, highlights = {}, states = {} })
  else
    if not trim_empty then trim_empty = true end

    local lines = vim.split(text, "\n", { trimempty = trim_empty })
    for _, line in ipairs(lines) do
      table.insert(new_obj, { text = line, highlights = {}, states = {} })
    end
  end


  return setmetatable(new_obj, self)
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
function TextBlock:apply_width(width, padding_pos)
  local max_width = self:width()
  if not width or max_width > width then
    width = max_width
  end

  if not padding_pos then
    padding_pos = TextBlock.padding.position.Back
  end

  for _, line in ipairs(self) do
    local line_width = vim.fn.strdisplaywidth(line.text)
    if line_width < width then
      if padding_pos == TextBlock.padding.position.Back then
        line.text = line.text .. string.rep(" ", width - line_width)
      else
        line.text = string.rep(" ", width - line_width) .. line.text
      end
    end
  end
  return self
end

function TextBlock:apply_height(height)
  local curr_height = self:height()
  if not height or curr_height >= height then
    return self
  end

  for _ = curr_height, height - 1, 1 do
    table.insert(self, { text = "", highlights = {}, states = {} })
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

function TextBlock:apply_highlight(hl_name, opts)
  if not hl_name then return end

  local col_start = opts.col_start
  if not col_start then col_start = 0 end


  for row, line in ipairs(self) do
    local col_end = opts.col_end
    if not col_end then col_end = #line.text end
    table.insert(line.highlights, make_hl(hl_name, row, col_start, col_end))
  end
end

local function make_state(state, row, col_start, col_end)
  return {
    state = state,
    pos = {
      row = row,
      col_start = col_start,
      col_end = col_end
    }
  }
end

function TextBlock:set_state(state)
  if not state then return end

  for row, line in ipairs(self) do
    -- @todo: do we need to handle col start here?
    line.states = { make_state(state, row, 0, #line.text) }
  end
end

return TextBlock
