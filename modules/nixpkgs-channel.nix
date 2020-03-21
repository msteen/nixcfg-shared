{ config, pkgs, ... }:

with import ../lib;

let
  cfg = config.nixpkgs;

in {
  options.nixpkgs.channel = with types; mkOption {
    type = nullOr str;
    default = null;
    description = ''
      Which nixpkgs channel to use.
    '';
  };

  config = mkMerge [
    {
      environment.etc."nixpkgs-channels/nixos-unstable".source = channels."nixos-unstable";
    }
    (mkIf (cfg.channel != null) {
      environment.etc."nixpkgs-channel".source = channels.${cfg.channel};
      environment.etc."nixpkgs-channels/${cfg.channel}".source = channels.${cfg.channel};

      environment.systemPackages = [
        (pkgs.writeBashBin "nixpkgs-channel-switch" ''
          store_path=$(nix eval --raw '(with import <nixpkgs> {}; cfglib.channels."'"$1"'")') &&
          sudo ln -sfT "$store_path" /etc/nixpkgs-channel
        '')
      ];

      nix.nixPath = mkAfter [ "nixpkgs=/etc/nixpkgs-channel" ];
    })
  ];
}
