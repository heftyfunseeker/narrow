local Utils = require("narrow.narrow_utils")

local hud_button_ids = {
  inactive = -1,
  prev_search = 0,
  next_search = 1,
  toggle_regex = 2,
  toggle_case = 3,
  toggle_word = 4,
  COUNT = 5
}

local confirmation_button_ids = {
  cancel = 0,
  confirm = 1,
  COUNT = 2
}

local M = {
  hud_button_ids = hud_button_ids,
  confirmation_button_ids = confirmation_button_ids,
}

M.reduce = function(state, action)
  local action_map = {
    init_store = function(_)
      return {
        query = nil,
        query_dirty = nil,
        completed_queries = {},

        rg_messages = {},
        rg_regex_enabled = false,
        rg_word_enabled = false,
        rg_case_enabled = false,

        action_id = nil,
        action_dirty = false,

        hud_button_id = hud_button_ids.inactive,
        confirmation_button_id = confirmation_button_ids.cancel,
      }
    end,

    toggle_regex = function(_)
      local new_state = Utils.array.shallow_copy(state)
      new_state.rg_regex_enabled = not new_state.rg_regex_enabled
      new_state.query_dirty = not new_state.query_dirty
      return new_state
    end,

    toggle_word = function(_)
      local new_state = Utils.array.shallow_copy(state)
      new_state.rg_word_enabled = not new_state.rg_word_enabled
      new_state.query_dirty = not new_state.query_dirty
      return new_state
    end,

    toggle_case = function(_)
      local new_state = Utils.array.shallow_copy(state)
      new_state.rg_case_enabled = not new_state.rg_case_enabled
      new_state.query_dirty = not new_state.query_dirty
      return new_state
    end,

    query_updated = function(query)
      local new_state = Utils.array.shallow_copy(state)
      new_state.query = query
      new_state.query_dirty = not new_state.query_dirty

      -- clear previous results if we nuke the query line
      if #query < 2 then
        new_state.rg_messages = {}
      end

      return new_state
    end,

    cursor_moved_insert = function()
      local new_state = Utils.array.shallow_copy(state)
      new_state.cursor_moved_insert = not new_state.cursor_moved_insert

      return new_state
    end,

    input_insert_leave = function()
      local new_state = Utils.array.shallow_copy(state)
      if state.completed_queries[-1] ~= state.query and #state.query >= 2 then
        table.insert(new_state.completed_queries, new_state.query)
      end
      return new_state
    end,

    rg_messages_parsed = function(rg_messages)
      local new_state = Utils.array.shallow_copy(state)
      new_state.rg_messages = rg_messages
      return new_state
    end,

    prev_query = function()
      local new_state = Utils.array.shallow_copy(state)
      local query = table.remove(new_state.completed_queries)
      new_state.query = query
      new_state.query_dirty = not new_state.query_dirty
      table.insert(new_state.completed_queries, 1, query)

      return new_state
    end,

    next_query = function()
      local new_state = Utils.array.shallow_copy(state)
      local query = table.remove(new_state.completed_queries, 1)
      new_state.query = query
      new_state.query_dirty = not new_state.query_dirty
      table.insert(new_state.completed_queries, query)

      return new_state
    end,

    focus_next_confirmation_button = function()
      local new_state = Utils.array.shallow_copy(state)
      new_state.confirmation_button_id = (new_state.confirmation_button_id + 1) % confirmation_button_ids.COUNT
      return new_state
    end,

    focus_next_hud_button = function()
      local new_state = Utils.array.shallow_copy(state)
      new_state.hud_button_id = (new_state.hud_button_id + 1) % hud_button_ids.COUNT
      return new_state
    end,

    focus_prev_hud_button = function()
      local new_state = Utils.array.shallow_copy(state)
      new_state.hud_button_id = (new_state.hud_button_id - 1) % hud_button_ids.COUNT
      return new_state
    end,

    set_hud_button_focus = function(hud_button_id)
      local new_state = Utils.array.shallow_copy(state)
      new_state.hud_button_id = hud_button_id
      return new_state
    end,
  }

  return action_map[action.type](action.payload)
end

return M
