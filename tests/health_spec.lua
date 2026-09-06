local function check(condition, message)
  assert(condition, message)
end

local source = debug.getinfo(1, "S").source:sub(2)
local root = vim.fn.fnamemodify(source, ":h:h")
local health_path = root .. "/lua/memory-trim/health.lua"

local original_vim = _G.vim
local original_memory_trim = package.loaded["memory-trim"]
local original_memory_trim_preload = package.preload["memory-trim"]
local original_telescope = package.loaded["telescope"]
local original_telescope_preload = package.preload["telescope"]
local original_telescope_integration = package.loaded["memory-trim.integrations.telescope"]
local original_telescope_integration_preload = package.preload["memory-trim.integrations.telescope"]

local function restore_state()
  _G.vim = original_vim
  package.loaded["memory-trim"] = original_memory_trim
  package.preload["memory-trim"] = original_memory_trim_preload
  package.loaded["telescope"] = original_telescope
  package.preload["telescope"] = original_telescope_preload
  package.loaded["memory-trim.integrations.telescope"] = original_telescope_integration
  package.preload["memory-trim.integrations.telescope"] = original_telescope_integration_preload
end

local function has_message(records, method, message)
  for _, record in ipairs(records) do
    if record.method == method and record.message == message then
      return true
    end
  end
  return false
end

local function has_message_starting_with(records, method, prefix)
  for _, record in ipairs(records) do
    if record.method == method and record.message:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function has_method(records, method)
  for _, record in ipairs(records) do
    if record.method == method then
      return true
    end
  end
  return false
end

local function error_messages_contain(records, text)
  for _, record in ipairs(records) do
    if record.method == "error" and record.message:find(text, 1, true) then
      return true
    end
  end
  return false
end

