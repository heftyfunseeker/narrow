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

-- when building the lines, check if the multi display width byte is corrupted, if so add spaces instead
function Canvas:add_text(params)
  local text = params.text
  local col = params.col
  local row = params.row
  local style = params.style

  if row < 0 or col < 0 then
    return
  end

  self.row_max = math.max(self.row_max, row)

  if self.lines[row] == nil then
    -- table that stores display cell to (char/code points, style)
    self.lines[row] = {}
  end

  local cell_map = self.lines[row]

  -- iterate over chars inserting into cell map
  local char_count = vim.fn.strchars(text)
  local cur_col = col
  for i = 0, char_count - 1, 1 do
    local c = vim.fn.strcharpart(text, i, 1)
    local display_width = vim.fn.strdisplaywidth(c)
    local cell_info = {code = c, display_width = display_width, style = style}

    self:insert_at_cell(cell_map, cur_col, cell_info)
    cur_col = cur_col + display_width
  end
end

function Canvas:insert_at_cell(cell_map, cell_index, cell_info)
  cell_map[cell_index] = cell_info

  -- if there's a multi-width code overlapping us, nuke it. Note we only check for at most 3 cell col overlaps
  if cell_index > 0 and cell_map[cell_index - 1] and cell_map[cell_index - 1].display_width > 1 then
    cell_map[cell_index - 1] = nil
  end

  if cell_index > 1 and cell_map[cell_index - 2] and cell_map[cell_index - 2].display_width > 2 then
    cell_map[cell_index - 2] = nil
  end
end

function Canvas:build_line(cell_map)
  local str_builder = {}

  local ending_cell = 0

  for cell_index, cell_info in pairs(cell_map) do
    ending_cell = math.max(cell_index + cell_info.display_width, ending_cell)
  end

  -- create our line that contains the entire display_width
  for _ = 0, ending_cell - 1, 1 do
    table.insert(str_builder, " ")
  end

  -- note: add 1 to cell indices for 1 based indexing in lua
  for cell_index, cell_info in pairs(cell_map) do
    str_builder[cell_index + 1] = cell_info.code

    -- collapse padded cells if this is multi-width
    for i = 1, cell_info.display_width - 1, 1 do
      str_builder[cell_index + 1 + i] = ""
    end
  end

  return table.concat(str_builder)
end

function Canvas:render(only_styles)
  -- lines array/obj is sparse, so iterate over it and add filler empty lines where needed
  local render_lines = {}
  for row = 0, self.row_max do
    if self.lines[row] == nil then
      table.insert(render_lines, "")
    else
      table.insert(render_lines, self:build_line(self.lines[row]))
    end
  end

  if not only_styles then
    self.window:set_lines(render_lines)
  end
  --
  -- -- apply styles
  -- for _, style in ipairs(self.styles) do
  --   if style.type == Style.Types.highlight then
  --     self.window:add_highlight(style.name, style.pos)
  --   elseif style.type == Style.Types.virtual_text then
  --     self.window:add_virtual_text(style.text, style.name, style.pos)
  --   end
  -- end

  -- apply entry identifiers
  for _, entry in ipairs(self.entries) do
    self.window:add_entry(entry.id, entry.pos, entry.entry_namespace)
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

