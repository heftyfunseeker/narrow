 -- local has_ts, _ = pcall(require, "nvim-treesitter")
local _, ts_configs = pcall(require, "nvim-treesitter.configs")
local _, ts_parsers = pcall(require, "nvim-treesitter.parsers")

local api = vim.api

-- TODO moves these to state
local buf, win local namespace_id = nil
local state = {
    narrow_results = {},
    debounce_count = 0,
    query = "",
    current_header = ""
}

local function readFileSync(path)
  local fd = assert(vim.loop.fs_open(path, "r", 438))
  local stat = assert(vim.loop.fs_fstat(fd))
  local data = assert(vim.loop.fs_read(fd, stat.size, 0))
  assert(vim.loop.fs_close(fd))
  return data
end

local function hl_buffer(result_header)
    local ext_to_type = {}
    ext_to_type[".lua"] = "lua"
    ext_to_type[".rs"] = "rust"

    local ext = result_header:match("^.+(%..+)$")
    local ft = ext_to_type[ext]
    if ft == nil then ft = ext:sub(2, -1) end

    local ft_parser = ts_parsers.get_parser(state.preview_buf, ft)
    if ft_parser ~= state.current_parser then
        print("destroying highlighter")
        if state.current_hl then
            state.current_hl:destroy()
        end
        state.current_parser = ft_parser
    end

    if ft_parser then
        state.current_hl = vim.treesitter.highlighter.new(ft_parser)
    else
        print("setting regex syntax")
        api.nvim_buf_set_option(state.preview_buf, 'syntax', ft)
    end
end

local function open_search_buffer()
    -- TODO: we should set custom types for our result and preview buffer?
    -- api.nvim_buf_set_option(buf, 'filetype', 'nvim-oldfile')
    state.debounce_count = 0
    state.narrow_results = {}
    state.query = ""
    state.preview_win = api.nvim_get_current_win()
    print("opening search buffer with current window list: " .. vim.inspect(api.nvim_list_wins()))
    api.nvim_command("edit narrow-preview")
    state.preview_buf = api.nvim_get_current_buf()
    print("dumping handles")
    print("state_win: " .. state.preview_win)
    print("state_buf: " .. state.preview_buf)

    api.nvim_buf_set_option(state.preview_buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(state.preview_buf, 'swapfile', false)
    api.nvim_buf_set_option(state.preview_buf, 'bufhidden', 'wipe')
    api.nvim_command("split narrow-results")
    win = api.nvim_get_current_win()
    buf = api.nvim_win_get_buf(win)
    api.nvim_buf_set_option(buf, 'buftype', 'nofile')
    api.nvim_buf_set_option(buf, 'swapfile', false)
    api.nvim_buf_set_option(buf, 'bufhidden', 'wipe')

    api.nvim_buf_set_lines(buf, 0, 0, false, {" >  "})
    api.nvim_buf_set_lines(buf, 1, -1, false, {})
    api.nvim_win_set_cursor(win, {1, 3})

    api.nvim_command("startinsert")
    print("win: " .. win)
    print("buf: " .. buf)
    api.nvim_buf_set_keymap(buf, 'n', '<ESC>', ':lua require("narrow").narrow_exit() <CR>', { nowait = true, noremap = true, silent = true })

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

local function result_index_from_cursor(cursor)
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

local function string_to_lines(str)
   local vals = vim.split(str, "\n")
   local lines = {}
   for _, line in pairs(vals) do
      table.insert(lines, line)
   end
   return lines
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
    print("searching with .. " .. query_term)
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
         print("detaching on_key handler")
         vim.on_key(nil, namespace_id) end, })

   vim.on_key(function(key)
      local cursor = api.nvim_win_get_cursor(win)
      if cursor[1] == 1 and cursor[2] < 3 then
          api.nvim_buf_set_lines(buf, 0, 0, false, {" >  "})
          api.nvim_buf_set_lines(buf, 1, -1, false, {})
          api.nvim_win_set_cursor(win, {1, 3})
      end


    local on_result_hovered = function(result)
        if result and result.header and state.current_header ~= result.header then
            local file_str = readFileSync(result.header)
            state.current_header = result.header
            state.preview_lines = string_to_lines(file_str)
            api.nvim_buf_set_lines(state.preview_buf, 0, -1, false, state.preview_lines)
            hl_buffer(result.header)
        elseif result and result.header then
            if result.row < #state.preview_lines then
                api.nvim_win_set_cursor(state.preview_win, {result.row, 0})
            end
        end
        -- TODO: do I need this?
        -- switch back to result buffer
        api.nvim_set_current_win(win)
        api.nvim_set_current_buf(buf)
    end

    local schedule_hover = function(key)
        vim.defer_fn(function()
            if buf == nil or win == nil then return end
            local c = api.nvim_win_get_cursor(win)
            local results = state.narrow_results
            local result = results[result_index_from_cursor(c)]

            if result == nil then return end
            if result.is_header then return end
            if result then on_result_hovered(result) end
        end, 0)
    end

    if api.nvim_get_mode().mode == 'n' then
        print("cursor at: " .. vim.inspect(cursor))
        schedule_hover(key)
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
      print(state.debounce_count)
      vim.defer_fn(function()
          if buf == nil then return end

          state.debounce_count = state.debounce_count - 1
          if state.debounce_count > 0 then
              return
          end

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

local function narrow_exit()
    api.nvim_buf_delete(state.preview_buf, {})
    api.nvim_buf_delete(buf, {})
    buf = nil
    state.preview_buf = nil
    state.narrow_results = 0
    state.current_header = ""
end

return {
   narrow = narrow,
   narrow_exit = narrow_exit
}
