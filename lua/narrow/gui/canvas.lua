local Style = require("narrow.gui.style")

local Canvas = {}

function Canvas:new(window)
  local new_obj = {
    window = window,
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

-- Places text at the col, row screen display coords.
-- Pads leading bytes if needed with a space
-- We have display width and byte-width to contend with
-- params : { text, col, row, as_bytes, style }
-- @TODO: we need to handle this same madness for VirtualText
function Canvas:add_text(params)
  local text = params.text
  local col = params.col
  local row = params.row
  local as_bytes = params.as_bytes
  local style = params.style

  if row < 0 or col < 0 then
    return
  end


  local hl_col_byte_start = 0 -- used for hl placement

  self.row_max = math.max(row, self.row_max)

  -- Early return if we're rendering virtual text - this method needs love
  if style and style.type == Style.Types.virtual_text then
    table.insert(self.styles, self:_build_style(text, row, col, style))
    return
  end

  if self.lines[row] == nil then
    self.lines[row] = string.rep(" ", col - 1) .. text
    hl_col_byte_start = col - 1
  elseif not as_bytes then
    local line = self.lines[row]

    if vim.fn.strdisplaywidth(line) < col then -- easy case
      line = line .. string.rep(" ", col - vim.fn.strdisplaywidth(line) - 1)
      hl_col_byte_start = #line
      line = line .. text
    elseif vim.fn.strdisplaywidth(vim.fn.strcharpart(line, 0, col)) >= col then -- muti-width display characters case
      local line_start = vim.fn.strcharpart(line, 0, col)
      while vim.fn.strdisplaywidth(line_start) >= col and (vim.fn.strchars(line_start) - 1) > 0 do
        line_start = vim.fn.strcharpart(line_start, 0, vim.fn.strchars(line_start) - 1)
      end

      local line_end = vim.fn.strcharpart(line, vim.fn.strchars(line_start) + vim.fn.strdisplaywidth(text))
      line = line_start .. string.rep(" ", col - vim.fn.strdisplaywidth(line_start) - 1)
      hl_col_byte_start = #line
      line =  line .. text .. line_end
    else -- standard display width characters case
      line = vim.fn.strcharpart(line, 0, col)
      hl_col_byte_start = #line
      line = line .. text .. vim.fn.strcharpart(line, col + vim.fn.strdisplaywidth(text))
    end

    self.lines[row] = line
  else
    local line = self.lines[row]
    local line_len = #line
    hl_col_byte_start = col

    if line_len < col then
      line = line .. string.rep(" ", col - line_len - 1) .. text
    else
      line = line:sub(0, col) .. text .. line:sub(col + #text + 1)
    end

    self.lines[row] = line
  end

  -- add highlights
  if style then
    table.insert(self.styles, self:_build_style(text, row, hl_col_byte_start, style))
  end

end

function Canvas:_build_style(text, row, col, style)
  if style.type == Style.Types.highlight then
    local hl_pos = {
      row = row,
      col_start = col,
      col_end = col + #text
    }
    return Style:new_hl(style.hl_name, hl_pos)
  end

  local virtual_text_pos = {
    pos_type = style.pos_type,
    row = row,
    col = col,
  }
  return Style:new_virtual_text(text, style.hl_name, virtual_text_pos)
end

function Canvas:add_entry(entry)
  table.insert(self.entries, entry)
end

function Canvas:render(only_styles)
  -- lines array/obj is sparse, so iterate over it and add filler empty lines where needed
  local render_lines = {}
  for row = 0, self.row_max do
    if self.lines[row] == nil then
      table.insert(render_lines, "")
    else
      table.insert(render_lines, self.lines[row])
    end
  end

  if not only_styles then
    self.window:set_lines(render_lines)
  end

  -- apply styles
  for _, style in ipairs(self.styles) do
    if style.type == Style.Types.highlight then
      self.window:add_highlight(style.name, style.pos)
    elseif style.type == Style.Types.virtual_text then
      self.window:add_virtual_text(style.text, style.name, style.pos)
    end
  end

  -- apply entry identifiers
  for _, entry in ipairs(self.entries) do
    self.window:add_entry(entry.id, entry.pos, entry.entry_namespace)
  end
end

-- @todo: lets have the canvas cache all used namespaces to do this book keeping for us
function Canvas:clear(additional_namespaces, only_styles)
  self.window:clear(additional_namespaces, only_styles)

  self.lines = {}
  self.row_max = 0

  self.styles = {}
  self.entries = {}
end

function Canvas:get_dimensions()
  return self.window:get_dimensions()
end

-- List of [extmark_id, row, col] tuples in "traversal order".
function Canvas:get_entry_at_cursor(namespace)
  return self.window:get_entry_at_cursor(namespace)
end

function Canvas:get_all_entries(namespace)
  return self.window:get_all_entries(namespace)
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
