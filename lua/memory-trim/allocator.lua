local M = {}

local trim

local ffi_ok, ffi = pcall(require, "ffi")

if ffi_ok then
  pcall(ffi.cdef, "int malloc_trim(size_t pad);")

  local trim_ok, trim_fn = pcall(function()
    return ffi.C.malloc_trim
  end)

  if trim_ok then
    trim = trim_fn
  end
end

function M.collect()
  collectgarbage("collect")

  if not trim then
    return false
  end

  local ok, result = pcall(trim, 0)

  return ok and result == 1
end

function M.can_trim()
  return trim ~= nil
end

return M
