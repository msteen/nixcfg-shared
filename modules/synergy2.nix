# FIXME: Should not be run as a systemd service.
# https://superuser.com/questions/759759/writing-a-service-that-depends-on-xorg/759891
{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.synergy2;

in {
  options.services.synergy2 = {
    enable = mkEnableOption "Synergy 2";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ synergy2 ];

    systemd.services.synergy2 = {
      description = "Synergy 2, a keyboard and mouse sharing solution";
      after = [ "network.target" ];
      serviceConfig = {
        Restart = "always";
        RestartSec = 0;
        SyslogLevel = "err";
        Environment = "DISPLAY=:0.0";
        ExecStart = "${pkgs.synergy2}/bin/synergy-service";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
