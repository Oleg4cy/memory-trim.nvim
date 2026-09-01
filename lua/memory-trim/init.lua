local M = {}

local allocator = require("memory-trim.allocator")

function M.collect()
  return allocator.collect()
end

function M.can_trim()
  return allocator.can_trim()
end

function M.setup(opts)
  opts = opts or {}

  if opts.telescope == true then
    require("memory-trim.integrations.telescope").setup()
  end
end

return M
