with import ../lib;

{ configuration ? maybeEnv "NIXOS_CONFIG" <nixos-config> }:

let
  toNixos = pkgsPath: import (pkgsPath + "/nixos") {
    inherit configuration;
    system = "x86_64-linux";
  };
  lastStableNixos = toNixos channels.${lastStableChannel};
in if lastStableNixos.config.nixpkgs.channel != lastStableChannel
then toNixos lastStableNixos.pkgs.path
else lastStableNixos
