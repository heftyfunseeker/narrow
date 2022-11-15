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

  api.nvim_set_hl(0, "FloatBorder", { link = "Function" })
  api.nvim_set_hl(0, "NormalFloat", { link = "Normal" })

  vim.cmd([[
    augroup narrow
      au!
      au VimResized * :lua require("narrow").resize()
      au CursorMoved * :lua require("narrow").on_cursor_moved() 
    augroup END
  ]])
end

M.open = function()
  init_narrow()

  local NarrowEditor = require("narrow.narrow_editor")
  narrow_editor = NarrowEditor:new({})
end

M.close = function()
  vim.cmd([[ au! narrow ]])

  if narrow_editor then
    narrow_editor:drop()
    narrow_editor = nil
  end
end

M.select = function()
  if narrow_editor then
    if narrow_editor:on_selected() then
      M.close()
    end
  end
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

-- TODO these should be private
M.resize = function()
  if narrow_editor then
    narrow_editor:resize()
  end
end

M.on_cursor_moved = function()
  if narrow_editor then
    narrow_editor:on_cursor_moved()
  end
end

M.update_config = function(config)
  if narrow_editor then
    narrow_editor:apply_config(config)
  end
end

return M
