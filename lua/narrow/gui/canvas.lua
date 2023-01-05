local Style = require("narrow.gui.style")

local Canvas = {}

function Canvas:new(window)
  local new_obj = {
    window = window,
    lines = {},
    num_rows = 0,
    selectable_text_blocks = {},

    virtual_text = {},
  }
  self.__index = self
  return setmetatable(new_obj, self)
end

function Canvas:write(text_block)
  for _, line in ipairs(text_block) do
    -- adjust highlights from local text_block row to canvas row
    for _, hl in ipairs(line.highlights) do
      hl.pos.row = self.num_rows
    end

    for _, state in ipairs(line.states) do
      state.pos.row = self.num_rows
    end

    table.insert(self.lines, line)

    self.num_rows = self.num_rows + 1
  end
end

function Canvas:write_virtual(text, hl_name, pos)
  table.insert(self.virtual_text, { text = text, hl_name = hl_name, pos = pos })
end

function Canvas:render_new(lock_buffer_after_draw)
  self.window:set_buf_option("modifiable", true)

  -- clear any marks first
  self.window:clear(nil, true)

  local window_lines = {}
  for _, line in ipairs(self.lines) do
    table.insert(window_lines, line.text)
  end

  self.window:set_lines(window_lines)

  for _, line in ipairs(self.lines) do
    for _, hl in ipairs(line.highlights) do
      self.window:add_highlight(hl.hl_name, hl.pos)
    end
  end

  for _, vt in ipairs(self.virtual_text) do
    self.window:add_virtual_text(vt.text, vt.hl_name, vt.pos)
  end

  if lock_buffer_after_draw then
    self.window:set_buf_option("modifiable", false)
  end
end

-- @todo: lets have the canvas cache all used namespaces to do this book keeping for us
function Canvas:clear()
  self.lines = {}
  self.num_rows = 0
  self.selectable_text_blocks = {}

  self.virtual_text = {}
end

-- @todo: delete/move this to search_provider - provider should handle how to select things?
function Canvas:get_state(row, col)
  local line = self.lines[row]
  if not line then return nil end

  for _, state in ipairs(line.states) do
    if state.pos.col_start <= col and state.pos.col_end > col then
      return state.state
    end
  end

  return nil
end

function Canvas:get_dimensions()
  return self.window:get_dimensions()
end

function Canvas:has_focus()
  return self.window:has_focus()
end

function Canvas:set_focus()
  self.window:set_focus()
end

function Canvas:drop()
  self.window:drop()
  self.window = nil
  self:clear()
end

return Canvas
