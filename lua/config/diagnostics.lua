-- Workaround for an upstream leak in nvim 0.12.x.
--
-- `vim.diagnostic.set()` on a buffer that is not loaded routes through
-- `once_buf_loaded()` (runtime/lua/vim/diagnostic.lua), which registers a
-- `once = true` BufRead autocmd to redraw the diagnostics once the buffer
-- appears. It never checks whether it already registered one, so every call
-- stacks another. If the buffer is never loaded the autocmds never fire, never
-- get freed, and each closure retains the diagnostics table it was handed.
--
-- It bites hard with any language server that publishes project-wide: texlab
-- reports chktex diagnostics for every \input-ed file of a LaTeX manuscript,
-- so a dozen never-opened buffers each leak three closures per republish. A
-- build-on-save loop republishes constantly, and nvim grows by hundreds of MB
-- within minutes — plus every one of those autocmds is scanned on each buffer
-- read, which is what makes the editor feel sluggish.
--
-- The fix is the dedup upstream is missing: after a set on an unloaded buffer,
-- collapse diagnostic.lua's BufRead autocmds for that buffer back down to one.
-- Nothing observable changes — the surviving autocmd still fires on load and
-- still redraws — and the loop is a no-op once upstream dedups on its own.

local api = vim.api

-- Only ever touch autocmds owned by diagnostic.lua. Other plugins register
-- buffer-local BufRead autocmds too, and deleting those would break them.
local function owned_by_diagnostic(autocmd)
  if not autocmd.callback then return false end
  local ok, info = pcall(debug.getinfo, autocmd.callback, "S")
  return ok and info ~= nil and info.source ~= nil
    and info.source:find("vim/diagnostic.lua", 1, true) ~= nil
end

local orig_set = vim.diagnostic.set

vim.diagnostic.set = function(namespace, bufnr, diagnostics, opts)
  local result = orig_set(namespace, bufnr, diagnostics, opts)

  local buf = bufnr == 0 and api.nvim_get_current_buf() or bufnr
  if api.nvim_buf_is_valid(buf) and not api.nvim_buf_is_loaded(buf) then
    local pending = {}
    for _, autocmd in ipairs(api.nvim_get_autocmds({ event = "BufRead", buffer = buf })) do
      if owned_by_diagnostic(autocmd) then
        pending[#pending + 1] = autocmd.id
      end
    end
    for i = 1, #pending - 1 do
      pcall(api.nvim_del_autocmd, pending[i])
    end
  end

  return result
end
