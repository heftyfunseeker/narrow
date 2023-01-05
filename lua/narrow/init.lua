local api = vim.api
local narrow_editor = nil

local M = {}

M.setup = function(_config)
  -- todo
end

-- @TODO: should we move this into the narrow_editor?
local function init_narrow()
  -- @todo: allow theming with colors
  -- api.nvim_set_hl(0, "NarrowMatch", { fg = "Red", bold = true })
  --
  api.nvim_command("hi def link NarrowHeader Function")
  api.nvim_command("hi def link NarrowMatch Keyword")
  api.nvim_command("hi def link NarrowHudHUD Error")
  api.nvim_command("hi def link NarrowQuery Todo")

  vim.cmd([[
    augroup narrow
      au!
      au VimResized * :lua require("narrow")._resize()
      au CursorMoved * :lua require("narrow").dispatch_event("event_cursor_moved")
      au CursorMovedI * :lua require("narrow").dispatch_event("event_cursor_moved_insert")
      au InsertLeave * :lua require("narrow")._on_insert_leave()
    augroup END
  ]])
end

M.search_project = function()
  if narrow_editor then M.close() end

  init_narrow()

  local NarrowEditor = require("narrow.narrow_editor")
  narrow_editor = NarrowEditor:new({
    search = {
      mode = NarrowEditor.SearchModes.Project
    }
  })
end

M.search_current_file = function()
  if narrow_editor then M.close() end

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

M.dispatch_event = function(event)
  if not narrow_editor then return end

  narrow_editor:dispatch_event(event)
end

M._resize = function()
  if not narrow_editor then return end

  narrow_editor:resize()
end

M._on_insert_leave = function()
  local a = vim.schedule_wrap(function()
    if not narrow_editor then return end
    narrow_editor:on_insert_leave()
  end)
  a()
end

return M
