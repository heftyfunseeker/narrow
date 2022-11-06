local NarrowResult = require("narrow_result")
M = {}

M.search = function(query_term, on_finished)
  -- clear previous results out
  M.results = {}

  local stdout = vim.loop.new_pipe(false)
  local stderr = vim.loop.new_pipe(false)

  if Handle ~= nil then
    Handle:close()
    Handle = nil
  end

  Handle = vim.loop.spawn(
    "rg",
    {
      args = M.build_rg_args(query_term),
      stdio = { nil, stdout, stderr },
    },
    vim.schedule_wrap(function()
      stdout:read_stop()
      stderr:read_stop()
      stdout:close()
      stderr:close()
      Handle:close()
      Handle = nil

      on_finished(M.results)
    end)
  )

  local onread = function(err, input_stream)
    if err then
      print("ERROR: ", err)
    end

    if input_stream then
      M.add_grep_result(input_stream)
    end
  end

  vim.loop.read_start(stdout, onread)
  vim.loop.read_start(stderr, onread)
end

M.add_grep_result = function (grep_results)
  local vals = vim.split(grep_results, "\n")
  for _, line in pairs(vals) do
    if line ~= "" then
      -- @todo: this will be json, how do we want this?
      local result = NarrowResult:new(line)
      if result then
        table.insert(M.results, result)
      end
    end
  end
end

M.build_rg_args = function(query_term, options)
  local args = { query_term, "--smart-case", "--vimgrep", "-M", "1024" }

  if options and not options.enable_regex then
    table.insert(args, "--fixed-strings")
  end

  return args
end

return M
