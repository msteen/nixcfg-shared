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

      nixpkgsOverlayFiles = mkOption {
        type = loeOf path;
        default = [];
        description = ''
          List of Nixpkgs overlay file paths.
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
    {
      nix.nixPath = [ "nixpkgs-overlays=/etc/nixpkgs/overlays" ];
      nixpkgs.overlays = map import cfg.nixpkgsOverlayFiles;
      environment.etc = listToAttrs (imap1 (i: overlayFile:
        # If we do not call `toString` on `overlayFile` the relative paths will break.
        nameValuePair "nixpkgs/overlays/overlay${toString i}.nix" { source = toString overlayFile; }
      ) cfg.nixpkgsOverlayFiles);
    }
    (mkIf (cfg.nixosConfig != null) {
      environment.sessionVariables.NIXOS_CONFIG = toString cfg.nixosConfig;
      environment.etc."nixos/configuration.nix".source = toString cfg.nixosConfig;
      nix.nixPath = [ "nixos-config=${toString cfg.nixosConfig}" ];
    })
  ];
}
