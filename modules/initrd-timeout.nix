{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.initrd;

in {
  options.boot.initrd.timeout = with types; mkOption {
    type = int;
    default = 0;
    description = ''
      How many seconds should have passed before the machine is powered off (0 means disabled).
    '';
  };

  config = mkIf (cfg.timeout > 0) {
    boot.initrd = {
      extraUtilsCommands = ''
        cp -Lpnv ${pkgs.sysrq-scripts}/bin/* $out/bin/
      '';

      network.postCommands = ''
      (
        echo 'timeout> timer started'
        sleep ${toString cfg.timeout}
        echo 'timeout> timer finished'
        sysrq-poweroff
      ) &
      '';
    };
  };
}
