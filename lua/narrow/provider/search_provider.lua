local Utils = require("narrow.narrow_utils")
local Devicons = require("nvim-web-devicons")
local TextBlock = require("narrow.gui.text_block")
local Style = require("narrow.gui.style")

local api = vim.api

local SearchProvider = {}
SearchProvider.__index = SearchProvider

-- ProviderInterface
function SearchProvider:new(editor_context)
  local this = Utils.array.shallow_copy(editor_context)

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
        enable_regex = false
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
  else
    self:render_rg_messages()
  end

  self:render_hud()
end

function SearchProvider:on_query_updated()
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
        :align_horizontal(Style.align.horizontal.Right)
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
          :align_horizontal(Style.align.horizontal.Right)
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

  -- self.hud_canvas:write(
  --   Style
  --       :new()
  --       :border()
  --       :margin_left(100)
  --       :margin_right(1)
  --       :add_highlight("Function")
  --       :render("hello world.\nthis is the first block"))


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

  -- -- todo pop-up confirmation modal instead
  print("narrow: Applying " .. #changes .. " changes to real files")

  -- TODO: batch these changes by header to avoid the io thrashing
  for _, change in ipairs(changes) do
    local file_lines = Utils.string_to_lines(Utils.read_file_sync(change.path))
    file_lines[change.row] = change.text
    Utils.write_file_sync(change.path, table.concat(file_lines, "\n"))
  end

  print("narrow: Finished applying " .. #changes .. " changes")
end

return SearchProvider
