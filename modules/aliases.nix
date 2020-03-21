{ config, lib, ... }:

with lib;

let
  cfg = config.environment;

in {
  options.environment = with types; {
    aliases = mkOption {
      default = {};
      type = attrsOf str;
      description = ''
        An attribute set that maps aliases to commands.
      '';
    };

    sudoAliases = mkOption {
      default = [];
      type = listOf str;
      description = ''
        A list of executables that should always be prepended with sudo.
      '';
    };
  };

  config = mkIf (cfg.aliases != {} || cfg.sudoAliases != []) {
    environment.shellAliases = genAttrs cfg.sudoAliases (alias: "sudo ${alias}")
      // mapAttrs (name: replaceStrings ["'"] ["'\\''"]) cfg.aliases;
  };
}
