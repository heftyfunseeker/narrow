NarrowResult = {}

function NarrowResult:new(raw_line)
  local header, row, column, text = string.match(raw_line, "([^:]*):(%d+):(%d+):(.*)")
  local new_obj = {
    header = header,
    row = tonumber(row),
    column = tonumber(column),
    text = text,
  }
  self.__index = self
  return setmetatable(new_obj, self)
end

function NarrowResult:new_header(header_text)
  local this = {
    is_header = true,
    text = header_text,
  }
  setmetatable(this, NarrowResult)
  return this
end

return NarrowResult
