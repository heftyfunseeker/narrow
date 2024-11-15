local Utils = require("narrow.narrow_utils")
local Devicons = require("nvim-web-devicons")
local TextBlock = require("narrow.gui.text_block")
local Style = require("narrow.gui.style")
local Canvas = require("narrow.gui.canvas")
local Window = require("narrow.window")
local Toggle = require("narrow.gui.components.toggle")
local Reducer = require("narrow.provider.search_provider_reducer")
-- @todo: move these to separate file
local HudButtonIds = Reducer.hud_button_ids
local ConfirmationButtonIds = Reducer.confirmation_button_ids

local api = vim.api

local SearchProvider = {}
SearchProvider.__index = SearchProvider

-- ProviderInterface
function SearchProvider:new(editor_context)
  local this = Utils.array.shallow_copy(editor_context)

  this.confirmation_button_id = ConfirmationButtonIds.cancel

  this.on_clicked = {}
  this.on_clicked[HudButtonIds.toggle_regex] = function()
    this.store:dispatch({ type = "toggle_regex" })
    this:search(this.store:get_state().query)
  end
  this.on_clicked[HudButtonIds.toggle_word] = function()
    this.store:dispatch({ type = "toggle_word" })
    this:search(this.store:get_state().query)
  end
  this.on_clicked[HudButtonIds.toggle_case] = function()
    this.store:dispatch({ type = "toggle_case" })
    this:search(this.store:get_state().query)
  end
  this.on_clicked[HudButtonIds.prev_search] = function()
    this.store:dispatch({ type = "prev_query" })
    this:search(this.store:get_state().query)
  end
  this.on_clicked[HudButtonIds.next_search] = function()
    this.store:dispatch({ type = "next_query" })
    this:search(this.store:get_state().query)
  end

  this.store:subscribe(function()
    this:on_store_updated()
  end)

  this = setmetatable(this, self)

  -- @todo: make this configurable
  local prompt_text = "   "
  vim.fn.prompt_setprompt(this.input_canvas.window.buf, prompt_text)

  this:_render_query()

  return this
end

function SearchProvider:reduce(state, action)
  return Reducer.reduce(state, action)
end

function SearchProvider:on_event(event)
  local state = self.store:get_state()

  if event == "event_ui_next" then
    if self.confirmation_canvas then
      self.store:dispatch({ type = "focus_next_confirmation_button" })
    elseif self.input_canvas:has_focus() then
      self.store:dispatch({ type = "focus_next_hud_button" })
    end
  elseif event == "event_ui_prev" then
    if self.input_canvas:has_focus() then
      self.store:dispatch({ type = "focus_prev_hud_button" })
    end
  elseif event == "event_ui_back" then
    if self.confirmation_canvas then
      self:close_confirmation_window()
    elseif self.results_canvas:has_focus() then
      self.input_canvas:set_focus()
    elseif state.hud_button_id ~= HudButtonIds.inactive then
      self.store:dispatch({ type = "set_hud_button_focus", payload = HudButtonIds.inactive })
    else
      require("narrow").close()
    end
  elseif event == "event_ui_confirm" then
    if self.confirmation_canvas then
      if state.confirmation_button_id == ConfirmationButtonIds.confirm then
        self.on_confirm_cb()
        -- refresh our results
        self.store:dispatch({ type = "query_updated", payload = state.query })
      end
      self:close_confirmation_window()
    elseif self.results_canvas:has_focus() then
      self:open_result()
    elseif self.input_canvas:has_focus() then
      if state.hud_button_id then
        self.on_clicked[state.hud_button_id]()
      end
    end
  elseif event == "event_ui_focus_results" then
    self.results_canvas:set_focus()
  elseif event == "event_ui_focus_input" then
    self.input_canvas:set_focus()
  elseif event == "event_update_real_file" then
    self:update_real_file()
  elseif event == "event_cursor_moved_insert" then
    self:_try_new_search()
  elseif event == "event_cursor_moved" then
    self:_try_hover_item()
  end
end

