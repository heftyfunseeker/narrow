local narrow_utils = require("narrow_utils")
local NarrowResult = require("narrow_result")
local Window = require("window")
local Layout = require("gui.layout")
local Canvas = require("gui.canvas")
local Text = require("gui.text")
local devicons = require("nvim-web-devicons")

local api = vim.api

local NarrowEditor = {}

-- creates the results and preview buffers/windows
function NarrowEditor:_build_layout(config)
  local entry_header_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_win_option("scrollbind", true)
      :set_border({ "", "", "", "", "", "─", "╰", "│" })

  local results_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_win_option("scrollbind", true)
      :set_win_option("wrap", false)
      :set_border({ "", "", "", "│", "╯", "─", "", "" })

  local hud_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border({ "", "─", "╮", "│", "", "", "", "" })

  local input_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "prompt")
      :set_buf_option("swapfile", false)
      :set_border({ "╭", "─", "", "", " ", "", "", "│" })

  self.layout = Layout
      :new()
      :set_entry_header_window(entry_header_window)
      :set_results_window(results_window)
      :set_hud_window(hud_window)
      :set_input_window(input_window)
      :render()

  self.entry_header_window = entry_header_window

  self.results_window = results_window
  self.results_window:set_lines({})

  api.nvim_buf_attach(self.results_window.buf, false, {
    on_detach = function(detach_str, buf_handle)
      vim.on_key(nil, self.namespace_id)
    end,
  })

  vim.on_key(function(key)
    self:on_key(key)
  end, self.namespace_id)

  -- create floating window hud
  self.hud_window = hud_window
  self:_render_hud()

  -- input
  self.input_window = input_window

  api.nvim_set_current_win(self.input_window.win)
  api.nvim_win_set_buf(self.input_window.win, self.input_window.buf)
  local prompt_text = " 👉 "
  vim.fn.prompt_setprompt(self.input_window.buf, prompt_text)
  api.nvim_buf_add_highlight(self.input_window.buf, -1, "HUD", 0, 0, prompt_text:len())

  api.nvim_command("startinsert")
end

