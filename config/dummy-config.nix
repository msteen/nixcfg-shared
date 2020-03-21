{ pkgs, ... }:

let
  dummyConfig = pkgs.writeText "dummy-configuration.nix" ''
    throw "Hey dummy, you should use NixOps to manage this machine!"
  '';

in {
  environment.variables.NIXOS_CONFIG = dummyConfig;
  nix.nixPath = [ "nixos-config=${dummyConfig}" ];
}
