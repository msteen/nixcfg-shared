{ config, pkgs, ... }:

with import ../lib;

let
  cfg = config.users;
  realUserNames = map ({ name, ... }: name) cfg.realUsers;

  realUserModule = { name, ... }: with types; {
    options = {
      id = mkOption {
        type = int;
        description = ''
          The user and group id of this real user (i.e. person), should be >= 1000.
        '';
      };

      name = mkOption {
        type = str;
        description = ''
          The user and group name of this real user (i.e. person).
        '';
      };

      fullName = mkOption {
        type = str;
        description = ''
          The full name of this real user (i.e. person).
        '';
      };

      passFile = mkOption {
        type = path;
        description = ''
          The password file containing the hashed password of this real user (i.e. person).
        '';
      };
    };
  };

in {
  options.users = with types; {
    realUsers = mkOption {
      type = loeOf (submodule realUserModule);
      default = [];
      description = ''
        List of real users (i.e. persons).
      '';
    };

    realUserNames = mkOption {
      type = listOf str;
      default = realUserNames;
      description = ''
        List of real user (i.e. person) names.
      '';
    };

    rootUserNames = mkOption {
      type = listOf str;
      default = [ "root" ] ++ realUserNames;
      description = ''
        List of root and real user (i.e. person) names.
      '';
    };
  };

  config = mkIf (cfg.realUsers != []) {
    users = {
      groups = listToAttrs (map ({ id, name, ... }: nameValuePair name {
        gid = id;
        inherit name;
      }) cfg.realUsers);

      users = listToAttrs (map ({ id, name, fullName, passFile, ... }: nameValuePair name {
        uid = id;
        inherit name;
        description = fullName;
        group = name;
        extraGroups = [
          "audio"
          "sshusers"
          "users"
          "video"
        ] ++ optional config.networking.networkmanager.enable "networkmanager";
        hashedPassword = fileContents passFile;
        home = "/home/${name}";
        useDefaultShell = true;
      }) cfg.realUsers);
    };
  };
}