LAST = nil
function SearchProvider:_try_hover_item()
  -- local cursor = self.results_canvas.window:get_cursor_location()
  -- local row = cursor[1]
  -- local col = cursor[2]
  --
  -- local item_state = self.results_canvas:get_state(row, col)
  -- if not item_state then return end
  --
  -- self.store:dispatch({ type = "set_hovered_item", payload = item_state })
  --
  -- local a = vim.schedule_wrap(function()
  --   if LAST ~= item_state then
  --     LAST = item_state
  --     api.nvim_set_current_win(self.prev_win)
  --     api.nvim_command("edit " .. item_state.path)
  --     api.nvim_win_set_cursor(0, { item_state.line_number, item_state.match_start })
  --     self.results_canvas:set_focus()
  --   end
  -- end)
  -- a()
end

function SearchProvider:_get_query_from_input_window()
  local query = self.input_canvas.window:get_buffer_lines(0, 1)[1]
  local prompt_text = vim.fn.prompt_getprompt(self.input_canvas.window.buf)
  local _, e = string.find(query, prompt_text)
  return query:sub(e + 1)
end

function SearchProvider:_try_new_search()
  if not self.input_canvas:has_focus() then return end

  local query = self:_get_query_from_input_window()

  if self.store:get_state().query == query then
    return
  end

  self.store:dispatch({ type = "query_updated", payload = query })

  if #query >= 2 then
    self:search(query)
  end
end

function SearchProvider:on_store_updated()
  local state = self.store:get_state()

  local results_updated = self.prev_rg_messages ~= state.rg_messages

  if results_updated then
    self.prev_rg_messages = state.rg_messages
    self:_render_rg_messages()
  end

  self:_render_hud()
  self:_render_query()

  if self.confirmation_canvas then
    self:render_confirmation_prompt()
  end
end

function SearchProvider:_render_query()
  local state = self.store:get_state()
  local query = state.query or ""

  local prompt = Style:new():add_highlight("Identifier"):render("   ")
  local styled_query = Style:new():add_highlight("NarrowMatch"):render(query)

  self.input_canvas:clear()
  self.input_canvas:write(Style.join.horizontal({ prompt, styled_query }))

  if state.rg_search_summary then
    local match_number = 0
    if state.hovered_item then
      match_number = state.hovered_item.match_number
    end

    local matches = state.rg_search_summary.stats.matches
    local matches_text = Style:new():set_width(12):align_horizontal(Style.position.Right):render(match_number ..
      "/" .. matches)[1].text
    local width, _ = self.input_canvas:get_dimensions()

    self.input_canvas:write_virtual(matches_text, "Comment", { row = 0, col = width - 13 })
  end

  self.input_canvas:render_new()
end

function SearchProvider:on_resized()
  self:_render_hud()
end

function SearchProvider:build_rg_args(query_term)
  local args = { query_term, "--smart-case", "--json" }

  local state = self.store:get_state()

  if not state.rg_regex_enabled then
    table.insert(args, "--fixed-strings")
  end

  if state.rg_word_enabled then
    table.insert(args, "--word-regexp")
  end

  if state.rg_case_enabled then
    table.insert(args, "--case-sensitive")
  end

  --@todo: move this to state
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

