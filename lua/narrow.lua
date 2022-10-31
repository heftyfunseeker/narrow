local api = vim.api
local NarrowEditor = require("narrow_editor")
local narrow_editor = nil

local M = {}

M.open = function()
  -- @todo: allow theming with colors
  -- api.nvim_set_hl(0, "NarrowMatch", { fg = "Red", bold = true })
  --
  api.nvim_command("hi def link NarrowHeader Function")
  api.nvim_command("hi def link NarrowMatch Keyword")
  api.nvim_command("hi def link HUD Error")
  api.nvim_command("hi def link Query Todo")

  api.nvim_set_hl(0, "FloatBorder", { link = "Function" })
  api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })

  narrow_editor = NarrowEditor:new({})

  vim.cmd([[ au VimResized * :lua require("narrow").resize() ]])
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

M.set_focus_results_window = function()
  if narrow_editor then
    narrow_editor:set_focus_results_window()
  end
end

M.set_focus_input_window = function()
  if narrow_editor then
    narrow_editor:set_focus_input_window()
  end
end

M.resize = function()
  if narrow_editor then
    narrow_editor:resize()
  end
end

return M
