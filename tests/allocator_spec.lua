local function check(condition, message)
  assert(condition, message)
end

local original_allocator = package.loaded["memory-trim.allocator"]
local original_ffi = package.loaded["ffi"]
local original_ffi_preload = package.preload["ffi"]
local original_collectgarbage = _G.collectgarbage
local source = debug.getinfo(1, "S").source:sub(2)
local allocator_path = vim.fn.fnamemodify(source, ":h:h") .. "/lua/memory-trim/allocator.lua"

local function load_fresh_allocator(ffi_value, collectgarbage_fn)
  package.loaded["memory-trim.allocator"] = nil
  package.loaded["ffi"] = nil
  package.preload["ffi"] = function()
    if ffi_value == false then
      error("controlled ffi-unavailable failure")
    end
    return ffi_value
  end
  _G.collectgarbage = collectgarbage_fn
  return assert(loadfile(allocator_path))()
end

local function with_fresh_allocator(ffi_value, collectgarbage_fn, body)
  local ok, err = xpcall(function()
    body(load_fresh_allocator(ffi_value, collectgarbage_fn))
  end, debug.traceback)

  package.loaded["memory-trim.allocator"] = original_allocator
  package.loaded["ffi"] = original_ffi
  package.preload["ffi"] = original_ffi_preload
  _G.collectgarbage = original_collectgarbage

  if not ok then
    error(err)
  end
end

local gc_calls = 0
with_fresh_allocator(false, function(argument)
  gc_calls = gc_calls + 1
  check(argument == "collect", "allocator.collect() must request Lua garbage collection")
end, function(allocator)
  check(not allocator.can_trim(), "allocator must report trimming unavailable without ffi")
  check(not allocator.collect(), "allocator.collect() must not throw when ffi is unavailable")
  check(gc_calls == 1, "allocator.collect() must run Lua GC when ffi is unavailable")
end)

local function check_unavailable_trim(cdef_throws)
  local ffi = {
    C = setmetatable({}, {
      __index = function()
        error("controlled malloc_trim-symbol-unavailable failure")
      end,
    }),
  }
  ffi.cdef = function()
    if cdef_throws then
      error("controlled ffi.cdef failure")
    end
  end

  local unavailable_gc_calls = 0
  with_fresh_allocator(ffi, function(argument)
    unavailable_gc_calls = unavailable_gc_calls + 1
    check(argument == "collect", "allocator.collect() must request Lua garbage collection")
  end, function(allocator)
    check(not allocator.can_trim(), "allocator must report trimming unavailable without malloc_trim")
    check(not allocator.collect(), "allocator.collect() must return false without malloc_trim")
    check(unavailable_gc_calls == 1, "allocator.collect() must run Lua GC without malloc_trim")
  end)
end

check_unavailable_trim(false)
check_unavailable_trim(true)

local trim_calls = 0
local ffi = {
  C = {
    malloc_trim = function(pad)
      trim_calls = trim_calls + 1
      check(pad == 0, "allocator.collect() must call malloc_trim with pad 0")
      return 1
    end,
  },
  cdef = function() end,
}

gc_calls = 0
with_fresh_allocator(ffi, function(argument)
  gc_calls = gc_calls + 1
  check(argument == "collect", "allocator.collect() must request Lua garbage collection")
end, function(allocator)
  check(allocator.can_trim(), "allocator must expose available malloc_trim")
  check(allocator.collect(), "allocator.collect() must return true when malloc_trim returns 1")
  check(trim_calls == 1, "allocator.collect() must call malloc_trim exactly once")
  check(gc_calls == 1, "allocator.collect() must run Lua GC before trimming")
end)

trim_calls = 0
ffi.C.malloc_trim = function()
  trim_calls = trim_calls + 1
  return 0
end
with_fresh_allocator(ffi, function() end, function(allocator)
  check(not allocator.collect(), "allocator.collect() must return false when malloc_trim returns 0")
  check(trim_calls == 1, "allocator.collect() must call malloc_trim when it returns 0")
end)

trim_calls = 0
ffi.C.malloc_trim = function()
  trim_calls = trim_calls + 1
  error("controlled malloc_trim failure")
end
local gc_attempts = 0
with_fresh_allocator(ffi, function()
  gc_attempts = gc_attempts + 1
end, function(allocator)
  check(not allocator.collect(), "allocator.collect() must not throw when malloc_trim fails")
  check(trim_calls == 1, "allocator.collect() must attempt malloc_trim once when it fails")
  check(gc_attempts == 1, "allocator.collect() must run Lua GC before malloc_trim failure")
end)

trim_calls = 0
ffi.C.malloc_trim = function(pad)
  trim_calls = trim_calls + 1
  check(pad == 0, "allocator.collect() must call malloc_trim with pad 0")
  return 1
end
with_fresh_allocator(ffi, function()
  error("controlled Lua GC failure")
end, function(allocator)
  check(allocator.collect(), "allocator.collect() must return trim success after Lua GC failure")
  check(trim_calls == 1, "malloc_trim must still run after Lua GC failure")
end)

local allocator = require("memory-trim.allocator")
check(type(allocator.collect) == "function", "real allocator must expose collect()")
check(type(allocator.can_trim) == "function", "real allocator must expose can_trim()")
local ok, result = pcall(allocator.can_trim)
check(ok, "real allocator.can_trim() must not throw")
check(type(result) == "boolean", "real allocator.can_trim() must return a boolean")
ok, result = pcall(allocator.collect)
check(ok, "real allocator.collect() must not throw")
check(type(result) == "boolean", "real allocator.collect() must return a boolean")

local memory_trim = require("memory-trim")
check(type(memory_trim.collect) == "function", "memory-trim must expose collect()")
check(type(memory_trim.can_trim) == "function", "memory-trim must expose can_trim()")
check(type(memory_trim.setup) == "function", "memory-trim must expose setup()")
ok, result = pcall(memory_trim.collect)
check(ok, "memory-trim.collect() must not throw")
check(type(result) == "boolean", "memory-trim.collect() must return a boolean")
ok, result = pcall(memory_trim.can_trim)
check(ok, "memory-trim.can_trim() must not throw")
check(type(result) == "boolean", "memory-trim.can_trim() must return a boolean")

print("memory-trim allocator tests: OK")
