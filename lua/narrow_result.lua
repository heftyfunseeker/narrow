NarrowResult = {}

function NarrowResult:new(raw_line)
  local header, row, column, text = string.match(raw_line, "([^:]*):(%d+):(%d+):(.*)")
  if row and column and header and text then
    local new_obj = {
      header = header,
      row = tonumber(row),
      column = tonumber(column),
      text = text,
      display_text = string.format("%3d:%3d:%s", tonumber(row), tonumber(column), text)
    }
    self.__index = self
    return setmetatable(new_obj, self)
  end

  return nil
end

function NarrowResult:new_header(header_text, header_number)
  local this = {
    is_header = true,
    header_number = header_number,
    text = header_text,
  }
  setmetatable(this, NarrowResult)
  return this
end

return NarrowResult
