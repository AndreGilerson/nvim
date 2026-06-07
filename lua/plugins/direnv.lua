-- direnv integration: when nvim enters a directory that has an `.envrc`
-- (typically `use flake` for a project's Nix devshell), pull that environment
-- into the *running* nvim process. Any language server nvim spawns afterwards
-- then inherits the devshell's PATH, so per-project toolchains work without
-- launching nvim from inside `nix develop`.
--
-- Requires the `direnv` binary on PATH (and `nix-direnv` for fast `use flake`
-- caching). See README.md → "Per-project tools via direnv".
return {
    "direnv/direnv.vim",
    -- Not lazy: we want the current directory's environment loaded as soon as
    -- nvim starts, before the first LSP server is spawned.
    lazy = false,
    init = function()
        -- Don't print the diff of exported variables on every directory change.
        vim.g.direnv_silent_load = 1
    end,
}
