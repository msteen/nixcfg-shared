{ config, pkgs, ... }:

with import ../lib;

addProfileConfig {
  imports = [
    ./ids.nix
    ./system.nix
  ];

  # Useful for debugging purposes.
  options.inspect = mkOption {};

  config = mkMerge [
    {
      # If we only not want to be interactive when booting, this check is better:
      # "$(ps --no-headers --format comm --pid 1)" != init
      system.activationScripts.from-nixos-rebuild = stringAfter [ "specialfs" ] "export FROM_NIXOS_REBUILD=$(${pkgs.writeBash "from-nixos-rebuild.sh" ''
        PATH=${makeBinPath (with pkgs; [ psmisc gnugrep ])}
        (pstree -s $$ | grep -q 'nixos-rebuild') && echo true || echo false
      ''})";
    }
    ( # Add support for Grub secrets
    mkIf (config.boot.loader.grub.enable && config.boot.initrd.secrets != {}) {
      boot.loader = {
        supportsInitrdSecrets = mkForce true;
        grub.extraInitrd = "/boot/grub/secrets-initrd.gz";
        grub.extraPrepareConfig = ''
          ${config.system.build.initialRamdiskSecretAppender}/bin/append-initrd-secrets /boot/grub/secrets-initrd.gz
        '';
      };
    })
    { # Kernel
      boot.kernelPackages = mkDefault pkgs.linuxPackages_latest;

      # Disable the motherboard bell sound globally by disabling the kernel module responsible for it.
      boot.blacklistedKernelModules = [ "pcspkr" ];
    }
    { # Limits
      # We increase to inotify limits since the defaults are easily exceeded.
      boot.kernel.sysctl = {
        "fs.inotify.max_user_instances" = 4096;
        "fs.inotify.max_user_watches" = 524288;
      };

      # Be very generous with resource restrictions.
      # Should be lower than the value defined in /proc/sys/fs/file-max.
      # The domain * excludes root, so we need repeat it for root.
      security.pam.loginLimits =
        flip concatMap [ "*" "root" ] (domain:
        flip concatMap [ "nproc" "nofile" ] (item:
        flip       map [ "soft" "hard" ] (type:
          { inherit domain; inherit item; inherit type; value = "65536"; }
        )));
    }
    { # File system
      boot.supportedFilesystems = [
        "exfat"
        "ext"
        "ntfs"
        "vfat"
      ];

      # Prevent garbage accumulation.
      boot.cleanTmpDir = true;
    }
    { # Shells
      programs = {
        bash = {
          enableCompletion = true;
          promptInit = "source '${config.path ./shell/bash_prompt.sh}'";
        };
        zsh = {
          enable = true;
          autosuggestions.enable = true;
          promptInit = "source '${config.path ./shell/zsh_prompt.sh}'";
          shellInit = "zsh-newuser-install() { :; }"; # Prevent the Z shell new user prompt.
        };
      };
    }
    {
      # Define where curl, git, and openssl can find the default cacert bundle.
      environment.variables = genAttrs [
        "CURL_CA_BUNDLE"
        "GIT_SSL_CAINFO"
        "SSL_CERT_FILE"
      ] (_: "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt");

      # Rather than assume applications to use the correct default XDG base directories,
      # we just set them explicitly to their defaults.
      environment.extraInit = ''
        export XDG_CACHE_HOME=$HOME/.cache
        export XDG_CONFIG_HOME=$HOME/.config
        export XDG_DATA_HOME=$HOME/.local/share
      '';

      # Prevent the following warnings from happening on every build, we do not use `info` anyway:
      # install-info: warning: no info dir entry in `/nix/store/...-system-path/share/info/automake-history.info'
      # install-info: warning: no info dir entry in `/nix/store/...-system-path/share/info/time.info'
      # https://unix.stackexchange.com/questions/19451/difference-between-help-info-and-man-command
      documentation.info.enable = false;
    }
    {
      # Give the group also write access by default.
      environment.extraInit = ''
        umask 002
      '';
    }
    {
      time.timeZone = "Europe/Amsterdam";

      console.keyMap = mkDefault "us";

      i18n = {
        # Without forcing duplicates could occur, which breaks the checking done in the locale generation.
        supportedLocales = mkForce [
          "en_US.UTF-8/UTF-8"
          "en_US/ISO-8859-1"
          "nl_NL.UTF-8/UTF-8"
          "nl_NL/ISO-8859-1"
          "nl_NL@euro/ISO-8859-15"
        ];

        defaultLocale = "en_US.UTF-8";
      };
    }
    {
      environment.systemPackages = with pkgs; [
        automake
        bc
        bind # dig, nslookup
        binutils
        curl
        diffoscope
        dmidecode
        ethtool
        file
        git
        gnumake
        gnupg
        gptfdisk
        inetutils # hostname, ifconfig
        inotify-tools # inotifywait
        iproute # ip
        iputils # arping
        jq
        kexectools
        lshw
        lsof
        mkpasswd
        multipath-tools # kpartx
        ncdu
        nettools # netstat
        nix-diff
        nix-index
        nix-prefetch
        nmap
        openssh
        p7zip
        pciutils # lspci
        port-up
        psmisc # fuser
        python
        smartmontools
        sudo
        tcpdump
        telnet
        unrar
        unzip
        usbutils # lsusb
        valgrind # C memory leak checker
        wakelan
        wget
        zip
      ];

      nixpkgs.overlays = [
        (self: super: flip genAttrs (name: lowPrio super.${name}) [
          "iputils" # collisions with inetutils
        ] // flip genAttrs (name: hiPrio super.${name}) [
          "inetutils" # collisions with nettools
        ] // {
          bootloader-deps = super.callPackage ../pkgs/bootloader-deps { inherit config pkgs; };
        })
      ];

      environment.shellAliases = {
        # If the last character of the alias value is a space or tab character,
        # then the next command word following the alias is also checked for alias expansion.
        sudo = "sudo ";

        hibernate = "systemctl hibernate";
        shutdown = "poweroff";
        suspend = "systemctl suspend";

        grep = "grep --color=auto";
        la = "ls --all --human-readable -l";
        lsnix = "command nix-env --query --installed";
        lsport = "sudo netstat --numeric --tcp --udp --listening --program";
        lsuser = "cut -d: -f1 /etc/passwd";
        nano = "nano --nowrap";
        nix-env = "nix-env --file '<nixpkgs>'";
        nix-eval = "nix-instantiate --eval --expr";
        nix-gc = "sudo nix-collect-garbage --delete-old";
        wanip = "dig +short myip.opendns.com @resolver1.opendns.com";
      };

      environment.sudoAliases = [
        "dd"
        "fdisk"
        "gdisk"
        "journalctl"
        "kexec"
        "losetup"
        "modprobe"
        "mount"
        "nixops"
        "nixos-rebuild"
        "partx"
        "swapoff"
        "umount"
      ];

      security.sudo = {
        enable = mkDefault true;
        extraConfig = ''
          Defaults umask = 0000
          %wheel ALL=(ALL) NOPASSWD: ${pkgs.systemd}/bin/systemctl poweroff, ${pkgs.systemd}/bin/systemctl reboot
        '';
      };

      environment.anyShellInit = ''
        source '${config.path ./shell/any.sh}'
        source '${config.path ./shell/any_nux.sh}'
        bash-confirm() {
          bash "${config.path ./shell/bash_confirm.sh}" exit 1 1 "$@"
        }
      '';
      environment.interactiveShellInit = ''
        source '${config.path ./shell/interactive.sh}'
        source '${config.path ./shell/interactive_nux.sh}'
      '';
    }
    {
      users = {
        mutableUsers = false;
        defaultUserShell = "${pkgs.zsh}/bin/zsh";
      };

      nix = {
        buildCores = mkDefault config.nix.maxJobs;
        autoOptimiseStore = true;
        binaryCachePublicKeys = [ "hydra.nixos.org-1:CNHJZBh9K4tP3EKF6FkkgeVYsS3ohTl+oS0Qa8bezVs=" ];
        trustedBinaryCaches = [ "https://cache.nixos.org" ];
        trustedUsers = [ "root" "@wheel" ];
        useSandbox = true;
      };

      system.stateVersion = "18.03";
    }
    ( # Use predictable interface names we define ourselves that are available in the initial ramdisk as well.
    let
      macInterfaces = filterAttrs (name: interface: interface.macAddress != null) config.networking.interfaces;
      extraUdevRules = pkgs.writeTextDir "10-mac-network.rules" (concatStrings (mapAttrsToList (name: interface: ''
        ACTION=="add", SUBSYSTEM=="net", ATTR{address}=="${interface.macAddress}", NAME="${name}"
      '') macInterfaces));
    in mkIf (!config.networking.usePredictableInterfaceNames && macInterfaces != {}) {
      boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];
      boot.initrd.extraUdevRulesCommands = ''
        cp -v ${extraUdevRules}/*.rules $out/
      '';
    })
    {
      boot.loader = {
        timeout = mkDefault 3;

        grub.extraEntries = mkAfter ''
          menuentry "Reboot" {
            reboot
          }

          menuentry "Poweroff" {
            halt
          }
        '';
      };

      # Disable Linux magic system request key hacks.
      # https://www.kernel.org/doc/Documentation/sysrq.txt
      boot.kernel.sysctl."kernel.sysrq" = 0;

      # Causes too much noise.
      networking.firewall.logRefusedConnections = false;

      environment.variables."EDITOR" = "nano --nowrap";

      # Prevent the creation of *.pyc files.
      environment.variables."PYTHONDONTWRITEBYTECODE" = "1";

      # Change the disk space used for the journal to balance retention and speed.
      services.journald.extraConfig = ''
        RuntimeMaxUse=256M
        SystemMaxUse=256M
      '';
    }
  ];
}
