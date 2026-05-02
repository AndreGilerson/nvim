{ pkgs, lib, ... }: {
  # Tools required by this nvim config (language servers, formatters, etc.).
  # Added to the user's home-manager packages so a `nixos-rebuild switch`
  # ensures everything nvim expects is on PATH.
  home.packages = import ./packages.nix pkgs;
}
