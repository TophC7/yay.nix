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
      }
    )
    // {
      # NixOS module for system-wide installation
      nixosModules.default =
        { pkgs, ... }:
        {
          environment.systemPackages = [ self.packages.${pkgs.system}.default ];
        };

      # Home-manager module
      homeManagerModules.default =
        { pkgs, ... }:
        {
          home.packages = [ self.packages.${pkgs.system}.default ];
        };
    };
}
