{
  # The script uses either the CLI or GUI program depending on being in a shell or not.
  environment.interactiveShellInit = "export PINENTRY_USER_DATA=$TTY";

  nixpkgs.overlays = [
    (self: super: {
      pinentry-dynamic = super.writeBash "pinentry-dynamic" ''
        # http://unix.stackexchange.com/questions/236746/change-pinentry-program-temporarily-with-gpg-agent
        # https://github.com/keybase/keybase-issues/issues/1099#issuecomment-59313502
        if [[ -z $PINENTRY_USER_DATA ]]; then
          exec ${super.pinentry.gnome3}/bin/pinentry-gnome3 "$@"
        else
          exec ${super.pinentry.curses}/bin/pinentry-curses --ttyname "$PINENTRY_USER_DATA" "$@"
        fi
      '';
    })
  ];
}
