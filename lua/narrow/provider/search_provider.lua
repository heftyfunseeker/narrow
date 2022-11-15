local NarrowResult = require("narrow.narrow_result")
local Utils = require("narrow.narrow_utils")
local Devicons = require("nvim-web-devicons")
local Canvas = require("narrow.gui.canvas")
local Text = require("narrow.gui.text")
local RipgrepParser = require("narrow.provider.ripgrep_parser")
local api = vim.api

local SearchProvider = {}
SearchProvider.__index = SearchProvider

-- ProviderInterface
function SearchProvider:new(editor_context)
  local new_obj = {}
  -- get render_contexts
  new_obj.results_canvas = editor_context.results_canvas
  new_obj.header_canvas = editor_context.header_canvas
  new_obj.hud_canvas = editor_context.hud_canvas

  new_obj.entry_header_namespace_id = editor_context.entry_header_namespace_id
  new_obj.entry_result_namespace_id = editor_context.entry_result_namespace_id

  new_obj.results = nil
  new_obj.entry_to_result = nil

  new_obj.ripgrep_parser = RipgrepParser:new()

  return setmetatable(new_obj, self)
end

function SearchProvider:on_query_updated(query)
  if query ~= nil and #query >= 2 then
    self:search(query)
  else
    self.results_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
    self.header_canvas:clear()
    self:render_hud()
  end
end

function SearchProvider:on_selected(entry, prev_win)
  local rg_match = self.entry_to_result[entry[1]]
  if rg_match == nil then return false end

  local submatches = rg_match.data.submatches
  if submatches then
    api.nvim_set_current_win(prev_win)
    api.nvim_command("edit " .. rg_match.data.path.text)
    for _, match in ipairs(submatches) do
      api.nvim_win_set_cursor(0, { rg_match.data.line_number, match.start })
      return true
    end
  end

  return false
end

function SearchProvider:on_cursor_moved()
  self:render_hud()
end

function SearchProvider:on_resized()
  self:render_hud()
end

local function build_rg_args(query_term, options)
  local args = { query_term, "--smart-case", "--json" }

  if options and not options.enable_regex then
    table.insert(args, "--fixed-strings")
  end

  return args
end

function SearchProvider:search(query_term)
  -- clear previous results out
  self.results = {}
  self.ripgrep_parser:reset()

  if stdout ~= nil then
    stdout:read_stop()
  end

  if Handle ~= nil then
    Handle:close()
    Handle = nil
  end

  stdout = vim.loop.new_pipe(false)
  Handle = vim.loop.spawn(
    "rg",
    {
      args = build_rg_args(query_term),
      stdio = { nil, stdout },
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stdout:close()
      stdout = nil
      Handle:close()
      Handle = nil

      self:render_rg_messages()
    end)
  )

  local onread = vim.schedule_wrap(function(err, input_stream)
    if err then
      print("ERROR: ", err)
    end

    if input_stream then
      self.ripgrep_parser:parse_stream(input_stream, self.results)
    end
  end)

  vim.loop.read_start(stdout, onread)
end

function SearchProvider:render_rg_messages()
  self.results_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
  self.header_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })

  self.entry_to_result = {}

  local row = 0
  local entry_result_index = 1
  local entry_header_index = 1

  for _, rg_message in ipairs(self.results) do
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
      Text:new()
          :set_text(icon)
          :set_pos(0, row)
          :apply_style(Style.Types.virtual_text, { hl_name = hl_name, pos_type = "overlay" })
          :render(self.results_canvas)

      Text:new()
          :set_text(" " .. path)
          :set_pos(1, row)
          :apply_style(Style.Types.virtual_text, { hl_name = "NarrowHeader", pos_type = "overlay" })
          :mark_entry(entry_header_index, self.entry_header_namespace_id)
          :render(self.results_canvas)

      row = row + 1
      entry_header_index = entry_header_index + 1
    elseif rg_message.type == "match" then
      local line = rg_message.data.lines.text
      Text:new()
          :set_text(line:sub(0, -2))
          :set_pos(0, row)
          :render(self.results_canvas)


      local submatches = rg_message.data.submatches
      for _, match in ipairs(submatches) do
        Text:new()
            :set_text(match.match.text)
            :set_pos(match.start, row)
            :apply_style(Style.Types.highlight, { hl_name = "NarrowMatch" })
            :mark_entry(entry_result_index, self.entry_result_namespace_id)-- mark this as a selectable entry
            :render(self.results_canvas)
      end

      local line_number = rg_message.data.line_number
      Text:new()
          :set_text(line_number)
          :set_dimensions(5, 1)
          :set_alignment(Text.AlignmentType.right)
          :set_pos(0, row)
          :apply_style(Style.Types.virtual_text, { hl_name = "Comment", pos_type = "overlay" })
          :render(self.header_canvas)

      self.entry_to_result[entry_result_index] = rg_message

      row = row + 1
      entry_result_index = entry_result_index + 1
    end
  end

  self.results_canvas:render()
  self.header_canvas:render()
  self:render_hud()
end

function SearchProvider:render_hud()
  self.hud_canvas:clear()

  local namespace_id = self.entry_result_namespace_id

  local entry = self.results_canvas:get_entry_at_cursor(namespace_id)
  if entry == nil then
    namespace_id = self.entry_header_namespace_id
    entry = self.results_canvas:get_entry_at_cursor(namespace_id)
  end

  -- results
  if entry ~= nil then
    local entry_index = entry[1] -- id is the index in namespace
    local entries = self.results_canvas:get_all_entries(namespace_id)
    local hud_width, _ = self.hud_canvas:get_dimensions()

    Text
        :new()
        :set_text(string.format("%d/%d  ", entry_index, #entries))
        :set_alignment(Text.AlignmentType.right)
        :set_pos(0, 0)
        :set_dimensions(hud_width, 1)
        :render(self.hud_canvas)
  end

  -- search config
  -- local btn_hl = "Identifier"
  -- -- if self.config.search.enable_regex then
  -- --   btn_hl = "Function"
  -- -- end
  -- Text
  --     :new()
  --     :set_text("|")
  --     :apply_style(Style.Types.highlight, { hl_name = btn_hl })
  --     :set_pos(0, 0)
  --     :render(self.hud_canvas)
  --
  -- Text
  --     :new()
  --     :set_text("regex")
  --     :set_pos(1, 0)
  --     :apply_style(Style.Types.highlight, { hl_name = "Identifier" })
  --     :render(self.hud_canvas)

  self.hud_canvas:render()
end

return SearchProvider
