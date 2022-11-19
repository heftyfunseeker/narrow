local RipgrepParser = {}
RipgrepParser.__index = RipgrepParser

function RipgrepParser:new()
  local new_obj = {
    -- concat messages chunks until we detect a full rg message (with \n)
    message_remainder = {},
  }
  return setmetatable(new_obj, self)
end

function RipgrepParser:reset()
  if #self.message_remainder > 0 then
    self.message_remainder = {}
  end
end

function RipgrepParser:parse_lines(lines, out_messages)
  for _, line in ipairs(lines) do
    local status, result = pcall(vim.json.decode, line)
    if status then
      table.insert(out_messages, result)
    else
      print("failed parsing rg json line: " .. vim.inspect(line))
    end
  end
end

function RipgrepParser:parse_stream(stream, out_messages)
  if stream == nil then return nil end

  table.insert(self.message_remainder, stream)

  -- check if we have a complete message
  local new_line_index = string.find(stream, "\n")
  if new_line_index == nil then return end

  local messages_string = table.concat(self.message_remainder)
  local message_lines = vim.split(messages_string, "\n")

  if message_lines[#message_lines] ~= "" then
    self.message_remainder = { message_lines[#message_lines] }
  else
    self.message_remainder = {}
  end
  -- this is either our remainder or an empty "" for the \n
  table.remove(message_lines, #message_lines)
  self:parse_lines(message_lines, out_messages)
end

return RipgrepParser
