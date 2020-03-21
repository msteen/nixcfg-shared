{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.programs.command-not-found;
  commandNotFoundHandler = ''
    if [[ -x ${cfg.package}/bin/command-not-found ]]; then
      ${cfg.package}/bin/command-not-found "$@"
    else
      echo "$1: command not found" >&2
    fi
    return 127
  '';

in {
  disabledModules = [ "programs/command-not-found/command-not-found.nix" ];

  options.programs.command-not-found = with types; {
    enable = mkEnableOption "interactive shell to search for the Nix package that supplies the missing command." // {
      default = true;
    };

    package = mkOption {
      type = nullOr package;
      default = null;
      description = ''
        Defines which package should be used for the command-not-found handler of interactive shells.
      '';
    };
  };

  config = mkIf (cfg.enable && cfg.package != null) {
    programs.bash.interactiveShellInit = ''
      command_not_found_handle() {
        ${commandNotFoundHandler}
      }
    '';

    programs.zsh.interactiveShellInit = ''
      command_not_found_handler() {
        ${commandNotFoundHandler}
      }
    '';

    environment.systemPackages = [ cfg.package ];
  };
}
