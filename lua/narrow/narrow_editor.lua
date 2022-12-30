local narrow_utils = require("narrow.narrow_utils")
local Window = require("narrow.window")
local Layout = require("narrow.gui.layout")
local Canvas = require("narrow.gui.canvas")
local SearchProvider = require("narrow.provider.search_provider")
local Store = require("narrow.redua.store")

local api = vim.api

local NarrowEditor = {
  SearchModes = {
    Project = 0,
    CurrentFile = 1,
  }
}

function NarrowEditor:new(config)
  local new_obj = {
    layout = nil,
    hud_window = nil,
    input_window = nil,
    results_window = nil,

    namespace_id = api.nvim_create_namespace("narrow"),
    entry_header_namespace_id = api.nvim_create_namespace("narrow-entry-header"),
    entry_result_namespace_id = api.nvim_create_namespace("narrow-entry-result"),

    config = {},
    provider = nil,
  }

  self.__index = self
  setmetatable(new_obj, self)

  new_obj.prev_win = api.nvim_get_current_win()

  new_obj:_build_layout(config)
  new_obj:_set_keymaps(config)

  new_obj.store = Store:new(function(state, action)
    if new_obj.provider then
      return new_obj.provider:handle_action(state, action)
    end
  end)

  new_obj:_init_provider(config)

  new_obj.store:dispatch({ type = "init_store" })

  vim.on_key(function(key)
    self.store:dispatch({
      type = "key_pressed",
      payload = key
    })
  end, self.namespace_id)

  return new_obj
end

function NarrowEditor:drop()
  vim.on_key(nil, self.namespace_id)

  self.entry_header_window:drop()
  self.entry_header_window = nil

  self.results_window:drop()
  self.results_window = nil

  self.input_window:drop()
  self.input_window = nil

  self.hud_window:drop()
  self.hud_window = nil

  self.layout = nil

  self.provider = nil
  self.store = nil
end

function NarrowEditor:get_store()
  return self.store
end

function NarrowEditor:get_provider()
  return self.provider
end

-- creates the results and preview buffers/windows
function NarrowEditor:_build_layout(config)
  local entry_header_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_win_option("scrollbind", true)
      :set_win_option("winhl", "NormalFloat:Normal,FloatBorder:Function")
      :set_border({ "", "", "", "", "", "─", "╰", "│" })

  local results_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_win_option("scrollbind", true)
      :set_win_option("wrap", false)
      :set_win_option("winhl", "NormalFloat:Normal,FloatBorder:Function")
      :set_border({ "", "", "", "│", "╯", "─", "", "" })

  local hud_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      :set_buf_option("swapfile", false)
      :set_win_option("winhl", "NormalFloat:Normal,FloatBorder:Function")
      :set_border({ "╭", "─", "╮", "│", "", "", "╰", "│" })

  local input_window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "prompt")
      :set_buf_option("swapfile", false)
      :set_win_option("winhl", "NormalFloat:Normal,FloatBorder:Comment")
      :set_border({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" })

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

  -- create floating window hud
  self.hud_window = hud_window

  -- input
  self.input_window = input_window

  api.nvim_set_current_win(self.input_window.win)
  api.nvim_win_set_buf(self.input_window.win, self.input_window.buf)

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
    ':lua require("narrow").toggle_regex() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_window.buf,
    "n",
    "{",
    ':lua require("narrow").prev_query() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
  api.nvim_buf_set_keymap(
    self.input_window.buf,
    "n",
    "}",
    ':lua require("narrow").next_query() <CR>',
    { nowait = true, noremap = true, silent = true }
  )
end

function NarrowEditor:_init_provider(config)
  local editor_context = {
    results_canvas = Canvas:new(self.results_window),
    hud_canvas = Canvas:new(self.hud_window),
    header_canvas = Canvas:new(self.entry_header_window),
    input_canvas = Canvas:new(self.input_window),

    entry_header_namespace_id = self.entry_header_namespace_id,
    entry_result_namespace_id = self.entry_result_namespace_id,

    prev_win = self.prev_win,

    config = config,
    store = self.store
  }

  self.provider = SearchProvider:new(editor_context)
end

function NarrowEditor:get_config()
  return self.config
end

function NarrowEditor:resize()
  if self.layout then
    self.layout:render()
  end
  if self.provider then
    self.provider:on_resized()
  end
end

function NarrowEditor:_get_query_from_input_window()
  local query = self.input_window:get_buffer_lines(0, 1)[1]
  local prompt_text = vim.fn.prompt_getprompt(self.input_window.buf)
  local _, e = string.find(query, prompt_text)
  return query:sub(e + 1)
end

function NarrowEditor:on_cursor_moved()
  if not self.provider then return end

  self.provider:on_cursor_moved()
end

function NarrowEditor:on_cursor_moved_insert()
  local curr_win = api.nvim_get_current_win()

  if curr_win ~= self.input_window.win or api.nvim_get_mode().mode ~= "i" then
    return
  end

  local query = self:_get_query_from_input_window()

  if self.store:get_state().query == query then
    return
  end

  self.store:dispatch({
    type = "query_updated",
    payload = query
  })
end

function NarrowEditor:on_insert_leave()
  local curr_win = api.nvim_get_current_win()

  if curr_win ~= self.input_window.win then
    return
  end

  self.store:dispatch({
    type = "input_insert_leave",
  })
end

function NarrowEditor:on_selected()
  return self.provider:on_selected()
end

function NarrowEditor:set_focus_results_window()
  api.nvim_set_current_win(self.results_window.win)
end

function NarrowEditor:set_focus_input_window()
  api.nvim_set_current_win(self.input_window.win)
end

function NarrowEditor:update_real_file()
  self.provider:update_real_file()
end

return NarrowEditor
