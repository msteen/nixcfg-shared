{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.samba-builtin;

  sambaToString = x: if builtins.typeOf x == "bool" then if x then "yes" else "no" else toString x;

  shareConfig = name: let share = getAttr name cfg.shares; in ''
    [${name}]
    ${concatStrings (map (key: ''
      ${"  "}${key} = ${sambaToString (getAttr key share)}
    '') (attrNames share))}
  '';

  configFile = if cfg.configFile != null then cfg.configFile else pkgs.writeText "smb.conf" ''
    [global]
      nsupdate command = ${pkgs.bind}/bin/nsupdate -g
      passwd program = /run/wrappers/bin/passwd %u
      rndc command = ${pkgs.bind}/bin/rndc
      template shell = ${pkgs.coreutils}/bin/false

    ${cfg.extraConfig}
    ${concatStringsSep "\n" (map shareConfig (attrNames cfg.shares))}
  '';

in {
  # This following cannot be used, because the existing samba module is too coupled with other modules.
  # disabledModules = [ "services/network-filesystems/samba.nix" ];

  options.services.samba-builtin = with types; {
    enable = mkEnableOption "Samba server";

    package = mkOption {
      type = package;
      default = pkgs.samba;
      defaultText = "pkgs.samba";
      example = literalExample "pkgs.samba3";
      description = ''
        Defines which package should be used for the samba server.
      '';
    };

    configFile = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        The Samba server config file <literal>smb.conf</literal>.
        If null (default), it will be generated based on <literal>extraConfig</literal>
        and <literal>shares</literal>.
      '';
    };

    extraConfig = mkOption {
      type = lines;
      default = "";
      description = ''
        Additional global section and extra section lines go in here.
      '';
      example = ''
        guest account = nobody
        map to guest = bad user
      '';
    };

    shares = mkOption {
      type = attrsOf (attrsOf unspecified);
      default = {};
      description = ''
        A set describing shared resources. See <command>man smb.conf</command> for options.
      '';
      example = {
        public = {
          "path" = "/srv/public";
          "read only" = true;
          "browseable" = "yes";
          "guest ok" = "yes";
          "comment" = "Public samba share.";
        };
      };
    };
  };

  config = mkIf cfg.enable {
    environment.etc."samba-builtin/smb.conf".source = configFile;

    environment.systemPackages = [ cfg.package ];

    systemd.services.samba = {
      description = "Samba Active Directory Domain Controller";
      after = [ "network.target" ];
      environment.LOCALE_ARCHIVE = "/run/current-system/sw/lib/locale/locale-archive";
      serviceConfig = {
        Type = "forking";
        ExecStart = "${cfg.package}/bin/samba -D";
        LimitNOFILE = 16384;
        PIDFile = "/run/samba/samba.pid";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
      };
      unitConfig.RequiresMountsFor = "/var/lib/samba";
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];
    };

    systemd.tmpfiles.rules = [
      "d /var/cache/samba - - - - -"
      "d /var/lib/samba/private - - - - -"
      "d /var/lock/samba - - - - -"
      "d /var/log/samba - - - - -"
      "d /run/samba - - - - -"
    ];
  };
}
