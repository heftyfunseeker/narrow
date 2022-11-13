local narrow_utils = require("narrow_utils")
local Window = require("window")
local Layout = require("gui.layout")
local Canvas = require("gui.canvas")
local Text = require("gui.text")
local SearchProvider = require("provider.search_provider")

local api = vim.api

local NarrowEditor = {}

function NarrowEditor:new(config)
  local new_obj = {
    current_provider = nil,

    layout = nil,
    hud_window = nil,
    input_window = nil,
    results_window = nil,

    namespace_id = api.nvim_create_namespace("narrow"),
    entry_header_namespace_id = api.nvim_create_namespace("narrow-entry-header"),
    entry_result_namespace_id = api.nvim_create_namespace("narrow-entry-result"),

    config = {},
    debounce_count = 0,

    -- restore user config
    wo = {
      number = vim.wo.number,
      relativenumber = vim.wo.relativenumber,
    },
  }
  self.__index = self
  setmetatable(new_obj, self)

  new_obj.prev_win = api.nvim_get_current_win()

  vim.wo.number = false
  vim.wo.relativenumber = false

  new_obj:_build_layout(config)
  new_obj:_set_keymaps(config)
  new_obj:_init_provider(config)

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

  vim.wo.number = self.wo.number
  vim.wo.relativenumber = self.wo.relativenumber
end

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
    on_detach = function(_, _)
      vim.on_key(nil, self.namespace_id)
    end,
  })

  vim.on_key(function(key)
    self:on_key(key)
  end, self.namespace_id)

  -- create floating window hud
  self.hud_window = hud_window

  -- input
  self.input_window = input_window

  api.nvim_set_current_win(self.input_window.win)
  api.nvim_win_set_buf(self.input_window.win, self.input_window.buf)
  local prompt_text = " 👉 "
  vim.fn.prompt_setprompt(self.input_window.buf, prompt_text)
  api.nvim_buf_add_highlight(self.input_window.buf, -1, "HUD", 0, 0, prompt_text:len())

  api.nvim_command("startinsert")
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
    ':lua require("narrow").select() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.results_window.buf,
    "n",
    "<C-w>",
    ':lua require("narrow").update_real_file() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_window.buf,
    "n",
    "<C-r>",
    ':lua require("narrow").toggle_search_regex() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
end

function NarrowEditor:_init_provider(config)
  local editor_context = {
    results_canvas = Canvas:new(self.results_window),
    hud_canvas = Canvas:new(self.hud_window),
    header_canvas = Canvas:new(self.entry_header_window),
    entry_header_namespace_id = self.entry_header_namespace_id,
    entry_result_namespace_id = self.entry_result_namespace_id,
  }

  self.current_provider = SearchProvider:new(editor_context)
end

function NarrowEditor:get_config()
  return self.config
end

function NarrowEditor:apply_config(config)
  narrow_utils.array.merge(self.config, config)

  -- -- apply any visual updates to the hud
  -- if self.hud_window then
  --   self:_render_hud()
  -- end
end

function NarrowEditor:resize()
  if self.layout then
    self.layout:render()
  end
  if self.current_provider then
    self.current_provider:on_resized()
  end
end

function NarrowEditor:on_cursor_moved()
  if not self.current_provider then return end

  self.current_provider:on_cursor_moved()
end

function NarrowEditor:on_selected()
  if self.results_window == nil then return false end

  local entry = self.results_window:get_entry_at_cursor(self.entry_result_namespace_id)
  if entry == nil then return false end

  if not self.current_provider then return false end

  return self.current_provider:on_selected(entry, self.prev_win)
end

function NarrowEditor:set_focus_results_window()
  api.nvim_set_current_win(self.results_window.win)
end

function NarrowEditor:set_focus_input_window()
  api.nvim_set_current_win(self.input_window.win)
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
    self.current_provider:on_query_updated(query)
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
