local api = vim.api
local narrow_editor = nil

local M = {}

function init_narrow()
  -- @todo: allow theming with colors
  -- api.nvim_set_hl(0, "NarrowMatch", { fg = "Red", bold = true })
  --
  api.nvim_command("hi def link NarrowHeader Function")
  api.nvim_command("hi def link NarrowMatch Keyword")
  api.nvim_command("hi def link HUD Error")
  api.nvim_command("hi def link Query Todo")

  vim.cmd([[
    augroup narrow
      au!
      au VimResized * :lua require("narrow")._resize()
      au CursorMoved * :lua require("narrow")._on_cursor_moved() 
      au CursorMovedI * :lua require("narrow")._on_cursor_moved_insert() 
      au InsertLeave * :lua require("narrow")._on_insert_leave() 
    augroup END
  ]])
end

M.setup = function(_config)
  -- no impl
end

M.search_project = function()
  init_narrow()

  local NarrowEditor = require("narrow.narrow_editor")
  narrow_editor = NarrowEditor:new({
    search = {
      mode = NarrowEditor.SearchModes.Project
    }
  })
end

M.search_current_file = function()
  local current_file = vim.api.nvim_buf_get_name(0)

  init_narrow()

  local NarrowEditor = require("narrow.narrow_editor")
  narrow_editor = NarrowEditor:new({
    search = {
      mode = NarrowEditor.SearchModes.CurrentFile,
      current_file = current_file
    }
  })
end

M.close = function()
  vim.cmd([[ au! narrow ]])
  if not narrow_editor then return end

  narrow_editor:drop()
  narrow_editor = nil
end

M.select = function()
  if not narrow_editor then return end

  if narrow_editor:on_selected() then
    M.close()
  end
end

M.update_real_file = function()
  if not narrow_editor then return end

  narrow_editor:update_real_file()
end

M.set_focus_results_window = function()
  if not narrow_editor then return end

  narrow_editor:set_focus_results_window()
end

M.set_focus_input_window = function()
  if not narrow_editor then return end

  narrow_editor:set_focus_input_window()
end

M.toggle_regex = function()
  if not narrow_editor then return end

  narrow_editor:get_store():dispatch({ type = "toggle_regex" })
end

M.prev_query = function()
  if not narrow_editor then return end

  narrow_editor:get_store():dispatch({ type = "prev_query" })
end

M.next_query = function()
  if not narrow_editor then return end

  narrow_editor:get_store():dispatch({ type = "next_query" })
end

-- TODO these should be private
M._resize = function()
  if not narrow_editor then return end

  narrow_editor:resize()
end

M._on_cursor_moved = function()
  local a = vim.schedule_wrap(function()
    if not narrow_editor then return end
    narrow_editor:on_cursor_moved()
  end)
  a()
end

M._on_cursor_moved_insert = function()
  local a = vim.schedule_wrap(function()
    if not narrow_editor then return end
    narrow_editor:on_cursor_moved_insert()
  end)
  a()
end

M._on_insert_leave = function()
  local a = vim.schedule_wrap(function()
    if not narrow_editor then return end
    narrow_editor:on_insert_leave()
  end)
  a()
end

return M
