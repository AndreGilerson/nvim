# Disclaimer

This is a repo for my personal nvim config, that is open for easy cloning in my nix config. No guarantees, on anything here actually working, so use at your own risk. I am building my personal config instead of using an established nvim distro such as lunar for the fun of it, and to learn the inner workings better. I highly recommend using an established nvim distro for everybody else. 

# My Neovim base configuration

A deliberately small, general-purpose Neovim setup that provides the parts that every project needs: editor settings, a file tree, fuzzy finding, completion, treesitter, and a handful of language servers for editing the config itself. Anything project-specific (extra language servers, formatters, per-project options) is layered on per project rather than baked in here.

Requires Neovim ≥ 0.12. Plugins are managed by [lazy.nvim](https://github.com/folke/lazy.nvim), which bootstraps itself on first launch.

## Layout

```
init.lua                 entry point: options → lazy → keymaps
lua/config/
  options.lua            editor options (tabs, clipboard, exrc, …)
  writing.lua            spell setup, Vale ruleset path, :DictSync wordlist
  lazy.lua               lazy.nvim bootstrap + plugin import
  keymaps.lua            global keymaps
lua/plugins/             one file per plugin (auto-imported by lazy)
vale/.vale.ini           Vale style ruleset (voice/tone); `vale sync` fills vale/styles/
flake.nix                exposes the home-manager module + a `nix run`-able package
module.nix               home-manager module: installs the tools below
packages.nix             the actual tool list (language servers, build deps, direnv)
```

## Installation (NixOS / home-manager)

This repo is two things at once: the Neovim config and a flake that installs the external tools the config expects (language servers, a C compiler for treesitter, `direnv`).

1. **Tools** — import the home-manager module so the tooling lands on `PATH`:

   ```nix
   # flake.nix inputs
   nvim-config.url = "path:/home/andre/82_nvim"; # or your git remote

   # home-manager modules
   imports = [ nvim-config.homeManagerModules.default ];
   ```

   The package set lives in [`packages.nix`](./packages.nix); a `nixos-rebuild switch` (or `home-manager switch`) makes it available. You can also try it ad-hoc with `nix run` / `nix shell` against this flake.

2. **Config** — point Neovim at this repo's config (e.g. via `xdg.configFile."nvim".source` in home-manager, or a plain checkout in `~/.config/nvim`).

## What's included

| Area          | Plugin                          |
|---------------|---------------------------------|
| Plugin manager| `folke/lazy.nvim`               |
| Colorscheme   | `rebelot/kanagawa.nvim`         |
| File tree     | `nvim-tree/nvim-tree.lua`       |
| Fuzzy find    | `nvim-telescope/telescope.nvim` |
| Completion    | `hrsh7th/nvim-cmp` (+ `cmp-dictionary` for prose prediction) |
| Syntax        | `nvim-treesitter/nvim-treesitter` |
| LSP           | `neovim/nvim-lspconfig` (native `vim.lsp.config` API) |
| Writing       | `ltex-ls-plus`, `harper`, `vale` (see below) |
| Terminal      | `akinsho/toggleterm.nvim`       |
| Keymap hints  | `folke/which-key.nvim`          |
| Markdown      | `OXY2DEV/markview.nvim`         |
| Devshell env  | `direnv/direnv.vim`             |

Bundled language servers (for editing this config and basic scripting): `lua_ls`, `nil` (Nix), `bashls`, and `basedpyright` (Python). LSP is configured through Neovim's native `vim.lsp.config()` / `vim.lsp.enable()` API — `nvim-lspconfig` is kept only for the per-server defaults it ships.

---

## Writing: spell, grammar & style

A writing stack for prose (LaTeX, Markdown, git commits, …) and code comments.

| Piece | Role |
|-------|------|
| **ltex-ls-plus** (LanguageTool) | Grammar + spelling for prose/markup (LaTeX, Markdown, reST, …) |
| **harper** (`harper-ls`) | Grammar in *code comments* only (scoped to programming filetypes) |
| **vale** (`vale-ls`) | Style / voice / tone — passive voice, wordiness, clichés (Grammarly-like) |
| built-in `spell` | Squiggles + `z=` corrections in prose; `zg` learns words |
| **cmp-dictionary** | Phone-keyboard-style prefix completion from a real wordlist (+ learned words) |

All three servers surface their fixes as **LSP code actions** — put the cursor
on a flagged word and hit `<leader>ca` to pick "Did you mean…", add-to-dictionary,
or disable-rule.

**Spell keys** (prose buffers, where `spell` is auto-enabled): `z=` list
corrections · `zg` mark a word *good* (learns it) · `zw` mark *wrong*. Words you
`zg` are saved to a personal spellfile (`stdpath("data")/spell/en.utf-8.add`) and
immediately become completion candidates.

### One-time setup

The binaries come from [`packages.nix`](./packages.nix) (a `home-manager switch`
installs `harper`, `ltex-ls-plus`, `vale`, `vale-ls`, `aspell`). Then:

1. **Vale styles** — download the style packages named in
   [`vale/.vale.ini`](./vale/.vale.ini) into `StylesPath`. From inside Neovim:

   ```vim
   :ValeSync        " runs `vale sync` with the right config, then reloads vale_ls
   ```

   or from a shell: `cd ~/.config/nvim/vale && vale sync`. Skipping this makes
   `vale_ls` fail with `E100 … style 'write-good' does not exist on StylesPath`.
   (One network call; offline afterward. `vale/styles/` is gitignored.) To add a
   house voice, append `Microsoft` or `Google` to both `Packages` and
   `BasedOnStyles` in `.vale.ini`, then re-sync.

2. **Completion wordlist** — build the predictive dictionary from aspell, once:

   ```vim
   :DictSync        " writes stdpath("data")/dict/en.dict, hot-loads it
   ```

### n-gram data (context-aware spelling)

LanguageTool catches *real-word* errors (their/there, its/it's) using an offline
[n-gram data set](https://dev.languagetool.org/finding-errors-using-n-gram-data).
The home-manager module downloads the English data by default (a fixed-output
`fetchzip`, ~8 GB) and symlinks it to `~/.local/share/ltex/ngrams/en/`, which
[`lsp.lua`](./lua/plugins/lsp.lua) auto-detects and passes to `ltex_plus` as its
`languageModel` — no manual step.

Because it is a large download, it can be turned off in your home-manager config:

```nix
nvimConfig.ltexNgrams.enable = false;   # ltex still runs, without n-gram rules
```

The version and hash are pinned from the maintained
[`Janik-Haag/nix-languagetool-ngram`](https://github.com/Janik-Haag/nix-languagetool-ngram)
project.

---

## Extending per project

The whole point of this setup: open `nvim` anywhere and let it adapt to the project, without starting it from inside a devshell or maintaining a forked config. There are two independent mechanisms.

### Per-project tools via direnv

When a project needs its own binaries on `PATH`: a language server not bundled here (`rust-analyzer`, `gopls`, `clangd`, …), a specific Python interpreter, formatters, etc. the idiomatic Nix answer is [direnv](https://direnv.net/) driving the project's `flake.nix` devshell.

One-time setup (in home-manager):

```nix
programs.direnv = {
  enable = true;
  nix-direnv.enable = true;   # fast, cached `use flake`
};
```

This enables the shell hook and the `use flake` helper. The `direnv` binary itself is already provided by this repo's package set, and the [`direnv.vim`](./lua/plugins/direnv.lua) plugin is included so the environment is pulled into a running nvim too.

Per project: add an `.envrc` at the project root:

```bash
# .envrc
use flake
```

then `direnv allow` once. Now:

- A shell that `cd`s into the project already has the devshell on `PATH`, so `nvim` launched from there sees the project's tools immediately.
- `direnv.vim` re-exports the environment into the running nvim on directory change (`:cd`/`:tcd`, which fire `DirChanged`). Merely opening a file in another subproject does not move the cwd, so it does not re-export. For that, register the server through the per-LSP helper below.

> **Note:** the editor environment is process-global, so `direnv.vim` is "last directory wins" and a server that's already running won't retroactively get a new environment (run `:LspRestart` after a change). It remains the right tool for cwd-based consumers — `:terminal`, `:!`, and the like.

#### Per-language-server environments (concurrent multi-direnv)

To run a language server against its buffer's nearest `.envrc` (independently per buffer, with no global cwd movement and without the binary being on nvim's own `PATH`) register it through [`config.direnv_lsp`](./lua/config/direnv_lsp.lua). It starts the server via `direnv exec <nearest-.envrc-root> <binary>`, so files under different `.envrc`s get separate clients with separate environments at the same time:

```lua
-- e.g. in a project's .nvim.lua (or the base config for a cross-project server)
require("config.direnv_lsp").server("texlab", "texlab", {
  settings = { texlab = { build = { onSave = true } } },
})
```

The server only starts in buffers that have an `.envrc` ancestor (so an always-registered server stays inert elsewhere), and reuses one client per project tree. `direnv exec` execve-replaces itself with the server, so `:LspRestart` and quitting clean up without leaving orphaned processes. If the `.envrc` exists but hasn't been `direnv allow`ed, the server won't start and `:LspLog` shows `direnv: error … is blocked` — run `direnv allow` to fix it.

### Per-project configuration via `exrc`

When a project needs its own Neovim settings or LSP registration rather than (or in addition to) extra binaries. Neovim's built-in `exrc` (enabled in [`options.lua`](./lua/config/options.lua)) sources a `.nvim.lua` from the directory nvim starts in.

Create `.nvim.lua` at the project root, for example to register a server whose binary direnv puts on `PATH`:

```lua
-- .nvim.lua — project-local, layered on top of the base config
vim.lsp.config("rust_analyzer", {
  settings = {
    ["rust-analyzer"] = { check = { command = "clippy" } },
  },
})
vim.lsp.enable("rust_analyzer")

-- project-local options are fine here too
vim.opt_local.shiftwidth = 2
```

The first time nvim encounters a given `.nvim.lua` it asks whether to trust it (via `vim.secure`) and remembers the file's hash, so an untrusted file in someone else's repo can't silently run code. Re-trust after edits with`:trust`.

**Scope & limits:** `exrc` runs once, at startup, from the launch directory. It's ideal for settings and LSP registration, not for adding brand-new lazy.nvim plugins at runtime. 

---

### Python interpreter / basedpyright

The Python setup auto-discovers a venv (`.venv`, `venv`, `.direnv/python*`) walking up from the file, falling back to `PATH`. Two commands help when it guesses wrong:

- `:PythonSelect` — pick a venv, a `flake.nix` devshell, the system python, or a custom path; optionally persists the choice to `pyrightconfig.json`.
- `:PythonDebug` — dump what the discovery logic and the running basedpyright client actually resolved, into a scratch buffer.
