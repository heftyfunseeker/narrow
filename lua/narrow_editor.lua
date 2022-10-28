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
  local results_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_border({ "", "", "", "│", "╯", "─", "╰", "│" })

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
      :set_results_window(results_window)
      :set_hud_window(hud_window)
      :set_input_window(input_window)
      :render()

  self.results_window = results_window
  self.results_window:set_lines(0, -1, {})

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
  self:_set_hud_text("")

  -- input
  self.input_window = input_window

  api.nvim_set_current_win(self.input_window.win)
  api.nvim_win_set_buf(self.input_window.win, self.input_window.buf)
  local prompt_text = " 👉 "
  vim.fn.prompt_setprompt(self.input_window.buf, prompt_text)
  api.nvim_buf_add_highlight(self.input_window.buf, -1, "HUD", 0, 0, prompt_text:len())

  api.nvim_command("startinsert")
end

function NarrowEditor:_update_hud()
  local results = self.narrow_results
  if #results == 0 then
    return
  end

  local c = api.nvim_win_get_cursor(self.results_window.win)
  local result_index = c[1]
  -- result headers are interleaved with result lines, so subtract the num of headers
  local i = result_index
  local result_num = result_index
  -- find our header by walking backwards up the results list
  while i > 0 do
    if results[i] ~= nil and results[i].is_header then
      result_num = result_index - results[i].header_number - 1
      break
    end
    i = i - 1
  end

  if self.num_results ~= nil and result_num ~= nil then
    local results_text = result_num .. "/" .. self.num_results
    self:_set_hud_text(results_text)
  end
end

function NarrowEditor:_set_hud_text(display_text)
  self.hud_window:set_lines(0, -1, { display_text_with_padding })
  api.nvim_buf_add_highlight(self.hud_window.buf, -1, "HUD", 0, 0, -1)
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
  end
end

function NarrowEditor:get_result()
  local entry = self.results_window:get_entry_at_cursor()
  if entry == nil or entry[1] == nil then return end

  entry = entry[1]
  print("entry: " .. vim.inspect(entry))
  local result = self.entry_id_to_result[entry[1]]

  if result == nil then
    return nil
  end

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
  local canvas = Canvas:new()

  local headers_processed = {}
  self.entry_id_to_result = {}

  local row = 0
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
          :apply_style(Style.types.virtual_text, hl_name)
          :render(canvas)

      Text:new()
          :set_text(" " .. result.header)
          :set_pos(1, row)
          :apply_style(Style.types.virtual_text, "NarrowHeader")
          :render(canvas)

      row = row + 1
    end

    Text:new()
        :set_text(result.entry_header)
        :set_pos(0, row)
        :apply_style(Style.types.virtual_text, "Comment")
        :mark_entry(row) -- mark this as a selectable entry
        :render(canvas)

    Text:new()
        :set_text(result.entry_text)
        :set_pos(string.len(result.entry_header) + 1, row)
        :render(canvas)

    self.entry_id_to_result[row] = result
    row = row + 1
  end

  canvas:render_to_window(self.results_window)
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

function NarrowEditor:schedule_result_hovered()
  vim.defer_fn(function()
    if self.results_window == nil then
      return
    end

    local c = api.nvim_win_get_cursor(self.results_window.win)
    local result = self.narrow_results[c[1]]
    if result == nil or result.is_header then
      return
    end

    self:on_result_hovered(result)
  end, 0)
end

function NarrowEditor:on_result_hovered(_result)
  self:_update_hud()
end

function NarrowEditor:on_key(key)
  local escape_key = "\27"
  if key == escape_key then
    return
  end

  local curr_win = api.nvim_get_current_win()

  if curr_win == self.results_window.win then
    if api.nvim_get_mode().mode ~= "i" then
      self:schedule_result_hovered()
    end
  end

  -- early return if we arent' making a query
  if curr_win ~= self.input_window.win and api.nvim_get_mode().mode ~= "i" then
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

    local query = self.input_window:get_lines(0, 1)[1]
    local prompt_text = vim.fn.prompt_getprompt(self.input_window.buf)
    local _, e = string.find(query, prompt_text)
    query = query:sub(e + 1)
    self.query = query
    if query ~= nil and #query >= 2 then
      self:search(query)
    else
      -- clear previous results
      -- TODO: make function
      api.nvim_buf_clear_namespace(self.results_window.buf, self.namespace_id, 0, -1)
      self.results_window:set_lines(0, -1, {})
    end
  end, 5)
end

function NarrowEditor:update_real_file()
  if true then return end

  -- fix narrow_result format below
  local buffer_lines = self.results_window:get_lines(0, -1)

  if #buffer_lines ~= #self.narrow_results then
    print("validation error: number of lines were modified " .. #buffer_lines .. " ~= " .. #self.narrow_results)
    return
  end

  local changes = {}
  for line, _ in ipairs(self.narrow_results) do
    local display_text = buffer_lines[line]
    local narrow_result = self.narrow_results[line]
    if narrow_result.is_header ~= true and display_text ~= narrow_result.display_text then
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

  -- todo pop-up confirmation modal instead
  print("narrow: applying " .. #changes .. " changes to real files")

  -- TODO: batch these changes by header to avoid the io thrashing
  for _, change in ipairs(changes) do
    local nr = change.narrow_result
    local file_lines = narrow_utils.string_to_lines(narrow_utils.read_file_sync(change.narrow_result.header))
    file_lines[nr.row] = change.changed_text
    narrow_utils.write_file_sync(change.narrow_result.header, table.concat(file_lines, "\n"))
  end

  print("narrow: finished applying " .. #changes .. " changes")
end

return NarrowEditor
