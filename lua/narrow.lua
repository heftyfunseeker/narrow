local api = vim.api
-- TODO moves these to state
local buf, win local namespace_id = nil
local state = {
    narrow_results = {},
    debounce_count = 0,
    query = "",
}
local function open_search_buffer()
    state.orig_win = api.nvim_get_current_win()
    print("opening search buffer with current window list: " .. vim.inspect(api.nvim_list_wins()))
    api.nvim_command("split narrow-results")
    win = api.nvim_get_current_win()
    buf = api.nvim_win_get_buf(win)

    api.nvim_buf_set_lines(buf, 0, 0, false, {" >  "})
    api.nvim_buf_set_lines(buf, 1, -1, false, {})
    api.nvim_win_set_cursor(win, {1, 3})

   api.nvim_command("startinsert")
end

-- simple object that parses a grep line
-- lua/narrow.lua:16:23:   local win_height = math.ceil(height * 0.4)
NarrowResult = {}
NarrowResult.__index = NarrowResult

function NarrowResult:new(raw_line)
   local header, row, column, text = string.match(raw_line, "([^:]*):(%d+):(%d+):(.*)")
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
   local vals = vim.split(raw_result_string, "\n")
   for _, line in pairs(vals) do
      if line ~= "" then
        local result = NarrowResult:new(line)
        if result.header then
            table.insert(result_buffer, result)
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
    -- garbage/naive implementation.
    -- Doesnt handle single line with multiple matches,
    -- preserve case sensitivity, or patterns
    for row, result in ipairs(state.narrow_results) do
        if result.is_header then
            api.nvim_buf_add_highlight(buf, -1, "NarrowHeader", row, 0, -1)
        else
            local col_start, col_end = string.find(results[row], state.query)
            if col_start and col_end then
                api.nvim_buf_add_highlight(buf, -1, "NarrowMatch", row, col_start - 1, col_end)
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
   open_search_buffer()

   namespace_id = api.nvim_create_namespace "narrow"

   -- clear our input listener
   api.nvim_buf_attach(buf, false, {
      on_detach = function(detach_str, buf_handle)
         vim.on_key(nil, namespace_id) end, })

   vim.on_key(function(key)
      local cursor = api.nvim_win_get_cursor(win)
      if cursor[1] == 1 and cursor[2] < 3 then
          api.nvim_buf_set_lines(buf, 0, 0, false, {" >  "})
          api.nvim_buf_set_lines(buf, 1, -1, false, {})
          api.nvim_win_set_cursor(win, {1, 3})
      end

    local on_result_hovered = function(result_index)
        local result = state.narrow_results[result_index]
        if result and result.header and state.current_header ~= result.header then
            state.current_header = result.header
            api.nvim_set_current_win(state.orig_win)
            api.nvim_command(string.format("view %s", result.header))

            if state.need_del and state.cur_buf then
                api.nvim_buf_delete(state.cur_buf, {})
            else
                state.need_del = true
            end
            -- cache new result file buffer
            state.cur_buf = api.nvim_get_current_buf()
        elseif result and result.header then
            api.nvim_set_current_win(state.orig_win)
            api.nvim_set_current_buf(state.cur_buf)
            api.nvim_win_set_cursor(state.orig_win, {result.row, result.column})
        end
        -- switch back to result buffer
        api.nvim_set_current_win(win)
        api.nvim_set_current_buf(buf)
    end

    if api.nvim_get_mode().mode == 'n' then
        local results = state.narrow_results
        if key == 'j' then
            local result = results[result_index_from_cursor(cursor) + 1]
            if result and result.is_header then
                api.nvim_win_set_cursor(win, {cursor[1] + 1, cursor[2]})
            end
            on_result_hovered(result_index_from_cursor(cursor) + 2)
        elseif key == 'k' then
            local result = results[result_index_from_cursor(cursor) - 1]
            if result and result.is_header then
                api.nvim_win_set_cursor(win, {cursor[1] - 1, cursor[2]})
            end
            on_result_hovered(result_index_from_cursor(cursor) - 2)
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
