{ config, pkgs, ... }:

with import ../lib;

let
  ciphersAndMACs = ''
    Ciphers ${commaLines ''
      chacha20-poly1305@openssh.com
      aes256-gcm@openssh.com
      aes128-gcm@openssh.com
      aes256-ctr
      aes192-ctr
      aes128-ctr
    ''}
    MACs ${commaLines ''
      hmac-sha2-512-etm@openssh.com
      hmac-sha2-256-etm@openssh.com
      umac-128-etm@openssh.com
      hmac-sha2-512
      hmac-sha2-256
      umac-128@openssh.com
    ''}
  '';

in {
  imports = [
    ../modules/system-users.nix
  ];

  environment.aliases = {
    "unsafe-ssh" = "ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null";
  };

  programs.ssh = {
    # http://unix.stackexchange.com/questions/83986/tell-ssh-to-use-a-graphical-prompt-for-key-passphrase
    askPassword = "";

    extraConfig = ''
      Host *
        ServerAliveInterval 300
        ServerAliveCountMax 2

        EscapeChar none

        ChallengeResponseAuthentication no
        KbdInteractiveAuthentication no
        PasswordAuthentication no

        PubkeyAuthentication yes
        KexAlgorithms ${commaLines ''
          curve25519-sha256@libssh.org
          diffie-hellman-group-exchange-sha256
        ''}
        HostKeyAlgorithms ${commaLines ''
          ssh-ed25519-cert-v01@openssh.com
          ssh-rsa-cert-v01@openssh.com
          ssh-ed25519
          ssh-rsa
        ''}
        ${ciphersAndMACs}
    '';

    # We do not use passwords on our private keys, making this just a security risk.
    startAgent = false;
  };

  # https://stribika.github.io/2015/01/04/secure-secure-shell.html
  services.openssh = {
    enable = true;
    ports = [ 2200 ];
    permitRootLogin = "no";
    passwordAuthentication = false;
    challengeResponseAuthentication = false; # default value for KbdInteractiveAuthentication
    extraConfig = mkAfter ''
      AllowGroups sshusers
      ${ciphersAndMACs}
      PrintlastLog no
    '';
  };

  users.systemGroups = "sshusers";
}
