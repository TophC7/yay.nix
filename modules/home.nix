# Home Manager module for yay
#
# Usage in consuming flake:
#   imports = [ inputs.yay.homeManagerModules.default ];
#   programs.yay = {
#     enable = true;
#     buildHost = "nimbus";
#     flakePath = "/repo/Nix/dot.nix";
#   };
#
yay:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.yay;
in
{
  options.programs.yay = {
    enable = lib.mkEnableOption "yay - convenient Nix command wrapper";

    buildHost = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default build host for remote builds (e.g., 'nimbus')";
      example = "nimbus";
    };

    flakePath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Default path to the flake configuration";
      example = "/repo/Nix/dot.nix";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      (yay.lib.${pkgs.system}.mkYay {
        inherit (cfg) buildHost flakePath;
      })
    ];
  };
}
