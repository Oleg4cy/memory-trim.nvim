local M = {}

local attached_buffers = {}

local function attach(bufnr, group)
  if not vim.api.nvim_buf_is_valid(bufnr) or attached_buffers[bufnr] then
    return
  end

  local ok, filetype = pcall(vim.api.nvim_get_option_value, "filetype", {
    buf = bufnr,
  })
  if not ok or filetype ~= "TelescopePrompt" then
    return
  end

  attached_buffers[bufnr] = true

  vim.api.nvim_create_autocmd("BufLeave", {
    group = group,
    buffer = bufnr,
    once = true,
    callback = function()
      attached_buffers[bufnr] = nil

      vim.defer_fn(function()
        require("memory-trim.allocator").collect()
      end, 100)
    end,
  })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("MemoryTrimTelescope", {
    clear = true,
  })

  attached_buffers = {}

  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "TelescopePrompt",
    callback = function(args)
      attach(args.buf, group)
    end,
  })

  for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
    attach(bufnr, group)
  end
end

return M
