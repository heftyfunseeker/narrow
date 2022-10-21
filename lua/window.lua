local api = vim.api

local width = api.nvim_get_option("columns")
local height = api.nvim_get_option("lines")

Window = {}

function Window:new_results_window()
  local results_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(results_buf, "bufhidden", "wipe")
  local opts = {
    style = "minimal",
    relative = "editor",
    border = { "", "", "", "│", "╯", "─", "╰", "│", },
    width = math.floor(width),
    height = math.floor(height * .5 - 3),
    row = math.floor(height * .5) + 1,
    col = 0,
    noautocmd = true,
  }
  local results_win = api.nvim_open_win(results_buf, true, opts)

  api.nvim_buf_set_option(results_buf, "buftype", "nofile")
  api.nvim_buf_set_option(results_buf, "swapfile", false)
  api.nvim_buf_set_option(results_buf, "bufhidden", "wipe")

  return results_buf, results_win
end

function Window:new_hud_window()
  local hud_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(hud_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(hud_buf, "swapfile", false)
  local opts = {
    style = "minimal",
    relative = "editor",
    border = { "", "─", "╮", "│", "", "", "", "", },
    width = math.floor(width) - 50,
    height = 2,
    row = math.floor(height * .5) - 2,
    col = 50,
    zindex = 100,
    noautocmd = true,
  }
  local hud_win = api.nvim_open_win(hud_buf, true, opts)
  return hud_buf, hud_win
end

function Window:new_input_window()
  local input_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(input_buf, "swapfile", false)
  api.nvim_buf_set_option(input_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(input_buf, "buftype", "prompt")
  local opts = {
    style = "minimal",
    relative = "editor",
    border = { "╭", "─", "", "", " ", "", "", "│" },
    width = 50,
    height = 2,
    row = math.floor(height * .5) - 2,
    col = 0,
    zindex = 100,
    noautocmd = true,
  }
  local input_win = api.nvim_open_win(input_buf, true, opts)
  return input_buf, input_win
end

function Window:new_preview_window()
  local preview_buf = api.nvim_create_buf(false, true)

  api.nvim_buf_set_option(preview_buf, "bufhidden", "wipe")
  api.nvim_buf_set_option(preview_buf, "buftype", "nofile")
  api.nvim_buf_set_option(preview_buf, "swapfile", false)
  local opts = {
    style = "minimal",
    relative = "editor",
    border = "solid",
    width = math.floor(width * .4) - 2,
    height = math.floor(height * .5 - 3),
    row = math.floor(height * .5),
    col = math.floor(width * .6) + 1,
    noautocmd = true,
  }
  local preview_win = api.nvim_open_win(preview_buf, true, opts)
  return preview_buf, preview_win
end

1. let's create a window class that saves the hardcoded width height position properties

function Window:resize(win)
  local win_config = api.nvim_win_get_config(win)
end

return Window
