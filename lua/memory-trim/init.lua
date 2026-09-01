local M = {}

local allocator = require("memory-trim.allocator")

function M.collect()
  return allocator.collect()
end

function M.can_trim()
  return allocator.can_trim()
end

return M
