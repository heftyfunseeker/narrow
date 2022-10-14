local api = vim.api
local NarrowEditor = require("narrow_editor")
local narrow_editor = nil

local M = {}

M.open = function()
  -- @todo: allow theming with colors
  -- api.nvim_set_hl(0, "NarrowMatch", { fg = "Red", bold = true })
  --
  api.nvim_command("hi def link NarrowHeader Identifier")
  api.nvim_command("hi def link NarrowMatch IncSearch")
  api.nvim_command("hi def link HUD Error")
  api.nvim_command("hi def link Query Todo")

  narrow_editor = NarrowEditor:new({})
end

M.close = function()
  if narrow_editor then
    narrow_editor:drop()
  end
end

M.goto_result = function()
  local result = narrow_editor:get_result()
  if result == nil then
    return
  end

  M.close()
  api.nvim_command("edit " .. result.header)
  api.nvim_win_set_cursor(0, { result.row, result.column - 1 })
end

M.update_real_file = function()
  if narrow_editor then
    narrow_editor:update_real_file()
  end
end

return M
