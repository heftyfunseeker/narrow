local Utils = require("narrow.narrow_utils")
local Devicons = require("nvim-web-devicons")
local TextBlock = require("narrow.gui.text_block")
local Style = require("narrow.gui.style")
local Canvas = require("narrow.gui.canvas")
local Window = require("narrow.window")

local api = vim.api

local SearchProvider = {}
SearchProvider.__index = SearchProvider

-- ProviderInterface
function SearchProvider:new(editor_context)
  local this = Utils.array.shallow_copy(editor_context)
  this.button_id = 1

  this.store:subscribe(function()
    this:on_store_updated()
  end)

  this = setmetatable(this, self)

  -- move this into the
  local prompt_text = "   "
  vim.fn.prompt_setprompt(this.input_canvas.window.buf, prompt_text)

  this:_render_query("")

  return this
end

function SearchProvider:handle_action(state, action)
  local action_map = {
    init_store = function(_)
      return {
        query = nil,
        completed_queries = {},
        rg_messages = {},
        enable_regex = false,
        key_pressed = nil,
        key_pressed_dirty = false,
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

      -- clear previous results if we nuke the query line
      if #query < 2 then
        new_state.rg_messages = {}
      end

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
      table.insert(new_state.completed_queries, 1, query)

      return new_state
    end,

    next_query = function()
      local new_state = Utils.array.shallow_copy(state)
      local query = table.remove(new_state.completed_queries, 1)
      new_state.query = query
      table.insert(new_state.completed_queries, query)

      return new_state
    end,

    key_pressed = function(key_pressed)
      local new_state = Utils.array.shallow_copy(state)
      new_state.key_pressed = key_pressed
      new_state.key_pressed_dirty = not new_state.key_pressed_dirty

      return new_state
    end
  }

  return action_map[action.type](action.payload)
end

function SearchProvider:_render_query(query)
  local prompt = Style:new():add_highlight("Identifier"):render("   ")
  local styled_query = Style:new():add_highlight("NarrowMatch"):render(query)

  self.input_canvas:clear()
  self.input_canvas:write(Style.join.horizontal({ prompt, styled_query }))
  self.input_canvas:render_new()
end

function SearchProvider:on_store_updated()
  local state = self.store:get_state()

  local query = self.store:get_state().query
  local results_updated = self.prev_rg_messages ~= state.rg_messages

  if results_updated then
    self.prev_rg_messages = state.rg_messages
    self:render_rg_messages()
  elseif query ~= nil and #query >= 2 and self.prev_query ~= query then
    self.prev_query = query
    self:search(query)
    self:_render_query(query)
  end

  if state.key_pressed_dirty ~= self.key_pressed_dirty then
    self.key_pressed_dirty = state.key_pressed_dirty
    self:on_key_pressed(state.key_pressed)
  end

  self:render_hud()
end

function SearchProvider:on_selected()
  local cursor = self.results_canvas.window:get_cursor_location()
  local row = cursor[1]
  local col = cursor[2]

  local rg_message = self.results_canvas:get_state(row, col)
  if not rg_message or not rg_message.data then return false end

  local submatches = rg_message.data.submatches
  if not submatches then return false end

  api.nvim_set_current_win(self.prev_win)
  api.nvim_command("edit " .. rg_message.data.path.text)
  for _, match in ipairs(submatches) do
    api.nvim_win_set_cursor(0, { rg_message.data.line_number, match.start })
    return true
  end

  return false
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
  local rg_messages = { "[" }

  if Stdout ~= nil then
    Stdout:read_stop()
    Stdout:close()
    Stdout = nil
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

      local messages = table.concat(rg_messages)
      local message_lines = table.concat(vim.split(messages, "\n", { trimempty = true }), ",")
      rg_messages = vim.json.decode(message_lines .. "]")

      self.store:dispatch({ type = "rg_messages_parsed", payload = rg_messages })
    end)
  )

  local onread = vim.schedule_wrap(function(err, input_stream)
    if err then
      print("ERROR: ", err)
    end

    if input_stream then
      table.insert(rg_messages, input_stream)
    end
  end)

  vim.loop.read_start(Stdout, onread)
end

