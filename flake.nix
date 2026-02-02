{
  description = "A convenient wrapper around Nix commands with fish completions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        lib = pkgs.lib;
      in
      {
        packages = rec {
          default = yay;
          yay = import ./pkgs/default.nix { inherit pkgs lib; };
        };

        # Helper function to build yay with custom config
        lib.mkYay =
          {
            buildHost ? null,
            flakePath ? null,
          }:
          import ./pkgs/default.nix {
            inherit
              pkgs
              lib
              buildHost
              flakePath
              ;
          };
      }
    )
    // {
      # NixOS module for system-wide installation
      nixosModules.default = import ./modules/default.nix self;

      # Home Manager module
      homeManagerModules.default = import ./modules/home.nix self;
    };
}
