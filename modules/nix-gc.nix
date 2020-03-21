{ config, pkgs, ... }:

with import ../lib;

let
  cfg = config.nix.gc;

in {
  options.nix.gc = with types; {
    roots = mkOption {
      type = loeOf package;
      default = [];
      description = ''
        Packages that would otherwise not have a root.
      '';
    };
  };

  config = mkIf (cfg.roots != []) {
    environment.etc."nix/roots".source = pkgs.runCommand "roots" { } ''
      echo '${concatStringsSep "\n" cfg.roots}' > $out
    '';
    # environment.systemPackages = [
    #   (pkgs.runCommand "roots" { } ''
    #     echo '${concatStringsSep ":" cfg.roots}' > $out
    #   '')
    # ];
  };
}
