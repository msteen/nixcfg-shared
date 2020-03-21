{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.initrd.udev;

in {
  options = {
    boot.initrd.udev = with types; {
      extraRules = mkOption {
        type = lines;
        default = "";
        description = ''
          Extra udev rules for in the initial ramdisk.
        '';
      };
    };
  };

  config = mkIf (cfg.extraRules != "") {
    boot.initrd = {
      extraUdevRulesCommands = let extraUdevRules = pkgs.writeTextDir "99-local.rules" cfg.extraRules; in ''
        cp -v ${extraUdevRules}/*.rules $out/
      '';
    };
  };
}
