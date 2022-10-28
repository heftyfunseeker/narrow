local api = vim.api
local Window = require("window")

HorizontalLayout = {}

function HorizontalLayout:new()
  local new_obj = {
    window = nil,
    children = {}
  }
  self.__index = self
  return setmetatable(new_obj, self)
end
