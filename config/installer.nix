{ lib, pkgs, ... }:

with lib;

{
  # Prevent errors due to aliases that use sudo, while sudo has not been configured.
  security.sudo = {
    enable = mkForce true;
    extraConfig = ''
      root ALL=(ALL:ALL) SETENV: ALL
    '';
  };

  # Allow SSH access to the installer.
  services.openssh.permitRootLogin = mkForce "yes";
  systemd.services.sshd.wantedBy = mkForce [ "multi-user.target" ];
  users.users.root.extraGroups = [ "sshusers" ];

  # Command line web browser, useful for i.e. free wifi access that requires you to accept terms.
  environment.systemPackages = with pkgs; [ links2 ];
}
