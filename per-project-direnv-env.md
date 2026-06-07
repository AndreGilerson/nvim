# Per-project / per-buffer direnv environments

Status: implemented — helper added as `lua/config/direnv_lsp.lua`; README
documents per-project registration. Verified on this machine: direnv 2.37.1
`exec` execve-replaces itself (no orphan on `:LspRestart`/quit), and an
un-allowed `.envrc` fails the spawn with a clear `is blocked` message rather
than hanging. The §5.1 helper was implemented with two refinements: the `cmd`
fallback drops `getcwd()` (the root_dir gate already guarantees a root, and
running `direnv exec` without an `.envrc` would defeat the gate), and the
un-allowed-`.envrc` failure mode is documented rather than detected (detecting
it would add a process spawn to every server start). Cross-project servers
(texlab, …) are documented for per-project `.nvim.lua` registration rather than
baked into the base config, to match this repo's "general-purpose base,
project-specific layering" philosophy — the base-config option (§6) remains
available.
Author: design notes for this nvim config
Scope: how language servers (and later, other spawned tools) pick up the
correct per-project Nix devshell environment when several projects — each
with its own `.envrc` — are edited in a single nvim session.

---

## 1. Goal

Open one nvim session anywhere (typically at a monorepo root) and have each
buffer's tooling resolve against *that file's* project environment:

> For each buffer/window, find the nearest `.envrc` by scanning up from the
> file's directory to the project root, and run that buffer's language
> servers (and ideally formatters / `:!` tools) with that `.envrc`'s
> environment — without any other buffer or the global editor state being
> affected.

Concretely, in this repo's own use case: nvim launched at `~/10_diss` (a
polyglot thesis monorepo) should run `texlab` for `thesis/*.tex` against
`thesis/.envrc` (a `use flake` TeX Live devshell), while a Python buffer
under another subproject keeps resolving against its own env, simultaneously.

---

## 2. How things work today

- **direnv integration is stock `direnv/direnv.vim`** (`lua/plugins/direnv.lua`),
  configured only with `g:direnv_silent_load = 1` and `lazy = false`.
- That plugin re-exports the environment **only on `VimEnter` and
  `DirChanged`** (on Neovim, which supports `DirChanged`; `BufEnter` is just a
  fallback for old Vim). Its `direnv#export_core()` runs `direnv export vim` in
  the **process working directory** — it never inspects the buffer's directory
  and never `chdir`s.
- `direnv export vim` **mutates the global editor environment** (`let $VAR=…`).
  There is no per-buffer environment.
- **`exrc` is enabled** (`lua/config/options.lua`): a `.nvim.lua` in the launch
  directory is sourced once at startup, gated by `vim.secure`.
- **LSP** uses the native `vim.lsp.config()` / `vim.lsp.enable()` API
  (`lua/plugins/lsp.lua`). `nvim-lspconfig` is kept only for the bundled
  `lsp/<name>.lua` defaults (cmd, root markers, filetypes). Servers are reused
  per `(name, root_dir)`.
- **Python already does file-relative discovery** out of band: `basedpyright`'s
  `before_init` reads `config.root_dir`, walks up for a venv/`.direnv` python,
  and restarts on change (`lua/plugins/lsp.lua`, around the `basedpyright`
  block). This is precedent that `config.root_dir` is resolved and readable in
  our hooks — the new design leans on the same fact.

### Consequence

Because the export is keyed to the **process cwd** via `DirChanged`:

- Multi-direnv *does* work if you change directory (`:cd`/`:tcd` that emits
  `DirChanged`).
- It does **not** trigger from merely opening a file in another subproject —
  there is no `autochdir` and no "follow the file's project root" logic.
- The README's "…or open a file in another project" is therefore optimistic
  for the config as-is; it only holds if opening the file also moved the cwd.

---

## 3. The core constraint, and the reframe

