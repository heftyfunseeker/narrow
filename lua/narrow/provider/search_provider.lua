local Utils = require("narrow.narrow_utils")
local Devicons = require("nvim-web-devicons")
local RipgrepParser = require("narrow.provider.ripgrep_parser")

local api = vim.api

local SearchProvider = {}
SearchProvider.__index = SearchProvider

-- ProviderInterface
function SearchProvider:new(editor_context)
  local this = Utils.array.shallow_copy(editor_context)

  this.entry_to_result = nil
  this.ripgrep_parser = RipgrepParser:new()

  this.store:subscribe(function()
    this:on_store_updated()
  end)

  return setmetatable(this, self)
end

function SearchProvider:handle_action(state, action)
  local action_map = {
    init_store = function(_)
      return {
        rg_messages = nil,
        enable_regex = false -- @todo: come from config
      }
    end,

    toggle_regex = function(_)
      local new_state = Utils.array.shallow_copy(state)
      new_state.enable_regex = not new_state.enable_regex
      return new_state
    end,

    query_updated = function(query)
      local new_state = Utils.array.shallow_copy(state)
      new_state.query = query
      return new_state
    end,

    rg_messages_parsed = function(rg_messages)
      local new_state = Utils.array.shallow_copy(state)
      new_state.rg_messages = rg_messages
      return new_state
    end,
  }

  return action_map[action.type](action.payload)
end

function SearchProvider:on_store_updated()
  local state = self.store:get_state()

  local results_updated = self.prev_rg_messages ~= state.rg_messages
  if results_updated then
    self.prev_rg_messages = state.rg_messages
    self:render_rg_messages()
  else
    self:on_query_updated()
  end
end

function SearchProvider:on_query_updated()
  local query = self.store:get_state().query

  if query ~= nil and #query >= 2 then
    self:search(query)
  else
    self.results_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
    self.header_canvas:clear()
    self:render_hud()
  end
end

function SearchProvider:on_selected()
  self.results_canvas:select_at_cursor()
  return true
end

function SearchProvider:on_cursor_moved()
  self:render_hud()
end

function SearchProvider:on_resized()
  self:render_hud()
end

function SearchProvider:build_rg_args(query_term)
  local args = { query_term, "--smart-case", "--json" }

  if self.config and not self.store:get_state().enable_regex then
    table.insert(args, "--fixed-strings")
  end

  if self.config and self.config.search.mode == 1 then
    table.insert(args, self.config.search.current_file)
  end

  return args
end

function SearchProvider:search(query_term)
  -- clear previous results out
  local rg_messages = {}
  self.ripgrep_parser:reset()

  if Stdout ~= nil then
    Stdout:read_stop()
  end

  if Handle ~= nil then
    Handle:close()
    Handle = nil
  end

  Stdout = vim.loop.new_pipe(false)
  Handle = vim.loop.spawn(
    "rg",
    {
      args = self:build_rg_args(query_term),
      stdio = { nil, Stdout },
    },
    vim.schedule_wrap(function()
      Stdout:read_stop()
      Stdout:close()
      Stdout = nil
      Handle:close()
      Handle = nil

      self.store:dispatch({ type = "rg_messages_parsed", payload = rg_messages })
    end)
  )

  local onread = vim.schedule_wrap(function(err, input_stream)
    if err then
      print("ERROR: ", err)
    end

    if input_stream then
      self.ripgrep_parser:parse_stream(input_stream, rg_messages)
    end
  end)

  vim.loop.read_start(Stdout, onread)
end

