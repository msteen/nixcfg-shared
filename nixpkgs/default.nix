with import ./lib;

{ config ? null, overlays ? null }@args:

(import (channels.${lastStableChannel} + "/nixos") (optionalAttrs (args != {}) {
  configuration = {
    imports = [
      (maybeEnv "NIXOS_CONFIG" <nixos-config>)
      { nixpkgs = args; }
    ];
  };
})).pkgs