function NarrowEditor:_render_hud()
  self.hud_window:clear()

  if self.results_window == nil then return end

  local namespace_id = self.entry_result_namespace_id

  local entry = self.results_window:get_entry_at_cursor(namespace_id)
  if entry == nil then
    namespace_id = self.entry_header_namespace_id
    entry = self.results_window:get_entry_at_cursor(namespace_id)
  end

  if entry == nil then
    return
  end

  local entry_index = entry[1] -- id is the index in namespace
  local entries = self.results_window:get_all_entries(namespace_id)
  local hud_width, _ = self.hud_window:get_dimensions()

  local canvas = Canvas:new()
  Text
      :new()
      :set_text(string.format("%d/%d  ", entry_index, #entries))
      :set_alignment(Text.AlignmentType.right)
      :set_pos(0, 0)
      :set_dimensions(hud_width, 1)
      :render(canvas)

  -- @todo: lets have the window take a canvas instead to render
  -- api kinda ping pongs
  canvas:render_to_window(self.hud_window)
end

-- should we instead expose se.get_results_buf()?
function NarrowEditor:_set_keymaps(config)
  api.nvim_buf_set_keymap(
    self.input_window.buf,
    "n",
    "<ESC>",
    ':lua require("narrow").close() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_window.buf,
    "n",
    "<CR>",
    ':lua require("narrow").set_focus_results_window() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_window.buf,
    "n",
    "j",
    ':lua require("narrow").set_focus_results_window() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(self.input_window.buf, "i", "<CR>", "", { nowait = true, noremap = false, silent = true })
  api.nvim_buf_set_keymap(
    self.results_window.buf,
    "n",
    "<C-g>",
    ':lua require("narrow").set_focus_input_window() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_window.buf,
    "n",
    "<CR>",
    ':lua require("narrow").goto_result() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_window.buf,
    "n",
    "<C-w>",
    ':lua require("narrow").update_real_file() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
end

function NarrowEditor:new(config)
  local new_obj = {
    layout = nil,
    hud_window = nil,
    input_window = nil,
    results_window = nil,

    -- state ---------
    namespace_id = api.nvim_create_namespace("narrow"),
    entry_header_namespace_id = api.nvim_create_namespace("narrow/entry/header"),
    entry_result_namespace_id = api.nvim_create_namespace("narrow/entry/result"),
    narrow_results = {},
    query = {},
    debounce_count = 0,
    -- restore user config
    wo = {
      number = vim.wo.number,
      relativenumber = vim.wo.relativenumber,
    },
  }
  self.__index = self
  setmetatable(new_obj, self)

  vim.wo.number = false
  vim.wo.relativenumber = false

  new_obj:_build_layout(config)
  new_obj:_set_keymaps(config)

  return new_obj
end

function NarrowEditor:drop()
  self.entry_header_window:drop()
  self.entry_header_window = nil

  self.results_window:drop()
  self.results_window = nil

  self.input_window:drop()
  self.input_window = nil

  self.hud_window:drop()
  self.hud_window = nil

  self.layout = nil
  self.narrow_results = {}

  vim.wo.number = self.wo.number
  vim.wo.relativenumber = self.wo.relativenumber
end

function NarrowEditor:resize()
  if self.layout then
    self.layout:render()
    self:_render_hud()
  end
end

function NarrowEditor:on_cursor_moved()
  self:_render_hud()
end

function NarrowEditor:get_result()
  if self.results_window == nil then return nil end

  local entry = self.results_window:get_entry_at_cursor(self.entry_result_namespace_id)
  if entry == nil then return end

  local result = self.narrow_results[entry[1]]
  if result == nil then return nil end

  return result
end

function NarrowEditor:set_focus_results_window()
  api.nvim_set_current_win(self.results_window.win)
end

function NarrowEditor:set_focus_input_window()
  api.nvim_set_current_win(self.input_window.win)
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
  self.results_window:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })

  local canvas = Canvas:new()
  local header_canvas = Canvas:new()

  local headers_processed = {}

  local row = 0
  local entry_result_index = 1
  local entry_header_index = 1
  for _, result in ipairs(self.narrow_results) do
    if result.header and headers_processed[result.header] == nil then
      headers_processed[result.header] = true

      local icon, hl_name = devicons.get_icon(
        result.header,
        narrow_utils.get_file_extension(result.header),
        { default = true }
      )
      Text:new()
          :set_text(icon)
          :set_pos(0, row)
          :apply_style(Style.Types.virtual_text, { hl_name = hl_name, pos_type = "overlay" })
          :render(canvas)

      Text:new()
          :set_text(" " .. result.header)
          :set_pos(1, row)
          :apply_style(Style.Types.virtual_text, { hl_name = "NarrowHeader", pos_type = "overlay" })
          :mark_entry(entry_header_index, self.entry_header_namespace_id)-- mark this as a selectable entry
          :render(canvas)

      row = row + 1
      entry_header_index = entry_header_index + 1
    end

    Text:new()
        :set_text(result.entry_text)
        :set_pos(0, row)
        :mark_entry(entry_result_index, self.entry_result_namespace_id)-- mark this as a selectable entry
        :render(canvas)

    Text:new()
        :set_text(self:get_query_result(result.entry_text, result.column))
        :set_pos(result.column - 1, row)
        :apply_style(Style.Types.highlight, { hl_name = "NarrowMatch" })
        :render(canvas)

    Text:new()
        :set_text(result.entry_header)
        :set_dimensions(5, 1)
        :set_alignment(Text.AlignmentType.right)
        :set_pos(0, row)
        :apply_style(Style.Types.virtual_text, { hl_name = "Comment", pos_type = "overlay" })
        :render(header_canvas)

    row = row + 1
    entry_result_index = entry_result_index + 1
  end

  canvas:render_to_window(self.results_window)
  header_canvas:render_to_window(self.entry_header_window)

  self:_render_hud()
end

-- @todo: probably a can of worms in here, but this works for now
function NarrowEditor:get_query_result(line, start)
  local is_case_insensitive = string.match(self.query, "%u") == nil
  local target = line
  if is_case_insensitive then
    target = string.lower(line)
  end
  local i, j = string.find(target, self.query, start - 1)
  if i == nil or j == nil then
    print("error: could not resolve the narrow query result")
    return self.query -- just return the query to see what happened
  end
  return line:sub(i, j)
end

function NarrowEditor:search(query_term)
  -- clear previous results out
  self.narrow_results = {}

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  if Handle ~= nil then
    Handle:close()
    Handle = nil
  end

  Handle = vim.loop.spawn(
    "rg",
    {
      --args = { query_term, "--word-regexp", "--smart-case", "--vimgrep", "-M", "1024" },
      args = { query_term, "--smart-case", "--vimgrep", "-M", "1024" },
      stdio = { nil, stdout, stderr },
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      Handle:close()
      Handle = nil

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
  local escape_key = "\27"
  if key == escape_key then
    return
  end

  local curr_win = api.nvim_get_current_win()

  -- early return if we arent' making a query
  if curr_win ~= self.input_window.win or api.nvim_get_mode().mode ~= "i" then
    return
  end

  self.debounce_count = self.debounce_count + 1
  vim.defer_fn(function()
    if self.results_window == nil or self.input_window == nil then
      return
    end

    self.debounce_count = self.debounce_count - 1
    if self.debounce_count > 0 then
      return
    end

    local query = self.input_window:get_buffer_lines(0, 1)[1]
    local prompt_text = vim.fn.prompt_getprompt(self.input_window.buf)
    local _, e = string.find(query, prompt_text)
    query = query:sub(e + 1)
    self.query = query
    if query ~= nil and #query >= 2 then
      self:search(query)
    else
      self.results_window:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
      self.entry_header_window:clear()
      self.hud_window:clear()
    end
  end, 5)
end

-- @todo: To reload opened files that have changed because of this function,
-- should we iterate through open file that were modified and `:e!` to reload them?
-- Maybe we have this as a settings for users to configure?
function NarrowEditor:update_real_file()
  -- the lines we set initially from the canvas
  local original_lines = self.results_window:get_lines()
  -- the lines that are currently visible on screen
  local buffer_lines = self.results_window:get_buffer_lines(0, -1)

  if #buffer_lines ~= #original_lines then
    print("narrow warning: Cannot update files. Number of lines were modified")
    return
  end

  local changes = {}
  for row, line in ipairs(buffer_lines) do
    local original_line = original_lines[row]
    if line ~= original_line then
      local entry = self.results_window:get_entry_at_row(row - 1, self.entry_result_namespace_id)
      if entry == nil then
        print("narrow warning: Entry was corrupted. Aborting update to files")
        return
      end
      local narrow_result = self.narrow_results[entry[1]]
      table.insert(changes, { narrow_result = narrow_result, changed_text = line })
    end
  end

  -- -- todo pop-up confirmation modal instead
  print("narrow: Applying " .. #changes .. " changes to real files")

  -- TODO: batch these changes by header to avoid the io thrashing
  for _, change in ipairs(changes) do
    local nr = change.narrow_result
    local file_lines = narrow_utils.string_to_lines(narrow_utils.read_file_sync(change.narrow_result.header))
    file_lines[nr.row] = change.changed_text
    narrow_utils.write_file_sync(change.narrow_result.header, table.concat(file_lines, "\n"))
  end

  print("narrow: Finished applying " .. #changes .. " changes")
end

return NarrowEditor
