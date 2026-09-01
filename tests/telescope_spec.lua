local api = vim.api
local original_allocator = package.loaded["memory-trim.allocator"]
local original_telescope_preload = package.preload["telescope"]
local collect_calls = 0

package.loaded["memory-trim.allocator"] = {
  collect = function()
    collect_calls = collect_calls + 1
    return true
  end,
}
package.preload["telescope"] = function()
  error("memory-trim telescope integration must not require telescope")
end

local function check(condition, message)
  assert(condition, message)
end

local function scratch_buffer()
  local buffer = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buffer, "bufhidden", "hide")
  return buffer
end

local function enter(buffer)
  api.nvim_set_current_buf(buffer)
end

local function leave(buffer)
  local destination = scratch_buffer()
  enter(destination)
  return destination
end

local function wait_for_collect_calls(expected_calls)
  check(vim.wait(500, function()
    return collect_calls == expected_calls
  end), "deferred allocator cleanup did not run")
  check(collect_calls == expected_calls, "allocator cleanup call count mismatch")
end

local function delete_buffer(buffer)
  if api.nvim_buf_is_valid(buffer) then
    api.nvim_buf_delete(buffer, { force = true })
  end
end

local function set_filetype(buffer, filetype)
  api.nvim_buf_set_option(buffer, "filetype", filetype)
end

local function run()
  local integration = require("memory-trim.integrations.telescope")
  check(type(integration.setup) == "function", "telescope integration setup must be a function")

  local already_open = scratch_buffer()
  enter(already_open)
  set_filetype(already_open, "TelescopePrompt")
  local before = collect_calls
  integration.setup()
  local destination = leave(already_open)
  check(collect_calls == before, "TelescopePrompt cleanup must be deferred")
  wait_for_collect_calls(before + 1)
  check(collect_calls == before + 1, "setup must handle an already-open TelescopePrompt")
  delete_buffer(already_open)
  delete_buffer(destination)

  integration.setup()
  local prompt = scratch_buffer()
  enter(prompt)
  set_filetype(prompt, "TelescopePrompt")
  before = collect_calls
  destination = leave(prompt)
  check(collect_calls == before, "TelescopePrompt cleanup must be deferred")
  wait_for_collect_calls(before + 1)
  check(collect_calls == before + 1, "TelescopePrompt close must collect exactly once")
  delete_buffer(prompt)
  delete_buffer(destination)

  local normal = scratch_buffer()
  enter(normal)
  set_filetype(normal, "lua")
  before = collect_calls
  destination = leave(normal)
  vim.wait(500, function()
    return collect_calls ~= before
  end)
  check(collect_calls == before, "non-Telescope buffers must not trigger cleanup")
  delete_buffer(normal)
  delete_buffer(destination)

  integration.setup()
  integration.setup()
  local repeated = scratch_buffer()
  enter(repeated)
  set_filetype(repeated, "TelescopePrompt")
  before = collect_calls
  destination = leave(repeated)
  check(collect_calls == before, "TelescopePrompt cleanup must be deferred")
  wait_for_collect_calls(before + 1)
  check(collect_calls == before + 1, "repeated setup must not duplicate cleanup")
  delete_buffer(repeated)
  delete_buffer(destination)

  local one_shot = scratch_buffer()
  enter(one_shot)
  set_filetype(one_shot, "TelescopePrompt")
  before = collect_calls
  destination = leave(one_shot)
  check(collect_calls == before, "TelescopePrompt cleanup must be deferred")
  wait_for_collect_calls(before + 1)
  enter(one_shot)
  local second_destination = leave(one_shot)
  check(collect_calls == before + 1, "one-shot cleanup must not run synchronously twice")
  vim.wait(500, function()
    return collect_calls ~= before + 1
  end)
  check(collect_calls == before + 1, "one TelescopePrompt must trigger cleanup only once")
  delete_buffer(one_shot)
  delete_buffer(destination)
  delete_buffer(second_destination)
end

local ok, err = xpcall(run, debug.traceback)
package.loaded["memory-trim.allocator"] = original_allocator
package.preload["telescope"] = original_telescope_preload

if not ok then
  error(err)
end

print("memory-trim telescope tests: OK")
