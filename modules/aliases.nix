{ config, lib, ... }:

with lib;

let
  cfg = config.environment;

in {
  options.environment = with types; {
    sudoAliases = mkOption {
      default = [];
      type = listOf str;
      description = ''
        A list of executables that should always be prepended with sudo.
      '';
    };
  };

  config = mkIf (cfg.sudoAliases != []) {
    environment.shellAliases = genAttrs cfg.sudoAliases (alias: "sudo ${alias}");
  };
}
