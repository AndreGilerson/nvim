pkgs: with pkgs; [
  # Language servers
  lua-language-server     # Lua (editing this nvim config)
  nil                     # Nix (editing flake.nix / module.nix)
  bash-language-server    # Bash / shell scripts
  basedpyright            # Python (fork of pyright with better venv handling)

  # Build deps for nvim-treesitter (compiles parsers from C at runtime)
  gcc
  tree-sitter

  # Writing stack: grammar / spell / style checkers, wired as language servers
  # in lua/plugins/prose.lua. See README.md → "Writing: spell, grammar & style".
  harper         # harper-ls: fast grammar checker for code comments
  ltex-ls-plus   # LanguageTool LSP: grammar/spell for LaTeX, Markdown, prose
  vale           # prose style linter (voice/tone), driven by vale-ls
  vale-ls        # LSP frontend for vale
  aspell         # used by :DictSync to build the completion wordlist
  aspellDicts.en # English word data for aspell

  # Per-project devshell integration (direnv.vim plugin). This only provides
  # the `direnv` binary; for fast `use flake` caching and the shell hook,
  # enable `programs.direnv` (with `nix-direnv`) in your home-manager config —
  # see README.md → "Per-project tools via direnv".
  direnv
]
