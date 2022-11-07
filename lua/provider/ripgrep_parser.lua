local uv = vim.loop

RipgrepParser = {}
RipgrepParser.__index = RipgrepParser

function RipgrepParser:new()
  local new_obj = {
    -- concat messages chunks until we detect a full rg message (with \n)
    message_remainder = nil,
    message_buffer = "",
  }
  return setmetatable(new_obj, self)
end

function RipgrepParser:parse_messages(out_messages)
  local parse_line, on_finished

  parse_line = uv.new_async(vim.schedule_wrap(function(in_json_message)
    local status, rg_message = pcall(vim.mpack.decode, in_json_message)
    if status then
      table.insert(out_messages, rg_message)
    end
  end))

  on_finished = uv.new_async(vim.schedule_wrap(function()
    print("finished with " .. #out_messages .. " parsed")
    on_finished:close()
    parse_line:close()
  end))

  uv.new_thread({}, function(message_buffer, in_parse_line, in_on_finished)
    local lines = vim.split(message_buffer, "\n")
    table.remove(lines, #lines)

    for _, line in ipairs(lines) do
      local status, rg_message = pcall(vim.json.decode, line)
      if status then
        in_parse_line:send(vim.mpack.encode(rg_message))
      end
    end
    in_on_finished:send()
  end,
    self.message_buffer,
    parse_line,
    on_finished
  )
end

function RipgrepParser:parse_stream(stream)
  if stream == nil then return nil end

  self.message_buffer = self.message_buffer .. stream
end

-- function RipgrepParser:parse_stream(stream, out_messages)
--   if stream == nil then return nil end
--   print(stream)
--
--   local lines = vim.split(stream, "\n")
--
--   if self.message_remainder ~= nil then
--     lines[1] = self.message_remainder .. lines[1]
--     self.message_remainder = nil
--   end
--
--   -- if the last entry isn't "", we have a partial message at the end
--   if lines[#lines] == "" then
--     table.remove(lines, #lines)
--
--     --parse_rg_json_lines(lines, out_messages)
--   else
--     self.message_remainder = lines[#lines]
--     table.remove(lines, #lines)
--     --print(vim.inspect(lines))
--
--     -- parse_rg_json_lines(lines, out_messages)
--   end
-- end

return RipgrepParser