function SearchProvider:render_rg_messages()
  self.results_canvas:clear()
  self.header_canvas:clear()

  local rg_messages = self.store:get_state().rg_messages

  for _, rg_message in ipairs(rg_messages) do
    if rg_message.type == "end" then
      self.results_canvas:write(TextBlock:from_string("", false))
      self.header_canvas:write(TextBlock:from_string("", false))
    elseif rg_message.type == "begin" then
      local path = rg_message.data.path.text
      if path == nil then
        print("did we get bytes?")
      end

      local icon, hl_name = Devicons.get_icon(
        path,
        Utils.get_file_extension(path),
        { default = true }
      )

      self.results_canvas:write(Style
        :new()
        :add_highlight("Function")
        :render(path))

      self.header_canvas:write(Style
        :new()
        :set_width(5)
        :align_horizontal(Style.position.Right)
        :add_highlight(hl_name)
        :render(icon))

    elseif rg_message.type == "match" then
      local result_text = rg_message.data.lines.text

      local result_line
      local on_select

      if #result_text > 1024 then
        result_line = Style:new():add_highlight("Error"):render("[long line]")
      else
        local submatches = rg_message.data.submatches

        -- treesitter highlighting
        local result_style = Style:new()

        for _, match in ipairs(submatches) do
          local match_text = match.match.text
          result_style:add_highlight("NarrowMatch", { col_start = match.start, col_end = match.start + #match_text })
        end

        result_line = result_style:render(result_text)
      end

      result_line:set_state(rg_message)
      self.results_canvas:write(result_line)

      local line_number = rg_message.data.line_number
      local row_header = Style:new()
          :align_horizontal(Style.position.Right)
          :set_width(5)
          :add_highlight("Comment")
          :render(tostring(line_number))

      self.header_canvas:write(row_header)
    end
  end

  self.results_canvas:render_new()
  self.header_canvas:render_new()

  api.nvim_win_set_cursor(self.results_canvas.window.win, { 1, 0 })
  api.nvim_win_set_cursor(self.header_canvas.window.win, { 1, 0 })
  -- self:render_hud()
end

function SearchProvider:render_hud()
  self.hud_canvas:clear()

  local input_width, _ = self.input_canvas:get_dimensions()
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
        :margin_left(input_width + 3)
        :border()
        :add_highlight("@text.title")
        :render(" < "),
    Style
        :new()
        :border()
        :add_highlight("Function")
        :render(" > "),
  })
  self.hud_canvas:write(line)
  self.hud_canvas:render_new()
end

-- @todo: To reload opened files that have changed because of this function,
-- should we iterate through open file that were modified and `:e!` to reload them?
-- Maybe we have this as a settings for users to configure?
function SearchProvider:update_real_file()
  -- the lines we set initially from the canvas
  local original_lines = self.results_canvas.window:get_lines()
  -- the lines that are currently visible on screen
  local buffer_lines = self.results_canvas.window:get_buffer_lines(0, -1)

  if #buffer_lines ~= #original_lines then
    print("narrow warning: Cannot update files. Number of lines were modified")
    return
  end

  local changes = {}
  for row, line in ipairs(buffer_lines) do
    local original_line = original_lines[row]
    if line ~= original_line then
      local rg_message = self.results_canvas:get_state(row, 0)
      if rg_message == nil then
        print("narrow warning: State was corrupted. Aborting update to files")
        return
      end
      table.insert(changes, { path = rg_message.data.path.text, row = rg_message.data.line_number, text = line })
    end
  end
  local prompt_text = "Are you sure you want to change " .. #changes .. " lines?"

  self:show_confirmation_window(prompt_text, function()
    -- TODO: batch these changes by header to avoid the io thrashing
    for _, change in ipairs(changes) do
      local file_lines = Utils.string_to_lines(Utils.read_file_sync(change.path))
      file_lines[change.row] = change.text
      Utils.write_file_sync(change.path, table.concat(file_lines, "\n"))
    end
  end)
end

function SearchProvider:show_confirmation_window(prompt_text, on_confirm_cb)
  self.on_confirm_cb = on_confirm_cb
  self.prompt_text = prompt_text

  local columns = api.nvim_get_option("columns")
  local lines = api.nvim_get_option("lines")

  local height = 8
  local width = 50
  local pos_col = columns * .5 - width * .5
  local pos_row = lines * .5 - height * .5 - 5

  local window = Window
      :new()
      :set_buf_option("bufhidden", "wipe")
      :set_buf_option("buftype", "nofile")
      -- :set_buf_option("modifiable", false)
      :set_buf_option("swapfile", false)
      :set_win_option("wrap", false)
      :set_win_option("winhl", "NormalFloat:Normal,FloatBorder:Function")
      :set_border({ "╭", "─", "╮", "│", "╯", "─", "╰", "│" })
      :set_pos(pos_col, pos_row)
      :set_z_index(100)
      :set_dimensions(width, height)
      :render()

  local canvas = Canvas:new(window)
  self.confirmation_canvas = canvas

  self:render_confirmation_prompt()
end

function SearchProvider:render_confirmation_prompt()
  self.confirmation_canvas:clear()

  local width, _ = self.confirmation_canvas:get_dimensions()

  local button_style = Style
      :new()
      :set_width(12)
      :margin_top(3)
      :align_horizontal(Style.position.Center)
      :border()

  local selected_button_style = button_style
      :clone()
      :add_highlight("Function")

  local prompt_text = Style
      :new()
      :set_width(width)
      :align_horizontal(Style.position.Center)
      :margin_top(1)
      :render(self.prompt_text)

  local ok_style = button_style
  local cancel_style = button_style

  if self.button_id == 1 then
    ok_style = selected_button_style
  else
    cancel_style = selected_button_style
  end

  local ok_button = ok_style:render("ok")
  local cancel_button = cancel_style:render("cancel")

  local buttons = Style.join.horizontal({ ok_button, cancel_button })
  local ui = Style.join.vertical({ prompt_text, buttons }, Style.position.Center)

  self.confirmation_canvas:write(ui)
  self.confirmation_canvas:render_new()
end

function SearchProvider:on_key_pressed(key)
  if self.confirmation_canvas == nil then return end

  if key == "\t" then
    self.button_id = (self.button_id + 1) % 2
    self:render_confirmation_prompt()
  elseif key == "\r" then
    if self.button_id == 1 then
      self.on_confirm_cb()
    end

    self.on_confirm_cb = nil
    self.prompt_text = nil

    self.confirmation_canvas:drop()
    self.confirmation_canvas = nil
  end
end

return SearchProvider
