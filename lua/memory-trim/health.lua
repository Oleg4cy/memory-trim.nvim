local M = {}

function M.check()
  vim.health.start("memory-trim")

  local ok, memory_trim = pcall(require, "memory-trim")
  if not ok then
    vim.health.error("Could not require memory-trim: " .. tostring(memory_trim))
    return
  end

  vim.health.ok("Public memory-trim module is available")

  local api_valid = true
  for _, name in ipairs({ "collect", "can_trim", "setup" }) do
    if type(memory_trim[name]) ~= "function" then
      vim.health.error("Public API member '" .. name .. "' is not a function")
      api_valid = false
    end
  end

  if not api_valid then
    return
  end

  local can_trim_ok, can_trim = pcall(memory_trim.can_trim)
  if not can_trim_ok then
    vim.health.error("can_trim() failed: " .. tostring(can_trim))
    return
  end

  if can_trim then
    vim.health.ok("Native malloc_trim support is available")
  else
    vim.health.info(
      "Native allocator trimming is unavailable; the plugin remains functional through Lua garbage collection"
    )
  end

  vim.health.info("Telescope integration is optional")
end

return M
