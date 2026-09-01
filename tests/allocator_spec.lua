local function check(condition, message)
  assert(condition, message)
end

local allocator = require("memory-trim.allocator")
check(type(allocator.collect) == "function", "allocator.collect must be a function")
check(type(allocator.can_trim) == "function", "allocator.can_trim must be a function")

local can_trim_ok, can_trim_result = pcall(allocator.can_trim)
check(can_trim_ok, "allocator.can_trim() must not throw")
check(type(can_trim_result) == "boolean", "allocator.can_trim() must return a boolean")

local collect_ok, collect_result = pcall(allocator.collect)
check(collect_ok, "allocator.collect() must not throw")
check(type(collect_result) == "boolean", "allocator.collect() must return a boolean")

local memory_trim = require("memory-trim")
check(type(memory_trim.collect) == "function", "memory_trim.collect must be a function")
check(type(memory_trim.can_trim) == "function", "memory_trim.can_trim must be a function")
check(type(memory_trim.setup) == "function", "memory_trim.setup must be a function")

local public_collect_ok, public_collect_result = pcall(memory_trim.collect)
check(public_collect_ok, "memory_trim.collect() must not throw")
check(type(public_collect_result) == "boolean", "memory_trim.collect() must return a boolean")

local public_can_trim_ok, public_can_trim_result = pcall(memory_trim.can_trim)
check(public_can_trim_ok, "memory_trim.can_trim() must not throw")
check(type(public_can_trim_result) == "boolean", "memory_trim.can_trim() must return a boolean")

print("memory-trim allocator tests: OK")
