{ config, ... }:

with import ../lib;

let
  stateDir = "/var/lib/nixos-files";

  cfg = config.system;

in {
  options.system.nixosFilesKeys = with types; mkOption {
    type = loeOf str;
    default = [];
  };

  config = mkIf (cfg.nixosFilesKeys != []) {
    system.activationScripts.clean-nixos-files = ''
      if [[ -d '${stateDir}' ]]; then
        find '${stateDir}' -mindepth 1 -maxdepth 1 ${toString (map (path: "\\! -name '${escapeShellArg path}'") cfg.nixosFilesKeys)} -exec rm -r {} +
      fi
    '';
  };
}
