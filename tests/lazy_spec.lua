local function check(c,m) assert(c,m) end
local source=debug.getinfo(1,"S").source:sub(2)
local root=vim.fn.fnamemodify(source,":h:h")
local ok,result=pcall(dofile,root.."/lazy.lua")
check(ok,"lazy.lua must load"); check(type(result)=="table"); check(#result==1)
local spec=result[1]; check(type(spec)=="table"); check(spec[1]=="Oleg4cy/memory-trim.nvim"); check(spec.ft=="TelescopePrompt"); check(type(spec.opts)=="table"); check(spec.opts.telescope==true)
for _,k in ipairs({"keys","cmd","event","init","config","dependencies","priority"}) do check(spec[k]==nil,"unexpected field "..k) end
local count=0; for k,v in pairs(spec.opts) do count=count+1; check(k=="telescope" and v==true) end; check(count==1)
print("memory-trim lazy metadata tests: OK")
