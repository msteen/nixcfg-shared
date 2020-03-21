{ lib, pkgs, ... }:

with lib;

{
  imports = [
    ./.
    ../modules/synergy2.nix
  ];

  hardware.pulseaudio.enable = true;
  sound.enable = true;

  environment.systemPackages = with pkgs; [
    glxinfo # graphics card info
    libqalculate # qalc (CLI frontend)
    ncurses
    nix-du
    pinentry
    qalculate-gtk
    wmctrl
    xclip
    xdo
    xdotool
    xorg.mkfontdir
    xorg.xev
    xorg.xlsfonts
    xorg.xmessage
    xorg.xwininfo
    xsel
    xterm
    xtitle
    xvkbd
  ];

  # In non-graphical environments, such as TTYs, this variable will not be set,
  # but if we want to be able to run X related commands from them, such as those of the window manager,
  # then it will need to be set, so we assign it the default display and screen.
  environment.variables."DISPLAY" = ":0.0";

  # Use clipboard as the default X selection.
  environment.aliases."xclip" = "xclip -selection c";

  # Do not offer to mount encrypted partitions.
  services.udev.extraRules = ''
    ENV{ID_FS_USAGE}=="crypto", ENV{UDISKS_IGNORE}="1"
  '';

  services.xserver = {
    enable = true;
    exportConfiguration = true;
    layout = mkDefault "us";
    xkbVariant = mkDefault "euro";
    xkbOptions = mkDefault "compose:menu";
  };

  # The reason for the error message that the default config file could not be loaded
  # is due to requesting a font that is missing from the font configuration file,
  # like ttf_liberation was initially for Google Chrome.
  # http://askubuntu.com/questions/492033/fontconfig-error-cannot-load-default-config-file
  fonts = {
    enableFontDir = true;
    enableGhostscriptFonts = true;
    fonts = with pkgs; [
      dejavu_fonts
      fira-code
      font-awesome-ttf
      freefont_ttf
      inconsolata
      liberation_ttf
      noto-fonts
      powerline-fonts
      siji
      terminus_font
      ttf_bitstream_vera
      ubuntu_font_family
      unifont
      vistafonts
      iosevka
    ];
  };
}
