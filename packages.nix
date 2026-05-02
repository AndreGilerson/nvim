pkgs: with pkgs; [
  # Language servers
  lua-language-server     # Lua (editing this nvim config)
  nil                     # Nix (editing flake.nix / module.nix)
  bash-language-server    # Bash / shell scripts
  basedpyright            # Python (fork of pyright with better venv handling)

  # Build deps for nvim-treesitter (compiles parsers from C at runtime)
  gcc
]
