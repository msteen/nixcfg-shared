{ config, pkgs, ... }:

with import ../lib;

let
  cfg = config.nixpkgs;

in {
  options.nixpkgs = with types; {
    channel = mkOption {
      type = nullOr str;
      default = null;
      description = ''
        Which Nixpkgs channel to use.
      '';
    };

    channelRev = mkOption {
      type = str;
      description = ''
        The revision of the Nixpkgs channel being used.
      '';
    };
  };

  config = mkMerge [
    {
      environment.etc."nixpkgs/channels".text = concatStrings (mapAttrsToList (channel: meta: ''
        ${meta.rev} ${channel}
      '') channelsMeta);

      nix.nixPath = mkAfter [ "nixpkgs=${toString ../nixpkgs}" ];
    }
    (mkIf (cfg.channel != null) {
      nixpkgs.pkgs = import channels.${cfg.channel} {
        inherit (config.nixpkgs) config overlays localSystem crossSystem;
      };

      nixpkgs.channelRev = channelsMeta.${cfg.channel}.rev;
    })
  ];
}
