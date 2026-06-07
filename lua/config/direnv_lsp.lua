-- Per-project LSP environments via direnv.
--
-- Editor environment variables are process-global in Neovim, so two buffers
-- can never see different `$PATH`s at once — any approach that rewrites the
-- global env (what `direnv.vim` does) is "last directory wins". The thing we
-- actually need a per-project environment for is the *processes nvim spawns*
-- for a buffer, above all its language servers. Those are launched with a
-- per-invocation cwd/env, so we solve it there: start each server through
-- `direnv exec <nearest-.envrc-root> <binary>`, which loads that project's
-- devshell and runs the server inside it.
--
-- This gives genuine concurrent multi-direnv (nvim reuses one client per
-- (name, root_dir), so files under different `.envrc`s get separate servers
-- with separate envs) with no global cwd movement and no reliance on the
-- binary being on nvim's own PATH.
--
-- `direnv exec` execve-replaces itself with the server binary, so nvim spawns
-- a single process that *becomes* the server: normal client shutdown
-- terminates it cleanly, no wrapper process is left orphaned.
--
-- See README.md → "Per-project tools via direnv" and per-project-direnv-env.md.
local M = {}

-- Nearest ancestor of the buffer's file that contains an `.envrc`. This is the
-- "scan up to the project root" step, performed by direnv's own root search
-- semantics. Returns nil when the buffer sits under no devshell.
local function env_root(bufnr)
    local name = vim.api.nvim_buf_get_name(bufnr)
    local from = (name ~= "" and vim.fs.dirname(name)) or vim.fn.getcwd()
    return vim.fs.root(from, ".envrc")
end

-- Register + enable an LSP server whose binary lives in a project devshell
-- selected by direnv. `binary` defaults to `name`. `opts` is a normal
-- vim.lsp.config table (settings, capabilities overrides, …); its `cmd` and
-- `root_dir` are filled in here and should not be set by the caller.
--
-- Safe to call from the base config for a cross-project server (e.g. texlab):
-- the root_dir gate keeps it inert until a buffer actually sits under an
-- `.envrc`, so it never spawns-and-fails in unrelated buffers.
function M.server(name, binary, opts)
    binary = binary or name
    local cfg = opts or {}

    -- Gate startup on the buffer having an `.envrc` ancestor: without one the
    -- devshell (and thus the binary) does not exist, so we must not start.
    -- A root_dir callback that conditionally calls on_dir is the native way to
    -- say "don't start here"; the root it reports also feeds config.root_dir
    -- for the cmd below. (Note: this checks `.envrc` *existence*, not whether
    -- it's been `direnv allow`ed. An un-allowed `.envrc` passes the gate and
    -- then fails at spawn with a clear "is blocked. Run `direnv allow`" line in
    -- :LspLog — that is the expected prompt to allow the project.)
    cfg.root_dir = function(bufnr, on_dir)
        local root = env_root(bufnr)
        if root then on_dir(root) end
    end

    -- Spawn the server inside the project's direnv environment. cmd-as-function
    -- receives the resolved config (incl. root_dir, populated by the callback
    -- above before cmd runs — the same field the basedpyright before_init in
    -- lsp.lua already relies on) and returns the RPC client. We don't fall back
    -- to getcwd(): the root_dir gate guarantees a root exists whenever a server
    -- starts, and running `direnv exec` somewhere with no `.envrc` would defeat
    -- the gate's whole purpose.
    cfg.cmd = function(dispatchers, config)
        local root = config.root_dir or env_root(0)
        return vim.lsp.rpc.start(
            { "direnv", "exec", root, binary },
            dispatchers,
            { cwd = root }
        )
    end

    vim.lsp.config(name, cfg)
    vim.lsp.enable(name)
end

return M
