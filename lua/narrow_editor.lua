local narrow_utils = require "narrow_utils"
local NarrowResult = require "narrow_result"
local api = vim.api

local NarrowEditor = {}

local function string_to_lines(str)
  local vals = vim.split(str, "\n")
  local lines = {}
  for _, line in pairs(vals) do
    table.insert(lines, line)
  end
  return lines
end

local function result_index_from_cursor(cursor)
  local cursor_row = cursor[1]
  return cursor_row
end

-- creates the results and preview buffers/windows
function NarrowEditor:_build_layout(config)
  -- TODO: use configuration

  local width = api.nvim_get_option("columns")
  local height = api.nvim_get_option("lines")

  -- create previenarroww buffer
  -- self.preview_buf = api.nvim_create_buf(false, true)
  --
  -- api.nvim_buf_set_option(self.preview_buf, "bufhidden", "wipe")
  -- api.nvim_buf_set_option(self.preview_buf, "buftype", "nofile")
  -- api.nvim_buf_set_option(self.preview_buf, "swapfile", false)
  -- local opts = {
  --   style = "minimal",
  --   relative = "editor",
  --   border = "solid",
  --   width = math.floor(width * .4) - 2,
  --   height = math.floor(height * .5 - 3),
  --   row = math.floor(height * .5),
  --   col = math.floor(width * .6) + 1,
  --   noautocmd = true,
  -- }
  -- self.preview_win = api.nvim_open_win(self.preview_buf, true, opts)

  -- create results buffer
  self.results_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(self.results_buf, "bufhidden", "wipe")
  local opts = {
    style = "minimal",
    relative = "editor",
    border = { "",  "", "","│", "╯", "─", "╰", "│",},
    width = math.floor(width),
    height = math.floor(height * .5 - 3),
    row = math.floor(height * .5) + 1,
    col = 0,
    noautocmd = true,
  }
  self.results_win = api.nvim_open_win(self.results_buf, true, opts)

  vim.wo.number = false
  vim.wo.relativenumber = false
  api.nvim_buf_set_option(self.results_buf, "buftype", "nofile")
  api.nvim_buf_set_option(self.results_buf, "swapfile", false)
  api.nvim_buf_set_option(self.results_buf, "bufhidden", "wipe")

  api.nvim_buf_set_lines(self.results_buf, 0, -1, false, {})

  api.nvim_win_set_cursor(self.results_win, { 1, 3 })
  api.nvim_command("startinsert")

  api.nvim_buf_attach(self.results_buf, false, {
    on_detach = function(detach_str, buf_handle)
      vim.on_key(nil, self.namespace_id)
    end,
  })

  vim.on_key(function(key)
    self:on_key(key)
  end, self.namespace_id)

  -- create floating window hud
  self.hud_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(self.hud_buf, "bufhidden", "wipe")
  local opts = {
    style = "minimal",
    relative = "editor",
    border = { "",  "─", "╮","│", "", "", "", "",},
    width = math.floor(width) - 50,
    height = 2,
    row = math.floor(height * .5) - 2,
    col = 50,
    zindex = 100,
    noautocmd = true,
  }
  self.hud_win = api.nvim_open_win(self.hud_buf, true, opts)
  self:_set_hud_text("")

  api.nvim_set_current_win(self.results_win)
  api.nvim_win_set_buf(self.results_win, self.results_buf)

  -- input
  self.input_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(self.input_buf, "swapfile", false)
  api.nvim_buf_set_option(self.input_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(self.input_buf, "buftype", "prompt")
  local opts = {
    style = "minimal",
    relative = "editor",
    border = { "╭", "─", "","", " ", "", "", "│"},
    width = 50,
    height = 2,
    row = math.floor(height * .5) - 2,
    col = 0,
    zindex = 100,
    noautocmd = true,
  }
  self.input_win = api.nvim_open_win(self.input_buf, true, opts)

  api.nvim_set_current_win(self.input_win)
  api.nvim_win_set_buf(self.input_win, self.input_buf)
  local prompt_text = "   "
  vim.fn.prompt_setprompt(self.input_buf, prompt_text)
  api.nvim_buf_add_highlight(self.input_buf, -1, "HUD", 0, 0, prompt_text:len())
end

function NarrowEditor:_update_hud()
  local results = self.narrow_results
  if #results == 0 then return end

  local c = api.nvim_win_get_cursor(self.results_win)
  local result_index = result_index_from_cursor(c)
  local result = results[result_index]
  -- result headers are interleaved with result lines, so subtract the num of headers
  -- @nicco: refactor results to point to a header and keep them separate?
  local i = result_index
  local result_num = result_index
  -- find our header by walking backwards up the results list
  while i > 0 do
    if results[i].is_header then
      result_num = result_index - results[i].header_number - 1
      break
    end
    i = i - 1
  end
  -- @nicco: we need to calculate this centering
  local results_text = result_num .. "/" .. self.num_results
  self:_set_hud_text(results_text)
end

function NarrowEditor:_set_hud_text(display_text)
  local hud_width = math.floor(api.nvim_get_option("columns") * .5)
  local margin = math.ceil((hud_width - #display_text) / 2)
  local padding = string.rep(" ", margin)
  local display_text_with_padding = padding .. display_text .. padding
  api.nvim_buf_set_lines(self.hud_buf, 0, -1, false, { display_text_with_padding })
  api.nvim_buf_add_highlight(self.hud_buf, -1, "HUD", 0, 0, -1)
end

function NarrowEditor:_define_signs(config)
  api.nvim_command(":sign define narrow_result_pointer text=> texthl=Directory")
end

function NarrowEditor:_apply_signs()
  -- local c = api.nvim_win_get_cursor(self.results_win)
  --
  -- local buf_name = api.nvim_buf_get_name(self.results_buf)
  -- api.nvim_command(":sign unplace * file="..buf_name)
  -- api.nvim_command(":sign place 1 line="..tostring(c[1]).." name=narrow_result_pointer file="..buf_name)
end

-- should we instead expose se.get_results_buf()?
function NarrowEditor:_set_keymaps(config)
  api.nvim_buf_set_keymap(
    self.input_buf,
    "n",
    "<ESC>",
    ':lua require("narrow").close() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_buf,
    "n",
    "<CR>",
    ':lua require("narrow").set_focus_results_window() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_buf,
    "n",
    "j",
    ':lua require("narrow").set_focus_results_window() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_buf,
    "i",
    "<CR>",
    '',
    { nowait = true, noremap = false, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_buf,
    "n",
    "<C-g>",
    ':lua require("narrow").set_focus_input_window() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_buf,
    "n",
    "<CR>",
    ':lua require("narrow").goto_result() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_buf,
    "n",
    "<C-w>",
    ':lua require("narrow").update_real_file() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
end

function NarrowEditor:new(config)
  local new_obj = {
    preview_win = nil,
    preview_buf = nil,
    -- maybe call this editor_buf/win?
    results_win = nil,
    results_buf = nil,
    -- state ---------
    namespace_id = api.nvim_create_namespace "narrow",
    preview_buf_query_id = api.nvim_create_namespace "narrow-query",
    narrow_results = {},
    query = {},
    debounce_count = 0,
    current_header = "",
    current_hl = nil,
    current_parser = nil,
    -- restore user config
    wo = {
      number = vim.wo.number,
      relativenumber = vim.wo.relativenumber
    }
  }
  self.__index = self
  setmetatable(new_obj, self)
  new_obj:_build_layout(config)
  new_obj:_set_keymaps(config)
  new_obj:_define_signs(config)

  -- clear our input listener
  return new_obj
end

function NarrowEditor:drop()
  -- api.nvim_buf_delete(self.preview_buf, {})
  api.nvim_buf_delete(self.results_buf, {})
  api.nvim_buf_delete(self.hud_buf, {})
  api.nvim_buf_delete(self.input_buf, { force = true })
  self.results_buf = nil
  self.preview_buf = nil
  self.input_buf = nil
  self.hud_buf = nil
  self.narrow_results = {}
  self.current_header = ""

  vim.wo.number = self.wo.number
  vim.wo.relativenumber = self.wo.relativenumber
end

function NarrowEditor:set_focus_results_window()
  api.nvim_set_current_win(self.results_win)
end

function NarrowEditor:set_focus_input_window()
  api.nvim_set_current_win(self.input_win)
end

function NarrowEditor:add_grep_result(grep_results)
  local vals = vim.split(grep_results, "\n")
  for _, line in pairs(vals) do
    if line ~= "" then
      local result = NarrowResult:new(line)
      if result then
        table.insert(self.narrow_results, result)
      end
    end
  end
end

function NarrowEditor:render_results()
  local headers_processed = {}
  local results = {}
  -- final results includes header entries to keep display lines and self lines in sync
  local final_results = {}
  local header_number = 0
  for _, result in ipairs(self.narrow_results) do
    if result.header and headers_processed[result.header] == nil then
      headers_processed[result.header] = true

      local header_text = "#" .. result.header
      table.insert(results, header_text)
      table.insert(final_results, NarrowResult:new_header(header_text, header_number))
      header_number = header_number + 1
    end
    table.insert(results, result.display_text)
    table.insert(final_results, result)
  end

  self.narrow_results = final_results
  api.nvim_buf_set_lines(self.results_buf, 0, -1, false, results)

  -- now add highlights
  -- garbage/naive implementation.
  -- Doesnt handle single line with multiple matches,
  -- preserve case sensitivity, or patterns
  local num_results = 0
  for row, result in ipairs(self.narrow_results) do
    if result.is_header then
      api.nvim_buf_add_highlight(self.results_buf, -1, "NarrowHeader", row - 1, 0, -1)
    else
      num_results = num_results + 1
      local result_line = results[row]
      if result_line == nil then
        print("result line is nil with row: " .. row)
        return
      end
      local col_start, col_end = string.find(results[row], self.query)
      if col_start and col_end then
        api.nvim_buf_add_highlight(self.results_buf, -1, "NarrowMatch", row - 1, col_start - 1, col_end)
      end
    end
  end
  self.num_results = num_results
  self:_update_hud()
end

function NarrowEditor:get_result()
  local c = api.nvim_win_get_cursor(self.results_win)
  local results = self.narrow_results
  local result = results[result_index_from_cursor(c)]

  if result == nil then
    return nil
  end
  if result.is_header then
    return nil
  end

  return result
end

function NarrowEditor:search(query_term)
  -- clear previous results out
  self.narrow_results = {}

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  Handle = vim.loop.spawn(
    "rg",
    {
      args = { query_term, "--smart-case", "--vimgrep", "-M", "1024" },
      stdio = { nil, stdout, stderr },
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      Handle:close()

      self:render_results()
    end)
  )

  local onread = function(err, input_stream)
    if err then
      print("ERROR: ", err)
    end

    if input_stream then
      self:add_grep_result(input_stream)
    end
  end

  vim.loop.read_start(stdout, onread)
  vim.loop.read_start(stderr, onread)
end

function NarrowEditor:on_key(key)
  local curr_win = api.nvim_get_current_win()
  local cursor = api.nvim_win_get_cursor(self.results_win)
  local on_result_hovered = function(result)
    -- api.nvim_buf_clear_namespace(self.preview_buf, self.namespace_id, 0, -1)

    self:_update_hud()

    -- if result and result.header and self.current_header ~= result.header then
    --   local file_str = narrow_utils.read_file_sync(result.header)
    --   self.current_header = result.header
    --   self.preview_lines = string_to_lines(file_str)
    --   api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, self.preview_lines)
    --   narrow_utils.hl_buffer(self, result.header)
    --   api.nvim_buf_add_highlight(self.preview_buf, self.namespace_id, "NarrowMatch", result.row - 1, result.column - 1, result.column + #self.query - 1)
    -- elseif result and result.header then
    --   if result.row < #self.preview_lines then
    --     api.nvim_win_set_cursor(self.preview_win, { result.row, 0 })
    --     self:_apply_signs()
    --     api.nvim_buf_add_highlight(self.preview_buf, self.namespace_id, "NarrowMatch", result.row - 1, result.column - 1, result.column + #self.query - 1)
    --   end
    -- end
  end

  local schedule_hover = function(key)
    vim.defer_fn(function()
      if self.results_buf == nil or self.results_win == nil then
        return
      end
      local c = api.nvim_win_get_cursor(self.results_win)
      local results = self.narrow_results
      local result = results[result_index_from_cursor(c)]

      if result == nil then
        return
      end
      if result.is_header then
        return
      end
      if result then
        on_result_hovered(result)
      end
    end, 0)
  end

  if curr_win == self.results_win then
    if api.nvim_get_mode().mode == "n" then
      schedule_hover(key)
    end
  end
  -- early return if we arent' inserting text
  -- we should also test if we're on the query input line
  if curr_win ~= self.input_win or api.nvim_get_mode().mode ~= "i" then
    return
  end

  self.debounce_count = self.debounce_count + 1
  vim.defer_fn(function()
    if self.results_buf == nil or self.input_buf == nil then
      return
    end

    self.debounce_count = self.debounce_count - 1
    if self.debounce_count > 0 then
      return
    end

    local query = api.nvim_buf_get_lines(self.input_buf, 0, 1, false)[1]
    local prompt_text = vim.fn.prompt_getprompt(self.input_buf)
    local _, e = string.find(query, prompt_text)
    query = query:sub(e)
    self.query = query
    if query ~= nil and #query >= 2 then
      self:search(query)
    else
      -- clear previous results
      -- TODO: make function
      api.nvim_buf_set_lines(self.results_buf, 0, -1, false, {})
    end
  end, 100)
end

function NarrowEditor:update_real_file()
  local current_header = ""
  local buffer_lines = api.nvim_buf_get_lines(self.results_buf, 0, -1, false)

  if #buffer_lines - 1 ~= #self.narrow_results then
    print("validation error: number of lines were modified")
    return
  end

  local changes = {}
  for index = 2, #buffer_lines, 1 do
    local display_text = buffer_lines[index]
    local narrow_result = self.narrow_results[index - 1]
    if narrow_result.is_header then
      if narrow_result.text == display_text then
        -- cache the header for validations across currently processing results
        current_header = narrow_result.text
      else
        print("bad header: couldn't find: " .. display_text)
        return
      end
    else
      if display_text ~= narrow_result.display_text then
        local row, col, text = string.match(display_text, "[%s]*(%d+):[%s]*(%d+):(.*)")

        -- validate the row and col are the same
        if tonumber(row) == narrow_result.row and tonumber(col) == narrow_result.column then
          table.insert(changes, { narrow_result = narrow_result, changed_text = text })
        else
          print("validation error: row and column were modified")
          return
        end
      end
    end
  end

  -- TODO: batch these changes by header to avoid the io thrashing
  for _, change in ipairs(changes) do
    local nr = change.narrow_result
    local file_lines = string_to_lines(narrow_utils.read_file_sync(change.narrow_result.header))
    file_lines[nr.row] = change.changed_text
    narrow_utils.write_file_sync(change.narrow_result.header, table.concat(file_lines, "\n"))
  end
end

return NarrowEditor