function SearchProvider:render_rg_messages()
  self.results_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
  self.header_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })

  local rg_messages = self.store:get_state().rg_messages
  self.entry_to_result = {}

  local row = 0
  local entry_result_index = 1
  local entry_header_index = 1

  for _, rg_message in ipairs(rg_messages) do
    if rg_message.type == "begin" then
      local path = rg_message.data.path.text
      if path == nil then
        print("did we get bytes?")
      end

      local icon, hl_name = Devicons.get_icon(
        path,
        Utils.get_file_extension(path),
        { default = true }
      )

      local header = Style.join.horizontal({
        Style
            :new()
            :margin_right(1)
            :add_highlight(hl_name)
            :render(icon),
        Style
            :new()
            :add_highlight("Function")
            :render(path)
      })
      self.results_canvas:write(header)

      row = row + 1
      entry_header_index = entry_header_index + 1
    elseif rg_message.type == "match" then
      local result_text = rg_message.data.lines.text:sub(0, -2)

      local submatches = rg_message.data.submatches

      local next_match_offset = 0
      local style_frags = {}

      -- Split the result string into fragments to build a styled line.
      for _, match in ipairs(submatches) do
        local match_text = match.match.text
        local front_fragment = result_text:sub(next_match_offset, match.start)
        table.insert(style_frags, Style:new():render(front_fragment))
        table.insert(style_frags, Style:new():add_highlight("NarrowMatch"):render(match_text))
        next_match_offset = match.start + #match_text + 1
      end
      table.insert(style_frags, Style:new():render(result_text:sub(next_match_offset)))

      local result_line = Style.join.horizontal(style_frags)

      result_line:mark_selectable(function()
        if submatches then
          api.nvim_set_current_win(self.prev_win)
          api.nvim_command("edit " .. rg_message.data.path.text)
          for _, match in ipairs(submatches) do
            api.nvim_win_set_cursor(0, { rg_message.data.line_number, match.start })
            return true
          end
        end
      end)

      self.results_canvas:write(result_line)

      -- local line_number = rg_message.data.line_number
      -- local row_header = Style:new()
      --     :width(5)
      --     :height(1)
      --     :align(Style.Align.Right)
      --     :add_highlight("Comment")
      --     :render(line_number)
      --
      -- self.header_canvas:write(row_header)
      self.entry_to_result[entry_result_index] = rg_message

      row = row + 1
      entry_result_index = entry_result_index + 1
    end
  end

  self.results_canvas:render_new()
  self.header_canvas:render()
  -- self:render_hud()
end

function SearchProvider:render_hud()
  self.hud_canvas:clear()
  self.input_canvas:clear(nil, true)

  -- local namespace_id = self.entry_result_namespace_id
  --
  -- local entry = self.results_canvas:get_entry_at_cursor(namespace_id)
  -- if entry == nil then
  --   namespace_id = self.entry_header_namespace_id
  --   entry = self.results_canvas:get_entry_at_cursor(namespace_id)
  -- end
  --
  -- -- results
  -- if entry ~= nil then
  --   local entry_index = entry[1] -- id is the index in namespace
  --   local entries = self.results_canvas:get_all_entries(namespace_id)
  --   local input_width, _ = self.input_canvas:get_dimensions()
  --
  --   Text
  --       :new()
  --       :set_text(string.format("%d/%d  ", entry_index, #entries))
  --       --:apply_style({ type = Style.Types.virtual_text, hl_name = "Comment", pos_type = "overlay" })
  --       :set_alignment(Text.AlignmentType.right)
  --       :set_dimensions(8, 1)
  --       :set_pos(input_width - 8, 0)
  --       :render(self.input_canvas)
  -- end
  local line = Style.join.horizontal({
    Style
        :new()
        :margin_left(100)
        :margin_right(1)
        :add_highlight("Function")
        :render("hello world.\nthis is the first block"),
    Style
        :new()
        :border()
        :add_highlight("comment")
        :render("This is the second block.")
  })
  self.hud_canvas:write(line)

  -- self.hud_canvas:write(
  --   Style
  --       :new()
  --       :border()
  --       :margin_left(100)
  --       :margin_right(1)
  --       :add_highlight("Function")
  --       :render("hello world.\nthis is the first block"))


  self.hud_canvas:render_new()
  self.input_canvas:render(true)
end

return SearchProvider
