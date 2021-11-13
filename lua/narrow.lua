local api = vim.api
local buf, win local namespace_id = nil
local state = {
    narrow_results = {},
    debounce_count = 0,
    query = ""
}
local function open_window()
   buf = api.nvim_create_buf(false, true) -- create new emtpy buffer
   api.nvim_buf_set_option(buf, "bufhidden", "wipe")
   api.nvim_buf_set_lines(buf, 0, 0, false, {" >  "})

   -- get dimensions
   local width = api.nvim_get_option("columns")
   local height = api.nvim_get_option("lines")

   -- calculate our floating window size
   local win_height = math.ceil(height * 0.4)
   local win_width = math.ceil(width)

   -- and its starting position
   local row = height * 0.6
   local col = 0

   -- set some options
   local opts = {
      style = "minimal",
      relative = "editor",
      width = win_width,
      height = win_height,
      row = row,
      col = col,
      border = "rounded",
      noautocmd = true
   }
   -- and finally create it with buffer attached
   --
   win = api.nvim_open_win(buf, true, opts)
   api.nvim_win_set_option(win, 'winhl', 'Normal:Normal')
   api.nvim_win_set_option(win, 'wrap', false)
   api.nvim_win_set_option(win, 'cursorline', true)
   api.nvim_win_set_cursor(win, {1, 3})

   api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':lua vim.api.nvim_win_close(0, true) <CR>', { nowait = true, noremap = true, silent = true })
   api.nvim_command("startinsert")
end

-- simple object that parses a grep line
-- lua/narrow.lua:16:23:   local win_height = math.ceil(height * 0.4)
NarrowResult = {}
NarrowResult.__index = NarrowResult

function NarrowResult:new(raw_line)
   local header, row, column, text = string.match(raw_line, "([^:]*):(%d+):(%d+):(.*)")
   if header == nil then print("WAT: " .. raw_line) end
   local this = {
      header = header,
      row = tonumber(row),
      column = tonumber(column),
      text = text,
   }
   setmetatable(this, NarrowResult)
   return this
end

function NarrowResult:new_header(header_text)
   local this = {
      is_header = true,
      text = header_text,
   }
   setmetatable(this, NarrowResult)
   return this
end

function result_index_from_cursor(cursor)
    local cursor_row = cursor[1]
    return cursor_row - 1
end

local function append_narrow_results(result_buffer, raw_result_string)
    -- TODO: I wonder if we're splitting results that contain newlines?
   local vals = vim.split(raw_result_string, "\n")
   for _, line in pairs(vals) do
      if line ~= "" then
        local result = NarrowResult:new(line)
        if result.header then -- splitting on newline might be flawed
            table.insert(result_buffer, result)
        else
            print("bad split?: " .. raw_result_string)
        end
      end
   end
end

local function display_results(narrow_results)
    local headers_processed = {}
    local results = {}
    -- final results includes header entries to keep display lines and state lines in sync
    local final_results = {}
    for _, result in ipairs(narrow_results) do
        -- how is header bad?
        if headers_processed[result.header] == nil then
            headers_processed[result.header] = true

            -- TODO: we should let the narrow result define this text
            local header_text = "#".. result.header
            table.insert(results, header_text)
            table.insert(final_results, NarrowResult:new_header(header_text))
        end
        table.insert(results, string.format("%3d:%3d:%s", result.row, result.column, result.text))
        table.insert(final_results, result)
    end

    state.narrow_results = final_results
    api.nvim_buf_set_lines(buf, 1, -1, false, results)

    -- now add highlights
    for row, result in ipairs(state.narrow_results) do
        if result.is_header then
            api.nvim_buf_add_highlight(buf, -1, "NarrowHeader", row, 0, -1)
        else
            local col_start, col_end = string.find(result.text, state.query)
            if col_start and col_end then
                api.nvim_buf_add_highlight(buf, -1, "NarrowMatch", row, col_start, col_end)
            end
        end
    end
end

-- spawn rg and parse and append stdio stream into a narrow_results buffer
-- on exit, take the narrow_results and display them in our buffer
local function search(query_term)
   local narrow_results = {}

   local stdout = vim.loop.new_pipe(false)
   local stderr = vim.loop.new_pipe(false)

   Handle = vim.loop.spawn(
      "rg",
      {
         args = { query_term, "--smart-case", "--vimgrep" },
         stdio = { nil, stdout, stderr },
      },
      vim.schedule_wrap(function()
         stdout:read_stop()
         stderr:read_stop()
         stdout:close()
         stderr:close()
         Handle:close()

         display_results(narrow_results)
      end)
   )

   local onread = function(err, input_stream)
      if err then
         print("ERROR: ", err)
      end

      if input_stream then
        append_narrow_results(narrow_results, input_stream)
      end
   end

   vim.loop.read_start(stdout, onread)
   vim.loop.read_start(stderr, onread)
end

local function narrow()
   open_window()

   namespace_id = api.nvim_create_namespace "narrow"

   -- clear our input listener
   api.nvim_buf_attach(buf, false, {
      on_detach = function(detach_str, buf_handle)
         vim.on_key(nil, namespace_id) end, })

   vim.on_key(function(key)
       print("key pressed: " .. vim.inspect(key))

      local cursor = api.nvim_win_get_cursor(win)
      print("cursor pos: " .. vim.inspect(cursor))
      if cursor[1] == 1 and cursor[2] < 3 then
          print("resetting cursor!")
          api.nvim_buf_set_lines(buf, 0, 0, false, {" >  "})
          api.nvim_buf_set_lines(buf, 1, -1, false, {})
          api.nvim_win_set_cursor(win, {1, 3})
      end

    if api.nvim_get_mode().mode == 'n' then
        local results = state.narrow_results
        if key == 'j' then
            local result = results[result_index_from_cursor(cursor) + 1]
            if result and result.is_header then
                api.nvim_win_set_cursor(win, {cursor[1] + 1, cursor[2]})
            end
        elseif key == 'k' then
            local result = results[result_index_from_cursor(cursor) - 1]
            if result and result.is_header then
                api.nvim_win_set_cursor(win, {cursor[1] - 1, cursor[2]})
            end
        end
    end
      -- early return if we arent' inserting text
      -- we should also test if we're on the query input line
      if api.nvim_get_mode().mode ~= "i" then
         return
      end

      if cursor[1] ~= 1 then
         return
      end

      state.debounce_count = state.debounce_count + 1
      vim.defer_fn(function()
          state.debounce_count = state.debounce_count - 1
          if state.debounce_count > 0 then
              return
          end
         -- I should check that this isn't in flight
         -- before kicking off another query (or drop it if I know another one is inbound)
         local query = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
         query = string.gsub(query, "%s+", "")
         query = string.match(query, ">(.*)")
         state.query = query
         if query ~= nil and #query >= 2 then
            search(query)
         else
            -- clear previous results
            -- TODO: make function
            api.nvim_buf_set_lines(buf, 1, -1, false, {})
         end
      end, 500)
   end, namespace_id)
end

return {
   narrow = narrow,
}