**Editor environment variables are process-global in Neovim.** Two buffers
cannot see different `$PATH` values at the same time. So a literally
per-buffer *environment inside the editor* is impossible, and any approach
based on rewriting the global env (what `direnv.vim` does) is fundamentally
"last directory wins."

The reframe: we don't need per-buffer env *in the editor*. We need the
**processes nvim spawns for a buffer** — first and foremost the LSP server —
to be launched with the right environment. Those are spawned via
`jobstart` / `vim.lsp.rpc.start`, which accept a **per-invocation `cwd` and
`env`**. So the correct place to solve this is **at process spawn**, per
server, keyed to that server's resolved root.

This sidesteps both problems at once: no global env mutation, and no global
cwd movement.

---

## 4. Options considered

| Option | Mechanism | Verdict |
|---|---|---|
| A. `autochdir` | cwd follows current file's dir; direnv.vim re-exports on `DirChanged` | Rejected. Global cwd thrash: Telescope root, `:grep`, `:terminal`, nvim-tree root, relative paths all move per buffer. Still last-wins global env. |
| B. cwd-follow autocmd (`BufEnter` → `:cd` nearest `.envrc`) | Snap global cwd to direnv root so `DirChanged` fires | Rejected as the long-term answer. Same global-cwd ramifications as A, just coarser. Fine as a quick per-project stopgap; not what we want in the base config. |
| **C. per-spawn `direnv exec` (chosen)** | Launch each server via `direnv exec <root> <binary>`; resolve `<root>` per buffer | Chosen. True per-project env for the thing that matters (spawned tools). No global cwd or env side effects. Binary need not be on the global PATH. |

### Why C wins

- `direnv exec DIR CMD…` loads the first `.envrc` found at/above `DIR` and runs
  `CMD` with that environment — exactly the "scan up to the project root"
  behavior requested, implemented by direnv itself.
- Because the binary is located *inside* the loaded env, `texlab` (and any
  other project server) never has to be on nvim's global `$PATH`.
- nvim reuses LSP clients per `(name, root_dir)`, so buffers under the same
  `.envrc` share one server while a file in a different subproject gets its own
  client with its own env — genuine concurrent multi-direnv.
- No `:cd`, so finders/terminals/tree stay anchored where the user put them.

### What C does not cover

- In-editor `$VAR` reads and non-LSP child processes (`:!`, `:terminal`,
  formatters not wrapped). For those, `direnv.vim` stays useful (cwd-based,
  global) — they are lower-stakes and can be wrapped later (see §9). The two
  mechanisms coexist: per-LSP env is correct regardless of what the global env
  happens to be.

---

## 5. Chosen design

### 5.1 A small helper module

New file `lua/config/direnv_lsp.lua` exposing a `server(name, binary, opts)`
registrar. It (a) computes the buffer's nearest `.envrc` root, (b) only starts
the server when such a root exists, and (c) launches the binary through
`direnv exec` in that root.

```lua
-- lua/config/direnv_lsp.lua
local M = {}

-- Nearest ancestor of the buffer's file that contains an `.envrc`.
local function env_root(bufnr)
  local name = vim.api.nvim_buf_get_name(bufnr)
  local from = (name ~= "" and vim.fs.dirname(name)) or vim.fn.getcwd()
  return vim.fs.root(from, ".envrc")
end

-- Register + enable an LSP server whose binary lives in a project devshell
-- selected by direnv. `binary` defaults to `name`. `opts` is a normal
-- vim.lsp.config table (settings, capabilities overrides, …).
function M.server(name, binary, opts)
  binary = binary or name
  local cfg = opts or {}

  -- Start only when the buffer actually sits under an `.envrc`; otherwise the
  -- devshell (and thus the binary) does not exist. Calling on_dir with the
  -- root both gates startup and feeds config.root_dir for the cmd below.
  cfg.root_dir = function(bufnr, on_dir)
    local root = env_root(bufnr)
    if root then on_dir(root) end
  end

  -- Spawn the server inside the project's direnv environment. cmd-as-function
  -- receives the resolved config (incl. root_dir) and returns the RPC client.
  cfg.cmd = function(dispatchers, config)
    local root = config.root_dir or env_root(0) or vim.fn.getcwd()
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
```

