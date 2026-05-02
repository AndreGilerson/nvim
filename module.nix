{ pkgs, lib, ... }: {
  # Tools required by this nvim config (language servers, formatters, etc.).
  # Added to the user's home-manager packages so a `nixos-rebuild switch`
  # ensures everything nvim expects is on PATH.
  home.packages = with pkgs; [
    # Language servers
    lua-language-server     # Lua (editing this nvim config)
    nil                     # Nix (editing flake.nix / module.nix)
    bash-language-server    # Bash / shell scripts
  ];
}
