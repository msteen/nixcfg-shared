{ config, pkgs, ... }:

with import ../lib;

let
  cfg = config.system;

in {
  options = with types; {
    system = {
      nixpkgsConfig = mkOption {
        type = path;
        default = ./nixpkgs.nix;
        description = ''
          Path of the Nixpkgs configuration file.
        '';
      };

      nixosConfig = mkOption {
        type = nullOr path;
        default = null;
        description = ''
          Path of the NixOS configuration file.
        '';
      };
    };
  };

  config = mkMerge [
    {
      # Need to set both `variables` and `sessionVariables`, because session variables are also assigned to be regular variables,
      # but when copying over attributes, `mkForce` is not copied over.
      environment.variables.NIXPKGS_CONFIG = mkForce (toString cfg.nixpkgsConfig);
      environment.sessionVariables.NIXPKGS_CONFIG = toString cfg.nixpkgsConfig;
      environment.etc."nix/nixpkgs-config.nix".source = toString cfg.nixpkgsConfig;
      nixpkgs.config = import cfg.nixpkgsConfig;
    }
    (mkIf (cfg.nixosConfig != null) {
      environment.etc."nixos/configuration.nix".source = toString cfg.nixosConfig;
      nix.nixPath = [ "nixos-config=${toString cfg.nixosConfig}" ];
    })
  ];
}