Notes:
- `vim.fs.root(from, ".envrc")` is the "scan up to the project root" step.
- `root_dir` as a callback that *conditionally* calls `on_dir` is the
  idiomatic native way to say "don't start this server here." This keeps
  `texlab` from spawning (and failing) in buffers with no devshell.
- `cmd` as a function returning `vim.lsp.rpc.start(...)` is the native hook for
  customizing how the process is launched. `config.root_dir` is populated by
  the `root_dir` callback before `cmd` runs — the same `config.root_dir` the
  existing `basedpyright` `before_init` already relies on.

### 5.2 How a project uses it

A project's `.nvim.lua` (sourced via `exrc` when nvim launches there) becomes a
one-liner plus settings — no PATH assumptions, no cwd tricks:

```lua
-- thesis/.nvim.lua
require("config.direnv_lsp").server("texlab", "texlab", {
  settings = {
    texlab = {
      build = {
        executable = "latexmk",
        args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
        onSave = true,
      },
      forwardSearch = {
        executable = "zathura",
        args = { "--synctex-forward", "%l:1:%f", "%p" },
      },
      chktex = { onOpenAndSave = true },
    },
  },
})
```

Because the registration no longer depends on the launch directory's PATH, it
works the same whether nvim is started in `thesis/` or at the monorepo root —
**provided the `.nvim.lua` that calls it is sourced**. See §6 for the
launch-directory caveat and how to handle the "launch at the monorepo root"
case.

### 5.3 Interaction with the existing pieces

- **`direnv.vim`**: keep it. It continues to populate the global env on
  `DirChanged` for terminals and `:!`. It is now *not* on the critical path for
  LSP correctness, so the "must `:cd` for the right env" papercut disappears
  for servers registered through the helper.
- **`basedpyright`**: unchanged. Its bespoke discovery already achieves the
  per-buffer goal for Python a different way. It can be migrated onto the
  helper later if we want a single mechanism, but there is no need to rush it.
- **Bundled servers** (`lua_ls`, `nil_ls`, `bashls`): unchanged. They come from
  the base home-manager env and are always on PATH, so they don't need direnv.

---

## 6. The launch-directory caveat

`exrc` sources `.nvim.lua` **once, from the directory nvim launches in**. A
nested `thesis/.nvim.lua` is therefore *not* read when nvim starts at the
monorepo root. The helper fixes environment resolution; it does not change when
the registration call runs. Two ways to handle the monorepo-root workflow:

1. **Root `.nvim.lua` registers project servers** for the subprojects you edit
   from the root. The helper makes this safe: `texlab` registered at the root
   still only starts in buffers that have an `.envrc` ancestor, and still runs
   against that buffer's env. (Downside: the root file lists each project's
   servers.)
2. **Register the project servers in the base config** if they are servers you
   always want available (e.g. always enable `texlab` for `tex` files). The
   helper's `root_dir` gate means an always-enabled `texlab` is inert until you
   open a `.tex` file under an `.envrc`. This is the cleanest for servers you
   use across many projects.

Recommendation: register genuinely cross-project servers (texlab, maybe
clangd/gopls/rust_analyzer) in the **base config** via the helper, and reserve
per-project `.nvim.lua` for project-specific *settings* overrides. This makes
the "open nvim at the root, everything adapts" experience work without each
repo re-declaring servers.

---

## 7. Implementation steps

1. Add `lua/config/direnv_lsp.lua` (the helper from §5.1).
2. Decide registration site per server (base config vs project `.nvim.lua`,
   per §6). For the thesis case, register `texlab` in the base config:
   - In `lua/plugins/lsp.lua`, after the existing `vim.lsp.enable({...})`, add
     `require("config.direnv_lsp").server("texlab", "texlab", { … })` (or a new
     `lua/plugins/latex.lua` that does it, to keep `lsp.lua` focused).
