{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.boot.initrd.network.ssh;

  sshdConfig = pkgs.writeText "sshd_config" ''
    Protocol 2
    Port ${toString cfg.port}
    AllowUsers root
    PasswordAuthentication no
    ChallengeResponseAuthentication no
    PrintlastLog no
    PrintMotd no

    ${concatStrings (map (name: ''
      HostKey /etc/ssh/${name}
    '') (attrNames cfg.hostKeys))}

    ${cfg.extraConfig}
  '';

in {
  disabledModules = [ "system/boot/initrd-ssh.nix" ];
  
  options.boot.initrd.network.ssh = with types; {
    enable = mkEnableOption "SSHD inside of the initial ramdisk";

    port = mkOption {
      type = int;
      default = head config.services.openssh.ports;
      description = ''
        The port to which SSHD inside of the initial ramdisk will listen to.
      '';
    };

    hostKeys = mkOption {
      type = attrsOf path;
      example = { "ssh_host_ed25519_key" = "/etc/ssh/ssh_host_ed25519_key"; };
      description = ''
        List of host keys for SSHD inside of the initial ramdisk.
      '';
    };

    shell = mkOption {
      type = str;
      default = "/bin/ash";
      description = ''
        The login shell for the root user inside of the initial ramdisk.
      '';
    };

    shellInit = mkOption {
      type = lines;
      default = "";
      description = ''
        The login shell initialization for the root user inside of the initial ramdisk.
      '';
    };

    authorizedKeys = mkOption {
      type = listOf str;
      description = ''
        List of authorized keys for the root user inside of the initial ramdisk.
      '';
    };

    extraConfig = mkOption {
      type = lines;
      default = "";
      description = ''
        Verbatim contents of <filename>sshd_config</filename> inside of the initial ramdisk.
      '';
    };

    moduliFile = mkOption {
      type = path;
      description = ''
        Path to <literal>moduli</literal> file to install in <filename>/etc/ssh/moduli</filename> inside of the initial ramdisk.
        If this option is unset, then the <literal>moduli</literal> file shipped with OpenSSH will be used.
      '';
    };
  };

  config = mkIf cfg.enable {
    boot.initrd = {
      extraUtilsCommands = ''
        copy_bin_and_libs ${pkgs.openssh}/bin/sshd
        cp -pv ${pkgs.glibc.out}/lib/libnss_files.so.* $out/lib

        mkdir -p $out/etc/ssh
        cp -pv ${cfg.moduliFile} $out/etc/ssh/moduli
      '';

      network = {
        enable = true;
        postCommands = ''
          extraUtils=$(dirname $(readlink /bin))

          echo '${cfg.shell}' > /etc/shells

          echo 'root:x:0:' > /etc/group
          echo 'nogroup:x:65534:' >> /etc/group

          echo 'root:x:0:0:root:/root:${cfg.shell}' > /etc/passwd
          echo 'sshd:x:1:65534:Privilege-separated SSH:/var/empty:/bin/nologin' >> /etc/passwd

          echo 'passwd: files' > /etc/nsswitch.conf

          # Make the sshd user's home folder.
          mkdir -p /var/empty

          cp $extraUtils/etc/ssh/moduli /etc/ssh/moduli

          ${optionalString (!config.boot.loader.supportsInitrdSecrets) (concatStrings (map (name: ''
            chmod 400 /etc/ssh/${name}
          '') (attrNames cfg.hostKeys)))}

          mkdir -p /root/.ssh
          ${concatStrings (map (key: ''
            echo ${escapeShellArg key} >> /root/.ssh/authorized_keys
          '') cfg.authorizedKeys)}

          ${optionalString (cfg.shellInit != "") ''
            cp ${pkgs.writeText "root-profile" cfg.shellInit} /root/.profile
          ''}

          /bin/sshd -f ${sshdConfig}
        '';
        ssh.moduliFile = mkDefault "${pkgs.openssh}/etc/ssh/moduli";
      };

      secrets = mapAttrs' (name: value: nameValuePair ("/etc/ssh/" + name) value) cfg.hostKeys;
    };

    networking.usePredictableInterfaceNames = false;
  };
}
