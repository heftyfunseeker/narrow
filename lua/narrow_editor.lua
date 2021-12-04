local utils = require "utils"
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

-- creates the results and preview buffers/windows
function NarrowEditor:_build_layout(config)
  -- TODO: use configuration

  -- create preview buffer
  self.preview_win = api.nvim_get_current_win()
  api.nvim_command("noa edit narrow-preview")
  self.preview_buf = api.nvim_get_current_buf()

  api.nvim_buf_set_option(self.preview_buf, "buftype", "nowrite")
  api.nvim_buf_set_option(self.preview_buf, "swapfile", false)
  api.nvim_buf_set_option(self.preview_buf, "bufhidden", "wipe")

  -- create results buffer
  api.nvim_command("noa split narrow-results")

  vim.wo.number = false
  vim.wo.relativenumber = false
  -- TODO: result buffer works, but the preview buffer looks borked
  -- api.nvim_command("set cursorline")
  -- api.nvim_command("hi def link CursorLine QuickFixLine") 
  self.results_win = api.nvim_get_current_win()
  self.results_buf = api.nvim_win_get_buf(self.results_win)
  api.nvim_buf_set_option(self.results_buf, "buftype", "nofile")
  api.nvim_buf_set_option(self.results_buf, "swapfile", false)
  api.nvim_buf_set_option(self.results_buf, "bufhidden", "wipe")

  api.nvim_buf_set_lines(self.results_buf, 0, 0, false, { " >  " })
  api.nvim_buf_set_lines(self.results_buf, 1, -1, false, {})

  api.nvim_win_set_cursor(self.results_win, { 1, 3 })
  api.nvim_command("startinsert")

  api.nvim_buf_attach(self.result_buf, false, {
    on_detach = function(detach_str, buf_handle)
      vim.on_key(nil, self.namespace_id)
    end,
  })

  vim.on_key(function(key)
    self:on_key(key)
  end, self.namespace_id)
end

function NarrowEditor:_define_signs(config)
  api.nvim_command(":sign define narrow_result_pointer text=> texthl=Directory")
end

function NarrowEditor:_apply_signs()
  local c = api.nvim_win_get_cursor(self.results_win)

  local buf_name = api.nvim_buf_get_name(self.results_buf)
  api.nvim_command(":sign unplace * file="..buf_name)
  api.nvim_command(":sign place 1 line="..tostring(c[1]).." name=narrow_result_pointer file="..buf_name)
end

-- should we instead expose se.get_results_buf()?
function NarrowEditor:_set_keymaps(config)
  api.nvim_buf_set_keymap(
    self.results_buf,
    "n",
    "<ESC>",
    ':lua require("narrow").narrow_exit() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_buf,
    "n",
    "<CR>",
    ':lua require("narrow").narrow_open_result() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_buf,
    "n",
    "<C-w>",
    ':lua require("narrow").narrow_update_real_file() <CR>',
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
    narrow_results = {},
    query = {},
    debounce_count = 0,
    current_header = "",
    current_hl = nil,
    current_parser = nil,
    -- restore user config
    wo = {
      number = vim.wo.number,
      relativenumber = vim.wo.relativenumber }
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
  api.nvim_buf_delete(self.preview_buf, {})
  api.nvim_buf_delete(self.results_buf, {})
  self.results_buf = nil
  self.preview_buf = nil
  self.narrow_results = 0
  self.current_header = ""

  vim.wo.number = self.wo.number
  vim.wo.relativenumber = self.wo.relativenumber
end

function NarrowEditor:add_grep_result(grep_results)
  local vals = vim.split(grep_results, "\n")
  for _, line in pairs(vals) do
    if line ~= "" then
      local result = NarrowResult:new(line)
      if result.header then
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
  for _, result in ipairs(self.narrow_results) do
    if result.header and headers_processed[result.header] == nil then
      headers_processed[result.header] = true

      local header_text = "#" .. result.header
      table.insert(results, header_text)
      table.insert(final_results, NarrowResult:new_header(header_text))
    end
    table.insert(results, result.display_text)
    table.insert(final_results, result)
  end

  self.narrow_results = final_results
  api.nvim_buf_set_lines(self.results_buf, 1, -1, false, results)

  -- now add highlights
  -- garbage/naive implementation.
  -- Doesnt handle single line with multiple matches,
  -- preserve case sensitivity, or patterns
  for row, result in ipairs(self.narrow_results) do
    if result.is_header then
      api.nvim_buf_add_highlight(self.results_buf, -1, "NarrowHeader", row, 0, -1)
    else
      local col_start, col_end = string.find(results[row], self.query)
      if col_start and col_end then
        api.nvim_buf_add_highlight(self.results_buf, -1, "NarrowMatch", row, col_start - 1, col_end)
      end
    end
  end
end

local function result_index_from_cursor(cursor)
  local cursor_row = cursor[1]
  return cursor_row - 1
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
  print("searching with .. " .. query_term)
  -- clear previous results out
  self.narrow_results = {}

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

      self:render_results()
    end)
  )

  local onread = function(err, input_stream)
    if err then
      print("ERROR: ", err) end

    if input_stream then
      self:add_grep_result(input_stream)
    end
  end

  vim.loop.read_start(stdout, onread)
  vim.loop.read_start(stderr, onread)