3. Ensure `direnv` is present (already in `packages.nix`). Recommend
   `programs.direnv` + `nix-direnv` in home-manager for cached `use flake`
   (already documented in README).
4. In each project: `.envrc` with `use flake`, `direnv allow` once. The
   project's `flake.nix` devshell must put the server binary on its PATH (for
   the thesis, `texlab` is already in `thesis/flake.nix`).
5. Trim the now-unnecessary cwd-follow logic from any project `.nvim.lua`
   (e.g. `~/10_diss/.nvim.lua`), leaving only LSP settings.
6. Update README (§10).

---

## 8. Validation

- **Single project, launched in it**: `cd thesis && nvim main.tex`. Expect
  `:checkhealth lsp` / `:LspInfo` to show a `texlab` client whose root is
  `thesis/` and that started without `texlab` on the *outer* PATH. Build on
  save produces `main.pdf`.
- **Monorepo root, mixed buffers**: `cd ~/10_diss && nvim`, open
  `thesis/main.tex` and a Python file from another subproject. Expect two
  independent clients, each resolving against its own `.envrc`. Confirm
  `:echo $PATH` (global) is unchanged by opening the tex buffer — i.e. the env
  isolation is real.
- **No-env buffer**: open a `.tex` file that has no `.envrc` ancestor; expect
  `texlab` to *not* start (root_dir gate), not to spawn-and-fail loudly.
- **Latency**: first `texlab` start pays a `direnv exec` load; with
  `nix-direnv` it should be tens of ms (cached). Note it in case cold loads
  feel slow.
- **`:LspRestart texlab`** picks up env changes after editing the flake +
  re-`direnv allow`.

---

## 9. Open questions / risks

- **`cmd`-as-function contract**: confirm `config.root_dir` is populated when
  `cmd` runs under the installed Neovim version. Evidence it is: the existing
  `basedpyright` `before_init` already reads `config.root_dir`. Fallback inside
  `cmd` (`env_root(0)`) guards the edge regardless.
- **`vim.lsp.rpc.start` signature**: `(_cmd, dispatchers, extra_spawn_params)`
  with `extra_spawn_params = { cwd, env, detached }`. Verify against the
  installed version; if the API differs, the alternative is `cmd = {binary}`
  plus a precomputed `cmd_env` from `direnv export json` (heavier, recomputed
  per root).
- **Per-root vs per-buffer**: clients are shared per `(name, root_dir)`. That's
  correct for direnv (one env per `.envrc` tree). If a single `.envrc` tree
  ever needed *different* envs per subdir, this model would need rethinking —
  not a real case here.
- **First-use trust**: project `.nvim.lua` still needs `:trust` (vim.secure)
  and `.envrc` still needs `direnv allow`. Unchanged, but worth stating in
  onboarding docs.
- **Non-LSP tools** (`:!`, `:terminal`, conform/none-ls formatters) still use
  the global env. Future work: a `direnv exec`-based wrapper for formatters
  (e.g. conform's `command`), and/or a `:DirenvExec` user command.

---

## 10. Docs to update

- README "Per-project tools via direnv": clarify that the *stock* re-export is
  cwd/`DirChanged`-based and document the new helper for LSP servers; correct
  the "open a file in another project" wording so it matches actual behavior
  (it's the helper, not direnv.vim, that makes opening a file Just Work).
- Add a short "Registering a project language server" example pointing at
  `config.direnv_lsp.server`.

---

## 11. Summary

Editor env is global, so chase the goal where it's achievable: launch each
language server through `direnv exec <nearest-.envrc-root> <binary>`, gated to
start only where a devshell exists. This delivers the requested per-buffer
behavior for the tooling that matters, with no global cwd movement and no
reliance on the global PATH, and it composes cleanly with the existing
`direnv.vim` (terminals/`:!`) and `basedpyright` (Python) paths.
