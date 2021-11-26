-- ugh we'll probably need to run within a nvim instance
local function build_mocks()
  local vim = {}
  vim.api = {
    nvim_get_current_win = function() end,
    nvim_get_current_buf = function() end,
    nvim_win_get_buf = function(arg1) end,
    nvim_command = function(arg1) end,
    nvim_buf_set_option = function(arg1, arg2, arg3) end,
    nvim_buf_set_lines = function(arg1, arg2, arg3, arg4, arg5) end,
    nvim_buf_set_keymap = function(arg1, arg2, arg3, arg4, arg5) end,
  }

  vim.split = function(str, delim)
    return { str }
  end

  _G.vim = vim
end

expose("vim api mocks", function()
  build_mocks()
end)

describe("NarrowEditor", function()
  describe("constructor", function()
    it("instatiates with defaults", function()
      local NarrowEditor = require("narrow_editor")
      local ne = NarrowEditor:new()
      assert.is.truthy(ne)
    end)

    it("adds grep results", function()
      local NarrowEditor = require("search_editor")
      local ne = NarrowEditor:new()

      ne:add_grep_result "some/random.path:01:02:result1"
      assert.is.equal(#ne.narrow_results, 1)
    end)
  end)
end)
