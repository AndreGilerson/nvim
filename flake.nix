{
  description = "Exposes a home-manager module that installs the language servers and tools required by this nvim setup.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }: {
    homeManagerModules.default = import ./module.nix;
  };
}
