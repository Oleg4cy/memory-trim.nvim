local api = vim.api

local function check(condition, message)
  assert(condition, message)
end

local original_allocator = package.loaded["memory-trim.allocator"]
local original_telescope_preload = package.preload["telescope"]
local original_telescope_integration = package.loaded["memory-trim.integrations.telescope"]
local collect_calls = 0
local scratch_buffers = {}

local function scratch_buffer(filetype)
  local buffer = api.nvim_create_buf(false, true)
  scratch_buffers[#scratch_buffers + 1] = buffer
  api.nvim_buf_set_option(buffer, "bufhidden", "hide")
  if filetype then
    api.nvim_buf_set_option(buffer, "filetype", filetype)
  end
  return buffer
end

local function enter(buffer)
  api.nvim_set_current_buf(buffer)
end

local function leave(buffer)
  check(
    api.nvim_get_current_buf() == buffer,
    "leave() must be called while the buffer being left is current"
  )
  local destination = scratch_buffer()
  enter(destination)
  return destination
end

local function delete_buffer(buffer)
  if api.nvim_buf_is_valid(buffer) then
    api.nvim_buf_delete(buffer, { force = true })
  end
end

local function set_filetype(buffer, filetype)
  api.nvim_buf_set_option(buffer, "filetype", filetype)
end

local function wait_for_collect_calls(expected, message)
  local completed = vim.wait(500, function()
    return collect_calls >= expected
  end)
  check(completed, message .. " before the timeout")
  check(collect_calls == expected, message .. "; got " .. collect_calls .. " cleanups")
end

local function assert_no_new_collects(expected, timeout, message)
  vim.wait(timeout, function()
    return false
  end)
  check(collect_calls == expected, message .. "; got " .. collect_calls .. " cleanups")
end

local function clear_telescope_augroup()
  pcall(api.nvim_del_augroup_by_name, "MemoryTrimTelescope")
end

local function cleanup_test_state()
  clear_telescope_augroup()
  for _, buffer in ipairs(scratch_buffers) do
    pcall(delete_buffer, buffer)
  end
  package.loaded["memory-trim.allocator"] = original_allocator
  package.preload["telescope"] = original_telescope_preload
  package.loaded["memory-trim.integrations.telescope"] = original_telescope_integration
end

package.loaded["memory-trim.allocator"] = {
  collect = function()
    collect_calls = collect_calls + 1
    return true
  end,
}
package.preload["telescope"] = function()
  error("controlled failure: Telescope must not be required by memory-trim integration")
end
package.loaded["memory-trim.integrations.telescope"] = nil

local function run()
  local telescope_integration = require("memory-trim.integrations.telescope")
  check(
    type(telescope_integration.setup) == "function",
    "Telescope integration must load without requiring the Telescope plugin"
  )

  local existing_prompt = scratch_buffer("TelescopePrompt")
  enter(existing_prompt)
  telescope_integration.setup()
  leave(existing_prompt)
  assert_no_new_collects(0, 250, "BufLeave alone must not trigger Telescope cleanup")
  delete_buffer(existing_prompt)
  wait_for_collect_calls(1, "TelescopePrompt wipe must trigger exactly one deferred cleanup")

  local filetype_prompt = scratch_buffer()
  enter(filetype_prompt)
  set_filetype(filetype_prompt, "TelescopePrompt")
  vim.wait(20)
  leave(filetype_prompt)
  assert_no_new_collects(1, 150, "BufLeave alone must not trigger Telescope cleanup")
  delete_buffer(filetype_prompt)
  wait_for_collect_calls(2, "FileType TelescopePrompt wipe must trigger exactly one deferred cleanup")

  local non_telescope_buffer = scratch_buffer("lua")
  enter(non_telescope_buffer)
  leave(non_telescope_buffer)
  delete_buffer(non_telescope_buffer)
  assert_no_new_collects(2, 200, "non-Telescope buffer wipe must not trigger cleanup")

  telescope_integration.setup()
  telescope_integration.setup()
  local repeated_setup_prompt = scratch_buffer("TelescopePrompt")
  enter(repeated_setup_prompt)
  leave(repeated_setup_prompt)
  delete_buffer(repeated_setup_prompt)
  check(collect_calls == 2, "TelescopePrompt wipe cleanup must be deferred")
  wait_for_collect_calls(3, "repeated setup must not duplicate Telescope cleanup")

  local pending_prompt = scratch_buffer("TelescopePrompt")
  enter(pending_prompt)
  leave(pending_prompt)
  delete_buffer(pending_prompt)
  telescope_integration.setup()
  wait_for_collect_calls(4, "pending Telescope cleanup must survive repeated setup exactly once")

  local new_setup_prompt = scratch_buffer()
  enter(new_setup_prompt)
  set_filetype(new_setup_prompt, "TelescopePrompt")
  vim.wait(20)
  leave(new_setup_prompt)
  delete_buffer(new_setup_prompt)
  wait_for_collect_calls(5, "new prompt under repeated setup must add one cleanup")

  local single_wipe_prompt = scratch_buffer("TelescopePrompt")
  enter(single_wipe_prompt)
  leave(single_wipe_prompt)
  delete_buffer(single_wipe_prompt)
  check(collect_calls == 5, "TelescopePrompt wipe cleanup must not be synchronous")
  wait_for_collect_calls(6, "one TelescopePrompt wipe must trigger exactly one cleanup")
  assert_no_new_collects(6, 200, "waiting longer must not trigger a second cleanup")
end

local ok, err = xpcall(run, debug.traceback)
local cleanup_ok, cleanup_err = xpcall(cleanup_test_state, debug.traceback)
if not ok then
  error(err)
end
if not cleanup_ok then
  error(cleanup_err)
end

print("memory-trim telescope tests: OK")
