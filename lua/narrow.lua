local api = vim.api
local NarrowEditor = require("narrow_editor")
local narrow_editor = nil

local function narrow()
  narrow_editor = NarrowEditor:new({})
end

local function narrow_exit()
  narrow_editor:drop()
end

local function narrow_open_result()
  local result = narrow_editor:get_result()
  if result == nil then
    return
  end

  narrow_exit()
  api.nvim_command("edit " .. result.header)
  api.nvim_win_set_cursor(0, { result.row, result.column - 1 })
end

local function narrow_update_real_file()
  narrow_editor:update_real_file()
end

return {
  narrow = narrow,
  narrow_exit = narrow_exit,
  narrow_open_result = narrow_open_result,
  narrow_update_real_file = narrow_update_real_file,
}
