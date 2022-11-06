local NarrowResult = require("narrow_result")
local Utils = require("narrow_utils")
local Devicons = require("nvim-web-devicons")
local Canvas = require("gui.canvas")
local Text = require("gui.text")
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

  return setmetatable(new_obj, self)
end

function SearchProvider:on_query_updated(query)
  if query ~= nil and #query >= 2 then
    self:search(query)
  else
    self.results_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
    self.header_canvas:clear()
    --self:_render_hud()
  end
end

function SearchProvider:on_selected(entry, prev_win)
  local result = self.results[entry[1]]
  if result == nil then return false end

  api.nvim_set_current_win(prev_win)
  api.nvim_command("edit " .. result.header)
  api.nvim_win_set_cursor(0, { result.row, result.column - 1 })

  return true
end

SearchProvider.build_rg_args = function(query_term, options)
  local args = { query_term, "--smart-case", "--vimgrep", "-M", "1024" }

  if options and not options.enable_regex then
    table.insert(args, "--fixed-strings")
  end

  return args
end

function SearchProvider:search(query_term)
  -- clear previous results out
  self.results = {}

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  if Handle ~= nil then
    Handle:close()
    Handle = nil
  end

  Handle = vim.loop.spawn(
    "rg",
    {
      args = SearchProvider.build_rg_args(query_term),
      stdio = { nil, stdout, stderr },
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      Handle:close()
      Handle = nil

      self:render_results()
    end)
  )

  local onread = function(err, input_stream)
    if err then
      print("ERROR: ", err)
    end

    if input_stream then
      self:add_grep_result(input_stream)
    end
  end

  vim.loop.read_start(stdout, onread)
  vim.loop.read_start(stderr, onread)
end

function SearchProvider:add_grep_result(grep_results)
  local vals = vim.split(grep_results, "\n")
  for _, line in pairs(vals) do
    if line ~= "" then
      -- @todo: this will be json, how do we want this?
      local result = NarrowResult:new(line)
      if result then
        table.insert(self.results, result)
      end
    end
  end
end

function SearchProvider:render_results()
  self.results_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })
  self.header_canvas:clear({ self.entry_header_namespace_id, self.entry_result_namespace_id })

  local headers_processed = {}

  local row = 0
  local entry_result_index = 1
  local entry_header_index = 1
  for _, result in ipairs(self.results) do
    if result.header and headers_processed[result.header] == nil then
      headers_processed[result.header] = true

      local icon, hl_name = Devicons.get_icon(
        result.header,
        Utils.get_file_extension(result.header),
        { default = true }
      )
      Text:new()
          :set_text(icon)
          :set_pos(0, row)
          :apply_style(Style.Types.virtual_text, { hl_name = hl_name, pos_type = "overlay" })
          :render(self.results_canvas)

      Text:new()
          :set_text(" " .. result.header)
          :set_pos(1, row)
          :apply_style(Style.Types.virtual_text, { hl_name = "NarrowHeader", pos_type = "overlay" })
          :mark_entry(entry_header_index, self.entry_header_namespace_id)
          :render(self.results_canvas)

      row = row + 1
      entry_header_index = entry_header_index + 1
    end

    Text:new()
        :set_text(result.entry_text)
        :set_pos(0, row)
        :mark_entry(entry_result_index, self.entry_result_namespace_id)-- mark this as a selectable entry
        :render(self.results_canvas)

    -- Text:new()
    --     :set_text(self:get_query_result(result.entry_text, result.column))
    --     :set_pos(result.column - 1, row)
    --     :apply_style(Style.Types.highlight, { hl_name = "NarrowMatch" })
    --     :render(self.results_canvas)

    Text:new()
        :set_text(result.entry_header)
        :set_dimensions(5, 1)
        :set_alignment(Text.AlignmentType.right)
        :set_pos(0, row)
        :apply_style(Style.Types.virtual_text, { hl_name = "Comment", pos_type = "overlay" })
        :render(self.header_canvas)

    row = row + 1
    entry_result_index = entry_result_index + 1
  end

  self.results_canvas:render()
  self.header_canvas:render()

  self:render_hud()
end

-- @todo: deprecate once we're parsing json
function SearchProvider:get_query_result(line, start)
  -- local is_case_insensitive = string.match(self.query, "%u") == nil
  -- local target = line
  -- if is_case_insensitive then
  --   target = string.lower(line)
  -- end
  --
  -- local query = self.query
  -- local matches = 0
  -- local use_fixed_strings = not self.config.search.enable_regex
  -- if not use_fixed_strings then
  --   query, matches = string.gsub(query, "\\", "%")
  -- end
  -- local i, j = string.find(target, query, start - 1, use_fixed_strings)
  -- if i == nil or j == nil then
  --   print("error: could not resolve the narrow query result: " .. query)
  --   return query -- just return the query to see what happened
  -- end
  -- return line:sub(i, j + matches)
end

function SearchProvider:render_hud()
  -- self.hud_window:clear()
  --
  -- if self.results_window == nil then return end
  --
  -- local namespace_id = self.entry_result_namespace_id
  --
  -- local entry = self.results_window:get_entry_at_cursor(namespace_id)
  -- if entry == nil then
  --   namespace_id = self.entry_header_namespace_id
  --   entry = self.results_window:get_entry_at_cursor(namespace_id)
  -- end
  --
  -- local canvas = Canvas:new()
  --
  -- -- results
  -- if entry ~= nil then
  --   local entry_index = entry[1] -- id is the index in namespace
  --   local entries = self.results_window:get_all_entries(namespace_id)
  --   local hud_width, _ = self.hud_window:get_dimensions()
  --
  --   Text
  --       :new()
  --       :set_text(string.format("%d/%d  ", entry_index, #entries))
  --       :set_alignment(Text.AlignmentType.right)
  --       :set_pos(0, 0)
  --       :set_dimensions(hud_width, 1)
  --       :render(canvas)
  -- end
  --
  -- -- search config
  -- local btn_hl = "Identifier"
  -- if self.config.search.enable_regex then
  --   btn_hl = "Function"
  -- end
  -- Text
  --     :new()
  --     :set_text("|")
  --     :apply_style(Style.Types.highlight, { hl_name = btn_hl })
  --     :set_pos(0, 0)
  --     :render(canvas)
  --
  -- Text
  --     :new()
  --     :set_text("regex")
  --     :set_pos(1, 0)
  --     :apply_style(Style.Types.highlight, { hl_name = "Identifier" })
  --     :render(canvas)
  --
  -- -- @todo: lets have the window take a canvas instead to render
  -- -- api kinda ping pongs
  -- canvas:render_to_window(self.hud_window)
end

return SearchProvider
