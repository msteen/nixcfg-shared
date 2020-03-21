{ config, ... }:

with import ../lib;

let
  cfg = config.users;
  inherit (config.ids) uids gids;

  systemUsers = partition (name: hasAttr name uids && hasAttr name gids && uids.${name} < 399 && uids.${name} == gids.${name}) cfg.systemUsers;
  systemGroups = partition (name: hasAttr name gids && gids.${name} < 399 && !(hasAttr name uids)) cfg.systemGroups;

in {
  imports = [
    ../config/ids.nix
  ];

  options.users = {
    systemUsers = mkOption {
      default = [];
      type = with types; loeOf str;
      description = ''
        List of system user names.
      '';
    };

    systemGroups = mkOption {
      default = [];
      type = with types; loeOf str;
      description = ''
        List of system group names.
      '';
    };
  };

  config = mkIf (cfg.systemUsers != [] || cfg.systemGroups != []) {
    assertions = [
      {
        assertion = length systemUsers.wrong == 0;
        message = ''
          The following users are not valid system users, i.e. users that have an uid < 399
          and that have an equally named and numbered group:
          ${toString systemUsers.wrong}
        '';
      }
      {
        assertion = length systemGroups.wrong == 0;
        message = ''
          The following groups are not valid system groups, i.e. groups that have an uid < 399
          and that do not have an equally named user:
          ${toString systemGroups.wrong}
        '';
      }
    ];

    users = {
      users = listToAttrs (map (name: nameValuePair name {
        uid = uids.${name};
        inherit name;
        group = name;
      }) systemUsers.right);

      groups = listToAttrs (map (name: nameValuePair name {
        gid = gids.${name};
        inherit name;
      }) (systemUsers.right ++ systemGroups.right));
    };
  };
}
