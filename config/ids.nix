let
  systemIds = {
    emby = 242; # removed 2019-05-01 from ids.nix
    www-data = 350;
    portforward = 351;
    bitwarden_rs = 352;
  };

in {
  ids.uids = systemIds;
  ids.gids = systemIds // {
    sshusers = 380;
  };
}
