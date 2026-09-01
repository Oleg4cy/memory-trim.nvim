local source = debug.getinfo(1, "S").source:sub(2)
local repository_root = vim.fn.fnamemodify(source, ":h:h")

vim.opt.runtimepath:prepend(repository_root)