function SearchProvider:_render_rg_messages()
  self.results_canvas:clear()
  self.header_canvas:clear()

  local rg_messages = self.store:get_state().rg_messages

  local match_number = 1
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

      if #result_text > 1024 then
        result_line = Style:new():add_highlight("Error"):render("[long line]")
      else
        local submatches = rg_message.data.submatches

        local result_style = Style:new()

        for _, match in ipairs(submatches) do
          local match_text = match.match.text
          result_style:add_highlight("NarrowMatch", { col_start = match.start, col_end = match.start + #match_text })
        end

        result_line = result_style:render(result_text)

        local col_start = 0
        for match_index, match in ipairs(submatches) do
          local match_text = match.match.text
          local col_end
          if match_index == #submatches then
            col_end = #result_text
          else
            col_end = match.start + #match_text
          end

          result_line:add_state({ path = rg_message.data.path.text, line_number = rg_message.data.line_number,
            match_start = match.start, match_number = match_number },
            { col_start = col_start, col_end = col_end })

          col_start = match.start + #match_text
          match_number = match_number + 1
        end
      end

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
end

function SearchProvider:_render_hud()
  self.hud_canvas:clear()

  local state = self.store:get_state()

  local input_width, _ = self.input_canvas:get_dimensions()

  local prev_button_style = Style
      :new()
      :add_highlight("Comment")
      :border_highlight("Comment")
      :margin_left(input_width + 3)
      :border()
  local next_button_style = prev_button_style:clone():margin_left(nil)

  -- @todo: move current button into state
  local regex_toggle = Toggle:new("regex", state.rg_regex_enabled, state.hud_button_id == HudButtonIds.toggle_regex)
  local case_toggle = Toggle:new("case", state.rg_case_enabled, state.hud_button_id == HudButtonIds.toggle_case)
  local word_toggle = Toggle:new("word", state.rg_word_enabled, state.hud_button_id == HudButtonIds.toggle_word)

  if state.hud_button_id == HudButtonIds.prev_search then
    prev_button_style:border_highlight("Function"):add_highlight("Function")
  elseif state.hud_button_id == HudButtonIds.next_search then
    next_button_style:border_highlight("Function"):add_highlight("Function")
  end

  local container_style = Style:new():border():border_highlight("Comment")

  local search_settings_buttons = container_style:render(Style.join.horizontal({
    Style:new():margin_right(2):margin_left(1):render(regex_toggle),
    Style:new():margin_right(2):render(case_toggle),
    Style:new():margin_right(2):render(word_toggle),
  }))

  local hud_buttons = Style.join.horizontal({
    prev_button_style:render(" ⬅ "),
    next_button_style:render(" ➡ "),
    search_settings_buttons
  })

  self.hud_canvas:write(hud_buttons)
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
      local item = self.results_canvas:get_state(row, 0)
      if item then
        table.insert(changes, { path = item.path, row = item.line_number, text = line })
      end
    end
  end

  local prompt_text = "Are you sure you want to change " .. #changes .. " lines?"
  self:open_confirmation_window(prompt_text, function()
    -- @todo: batch these changes by header to avoid the io thrashing
    for _, change in ipairs(changes) do
      local file_lines = Utils.string_to_lines(Utils.read_file_sync(change.path))
      file_lines[change.row] = change.text
      Utils.write_file_sync(change.path, table.concat(file_lines, "\n"))
    end
  end)
end

function SearchProvider:open_confirmation_window(prompt_text, on_confirm_cb)
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

function SearchProvider:close_confirmation_window()
  self.on_confirm_cb = nil
  self.prompt_text = nil

  self.confirmation_canvas:drop()
  self.confirmation_canvas = nil
  -- set button to cancel
  self.store:dispatch({ type = "focus_next_confirmation_button" })
end

function SearchProvider:render_confirmation_prompt()
  self.confirmation_canvas:clear()

  local width, _ = self.confirmation_canvas:get_dimensions()
  local state = self.store:get_state()

  local button_style = Style
      :new()
      :set_width(12)
      :margin_top(3)
      :align_horizontal(Style.position.Center)
      :border()

  local selected_button_style = button_style
      :clone()
      :padding_right(1)
      :padding_left(1)
      :add_highlight("Function")
      :border_highlight("Function")

  local prompt_text = Style
      :new()
      :set_width(width)
      :align_horizontal(Style.position.Center)
      :margin_top(1)
      :render(self.prompt_text)

  local ok_style = button_style
  local cancel_style = button_style

  if state.confirmation_button_id == ConfirmationButtonIds.confirm then
    ok_style = selected_button_style
    cancel_style:margin_right(1)
  else
    cancel_style = selected_button_style
    ok_style:margin_left(1)
  end

  local ok_button = ok_style:render("ok")
  local cancel_button = cancel_style:render("cancel")

  local buttons = Style.join.horizontal({ ok_button, Style:new():render("  "), cancel_button })
  local ui = Style.join.vertical({ prompt_text, buttons }, Style.position.Center)

  self.confirmation_canvas:write(ui)
  self.confirmation_canvas:render_new(true)
end

function SearchProvider:open_result()
  local cursor = self.results_canvas.window:get_cursor_location()
  local row = cursor[1]
  local col = cursor[2]

  local match_state = self.results_canvas:get_state(row, col)
  if not match_state then return end

  api.nvim_set_current_win(self.prev_win)
  api.nvim_command("edit " .. match_state.path)
  api.nvim_win_set_cursor(0, { match_state.line_number, match_state.match_start })
  require("narrow").close()
end

return SearchProvider