end

function NarrowEditor:on_key(key)
  local cursor = api.nvim_win_get_cursor(self.results_win)
  if cursor[1] == 1 and cursor[2] < 3 then
    api.nvim_buf_set_lines(self.results_buf, 0, 0, false, { " >  " })
    api.nvim_buf_set_lines(self.results_buf, 1, -1, false, {})
    api.nvim_win_set_cursor(self.results_win, { 1, 3 })
  end

  local on_result_hovered = function(result)
    if result and result.header and self.current_header ~= result.header then
      local file_str = utils.read_file_sync(result.header)
      self.current_header = result.header
      self.preview_lines = string_to_lines(file_str)
      api.nvim_buf_set_lines(self.preview_buf, 0, -1, false, self.preview_lines)
      utils.hl_buffer(self, result.header)
    elseif result and result.header then
      if result.row < #self.preview_lines then
        api.nvim_win_set_cursor(self.preview_win, { result.row, 0 })
        self:_apply_signs()
      end
    end
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

  if api.nvim_get_mode().mode == "n" then
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

  self.debounce_count = self.debounce_count + 1
  vim.defer_fn(function()
    if self.results_buf == nil then
      return
    end

    self.debounce_count = self.debounce_count - 1
    if self.debounce_count > 0 then
      return
    end

    local query = api.nvim_buf_get_lines(self.results_buf, 0, 1, false)[1]
    query = string.gsub(query, "%s+", "")
    query = string.match(query, ">(.*)")
    self.query = query
    if query ~= nil and #query >= 2 then
      self:search(query)
    else
      -- clear previous results
      -- TODO: make function
      api.nvim_buf_set_lines(self.results_buf, 1, -1, false, {})
    end
  end, 500)
end

function NarrowEditor:update_real_file()
  local current_header = ""
  local buffer_lines = api.nvim_buf_get_lines(self.results_buf, 0, -1, false)

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
      end
    else
      if display_text ~= narrow_result.display_text then
        -- add the changed line
        table.insert(changes, { narrow_result = narrow_result, changed_text = display_text } )
        print("line: " .. display_text .. " not the same")
      end
    end
  end

  -- we should batch these changes by header to avoid the io thrashing
  -- but we'll start with this naive impl
  for _, change in ipairs(changes) do
    local nr = change.narrow_result
    local file_lines = utils.read_file_sync(change.narrow_result.header)
    file_lines[nr.row] = change.changed_text
    utils.write_file_sync(change.narrow_result.header, file_lines)
  end
end

return NarrowEditor
