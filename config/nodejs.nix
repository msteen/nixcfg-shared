{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.nodejs;

in {
  options.programs.nodejs = with types; {
    package = mkOption {
      type = package;
      default = pkgs.nodejs-latest;
      description = ''
        The NodeJS package to be installed on the system.
      '';
    };
  };

  config = {
    system.nixpkgsOverlayFiles = ./nodejs-overlay.nix;

    environment.systemPackages = [ cfg.package ];

    environment.anyShellInit = ''
      # Workaround for not being able to install packages globally.
      export PATH="/wheel/opt/npm/bin:$PATH"
    '';
  };
}