local function prepare_success_state(can_trim)
  local records = {}
  local calls = { collect = 0, can_trim = 0, setup = 0, telescope = 0, telescope_integration = 0 }

  _G.vim = { health = {} }
  for _, method in ipairs({ "start", "ok", "info", "warn", "error" }) do
    _G.vim.health[method] = function(message)
      records[#records + 1] = { method = method, message = message }
    end
  end

  package.loaded["memory-trim"] = {
    collect = function()
      calls.collect = calls.collect + 1
      error("healthcheck must not call collect()")
    end,
    can_trim = function()
      calls.can_trim = calls.can_trim + 1
      return can_trim()
    end,
    setup = function()
      calls.setup = calls.setup + 1
      error("healthcheck must not call setup()")
    end,
  }
  package.preload["memory-trim"] = nil
  package.loaded["telescope"] = nil
  package.preload["telescope"] = function()
    calls.telescope = calls.telescope + 1
    error("healthcheck must not require Telescope")
  end
  package.loaded["memory-trim.integrations.telescope"] = nil
  package.preload["memory-trim.integrations.telescope"] = function()
    calls.telescope_integration = calls.telescope_integration + 1
    error("healthcheck must not require the Telescope integration")
  end

  return records, calls
end

local function run_healthcheck()
  local health = assert(loadfile(health_path))()
  health.check()
end

local function assert_passive_telescope(calls)
  check(calls.telescope == 0, "healthcheck must not require Telescope")
  check(calls.telescope_integration == 0, "healthcheck must not require the Telescope integration")
  check(package.loaded["telescope"] == nil, "Telescope must remain unloaded")
  check(
    package.loaded["memory-trim.integrations.telescope"] == nil,
    "Telescope integration must remain unloaded"
  )
end

local function run()
  local records, calls = prepare_success_state(function()
    return true
  end)
  local ok, err = pcall(run_healthcheck)
  check(ok, "available-native healthcheck must not throw: " .. tostring(err))
  check(has_message(records, "start", "memory-trim"), "healthcheck must start memory-trim report")
  check(has_message(records, "ok", "Public memory-trim module is available"), "healthcheck must report public module")
  check(has_message(records, "ok", "Native malloc_trim support is available"), "healthcheck must report native trim")
  check(has_message(records, "info", "Telescope integration is optional"), "healthcheck must report optional Telescope")
  check(calls.can_trim == 1, "healthcheck must call can_trim() exactly once when available")
  check(calls.collect == 0, "healthcheck must not call collect() when available")
  check(calls.setup == 0, "healthcheck must not call setup() when available")
  check(not has_method(records, "error"), "available-native healthcheck must not report errors")
  check(not has_method(records, "warn"), "available-native healthcheck must not report warnings")
  assert_passive_telescope(calls)
  restore_state()

  records, calls = prepare_success_state(function()
    return false
  end)
  ok, err = pcall(run_healthcheck)
  check(ok, "unavailable-native healthcheck must not throw: " .. tostring(err))
  check(calls.can_trim == 1, "healthcheck must call can_trim() exactly once when unavailable")
  check(calls.collect == 0, "healthcheck must not call collect() when unavailable")
  check(calls.setup == 0, "healthcheck must not call setup() when unavailable")
  check(not has_method(records, "error"), "unavailable native trim must not report an error")
  check(not has_method(records, "warn"), "unavailable native trim must not report a warning")
  check(
    has_message(
      records,
      "info",
      "Native allocator trimming is unavailable; the plugin remains functional through Lua garbage collection"
    ),
    "healthcheck must report Lua GC fallback"
  )
  check(has_message(records, "info", "Telescope integration is optional"), "healthcheck must report optional Telescope")
  assert_passive_telescope(calls)
  restore_state()

  local failure_records = {}
  _G.vim = { health = {} }
  for _, method in ipairs({ "start", "ok", "info", "warn", "error" }) do
    _G.vim.health[method] = function(message)
      failure_records[#failure_records + 1] = { method = method, message = message }
    end
  end
  package.loaded["memory-trim"] = nil
  package.preload["memory-trim"] = function()
    error("controlled memory-trim require failure")
  end
  ok, err = pcall(run_healthcheck)
  check(ok, "require-failure healthcheck must not throw: " .. tostring(err))
  check(
    has_message_starting_with(failure_records, "error", "Could not require memory-trim:"),
    "healthcheck must report memory-trim require failure"
  )
  check(not has_method(failure_records, "ok"), "API validation must not proceed after require failure")
  check(not has_message(failure_records, "ok", "Native malloc_trim support is available"), "native trim must not be reported")
  restore_state()

  for _, invalid_name in ipairs({ "collect", "can_trim", "setup" }) do
    records, calls = prepare_success_state(function()
      return true
    end)
    package.loaded["memory-trim"][invalid_name] = nil
    ok, err = pcall(run_healthcheck)
    check(ok, "invalid " .. invalid_name .. " healthcheck must not throw: " .. tostring(err))
    check(
      has_message(records, "error", "Public API member '" .. invalid_name .. "' is not a function"),
      "healthcheck must report invalid " .. invalid_name .. " API member"
    )
    check(calls.can_trim == 0, "healthcheck must not call can_trim() with invalid " .. invalid_name)
    check(calls.collect == 0, "healthcheck must not call collect() with invalid " .. invalid_name)
    check(calls.setup == 0, "healthcheck must not call setup() with invalid " .. invalid_name)
    check(not has_message(records, "ok", "Native malloc_trim support is available"), "native trim must not be reported")
    check(
      not has_message(
        records,
        "info",
        "Native allocator trimming is unavailable; the plugin remains functional through Lua garbage collection"
      ),
      "native trim fallback must not be reported"
    )
    restore_state()
  end

  records, calls = prepare_success_state(function()
    error("controlled can_trim failure")
  end)
  ok, err = pcall(run_healthcheck)
  check(ok, "can_trim-failure healthcheck must not throw: " .. tostring(err))
  check(calls.can_trim == 1, "healthcheck must attempt failing can_trim() exactly once")
  check(calls.collect == 0, "healthcheck must not call collect() after can_trim() failure")
  check(calls.setup == 0, "healthcheck must not call setup() after can_trim() failure")
  check(has_message_starting_with(records, "error", "can_trim() failed:"), "healthcheck must report can_trim() failure")
  check(error_messages_contain(records, "controlled can_trim failure"), "can_trim() failure report must include controlled error text")
  check(not has_message(records, "ok", "Native malloc_trim support is available"), "native trim must not be reported")
  check(
    not has_message(
      records,
      "info",
      "Native allocator trimming is unavailable; the plugin remains functional through Lua garbage collection"
    ),
    "native trim fallback must not be reported"
  )
  check(not has_message(records, "info", "Telescope integration is optional"), "Telescope info must not follow can_trim failure")
  assert_passive_telescope(calls)
  restore_state()
end

local ok, err = xpcall(run, debug.traceback)
local cleanup_ok, cleanup_err = xpcall(restore_state, debug.traceback)
if not ok then
  error(err)
end
if not cleanup_ok then
  error(cleanup_err)
end

print("memory-trim health tests: OK")
