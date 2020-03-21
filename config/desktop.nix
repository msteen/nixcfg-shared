{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.desktop;

in {
  options.desktop = with types; {
    gtk2Theme = mkOption {
      default = "Arc";
      type = str;
      description = ''
        The GTK 2 theme to apply.
      '';
    };

    gtk2IconTheme = mkOption {
      default = "Arc";
      type = str;
      description = ''
        The GTK 2 icon theme to apply.
      '';
    };

    gtk3Theme = mkOption {
      default = "Arc";
      type = str;
      description = ''
        The GTK 3 theme to apply.
      '';
    };

    gtk3IconTheme = mkOption {
      default = "Arc";
      type = str;
      description = ''
        The GTK 3 icon theme to apply.
      '';
    };

    qt4Theme = mkOption {
      default = "Breeze";
      type = str;
      description = ''
        The Qt 4 theme to apply.
      '';
    };

    qt5Theme = mkOption {
      default = "Breeze";
      type = str;
      description = ''
        The Qt 5 theme to apply.
      '';
    };

    xcursorTheme = mkOption {
      default = "Premium";
      type = str;
      description = ''
        The X cursor theme to apply.
      '';
    };

    removeUserSettings = mkOption {
      default = false;
      type = bool;
      description = ''
        Remove user settings in order to enforce global settings.
      '';
    };
  };

  config = mkMerge [
    {
      environment.extraInit = "export XDG_CONFIG_DIRS=/etc/xdg:$XDG_CONFIG_DIRS";
      environment.pathsToLink = [ "/share" ]; # needed for themes and backgrounds
    }
    {
      environment.variables.QT_STYLE_OVERRIDE = cfg.qt5Theme; # overrides the style since Qt 5.7
    }
    {
      environment.shellInit = mkIf cfg.removeUserSettings "rm -f ~/.config/Trolltech.conf";
      environment.etc."xdg/Trolltech.conf" = {
        text = ''
          [Qt]
          style=${cfg.qt4Theme}
        '';
        mode = "444";
      };
    }
    {
      environment.extraInit = ''
        export GDK_PIXBUF_MODULEDIR=$(echo ${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/*/loaders)
        export GDK_PIXBUF_MODULE_FILE=$(echo ${pkgs.librsvg.out}/lib/gdk-pixbuf-2.0/*/loaders.cache)
        export GTK2_RC_FILES=${pkgs.writeText "iconrc" ''gtk-icon-theme-name="${cfg.gtk2IconTheme}"''}:${config.system.path}/share/themes/${cfg.gtk2Theme}/gtk-2.0/gtkrc:$GTK2_RC_FILES
      '';
      environment.variables.GTK_DATA_PREFIX = "${config.system.path}"; # needed for GTK to find theme data
    }
    {
      environment.shellInit = mkIf cfg.removeUserSettings "rm -f ~/.config/gtk-3.0/settings.ini";
      environment.etc."xdg/gtk-3.0/settings.ini" = {
        text = ''
          [Settings]
          gtk-theme-name=${cfg.gtk3Theme}
          gtk-icon-theme-name=${cfg.gtk3IconTheme}
          gtk-cursor-theme-name=${cfg.xcursorTheme}
        '';
        mode = "444";
      };
    }
    {
      environment.profileRelativeEnvVars.XCURSOR_PATH = [ "/share/icons" ];
      environment.extraInit = mkIf (!cfg.removeUserSettings) "export XCURSOR_PATH=~/.icons:$XCURSOR_PATH";
    }
    {
      environment.shellInit = mkIf cfg.removeUserSettings "rm -fR ~/.icons/default";
      environment.systemPackages = singleton (pkgs.callPackage ({ stdenv }: stdenv.mkDerivation rec {
        name = "default-xcursor-theme";
        phases = [ "installPhase" ];
        installPhase = ''
          mkdir -p $out/share/icons/default
          cat <<'EOL' > $out/share/icons/default/icon.theme
          [Icon Theme]
          Inherits=${cfg.xcursorTheme}
          EOL
          ln -s /run/current-system/sw/share/icons/${cfg.xcursorTheme}/cursors $out/share/icons/default/cursors
        '';
        meta = {
          description = "Install the default X cursor theme globally.";
        };
      }) { });
    }
  ];
}
