-- simple reduxish store
--
local Store = {}
Store.__index = Store

function Store:new(reducer)
  local new_obj = {
    reducer = reducer,
    state = nil,
    listeners = {}
  }
  return setmetatable(new_obj, self)
end

function Store:dispatch(action)
  self.state = self.reducer(self.state, action)
  for _, listener in ipairs(self.listeners) do
    listener()
  end
end

function Store:get_state()
  return self.state
end

function Store:subscribe(listener)
  table.insert(self.listeners, listener)
  -- @TODO: unsubscribe
end

return Store
