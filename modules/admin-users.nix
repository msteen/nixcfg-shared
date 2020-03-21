{ config, ... }:

with import ../lib;

let
  cfg = config.users;

in {
  options.users.adminUsers = with types; mkOption {
    default = [];
    type = loeOf str;
    description = ''
      List of admin user names.
    '';
  };

  config = mkIf (cfg.adminUsers != []) {
    users.users = genAttrs cfg.adminUsers (const { extraGroups = [ "wheel" ]; });
    nix.trustedUsers = cfg.adminUsers;
  };
}
