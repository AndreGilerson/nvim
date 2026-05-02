{
  description = "Exposes a home-manager module that installs the language servers and tools required by this nvim setup.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      homeManagerModules.default = import ./module.nix;

      # `nix profile install <this-flake>` or `nix shell <this-flake>` puts the
      # same package set as the home-manager module on PATH, without touching
      # the system config. Useful for testing locally before wiring the module
      # into the system flake.
      packages = forAllSystems (system:
        let pkgs = nixpkgs.legacyPackages.${system}; in {
          default = pkgs.buildEnv {
            name = "nvim-tooling";
            paths = import ./packages.nix pkgs;
          };
        });
    };
}
