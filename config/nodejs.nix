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
    nixpkgs.overlays = singleton (self: super: {
      nodejs-latest = super.nodejs-12_x;
      nodePackages-latest = super.nodePackages_12_x;
    });

    environment.systemPackages = [ cfg.package ];

    environment.anyShellInit = ''
      # Workaround for not being able to install packages globally.
      export PATH="/wheel/opt/npm/bin:$PATH"
    '';
  };
}
