{ config, lib, ... }:

with lib;

{
  config = mkIf config.services.zerotierone.enable {
    environment.sudoAliases = map (name: "zerotier-${name}") [ "cli" "idtool" "one" ];
  };
}
