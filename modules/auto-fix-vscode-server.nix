{ pkgs, ... }:

{
  systemd.user.services.auto-fix-vscode-server = {
    description = "Automatically fix the VS Code server used by the remote SSH extension";
    path = with pkgs; [ inotify-tools ];
    serviceConfig = {
      # When a monitored directory is deleted, it will stop being monitored.
      # Even if it is later recreated it will not restart monitoring it.
      # Unfortunately the monitor does not kill itself when it stops monitoring,
      # so rather than creating our own restart mechanism, we leverage systemd to do this for us.
      Restart = "always";
      RestartSec = 0;
    };
    script = ''
      mkdir -p ~/.vscode-server/bin &&
      while IFS=: read -r bin_dir event; do
        # A new version of the VS Code Server is being created.
        if [[ $event == 'CREATE,ISDIR' ]]; then
          # Create a trigger to know when their node is being created and replace it for our symlink.
          touch "$bin_dir/node" &&
          inotifywait -qq -e DELETE_SELF "$bin_dir/node" &&
          ln -sfT ${pkgs.nodejs-12_x}/bin/node "$bin_dir/node"
        # The monitored directory is deleted, e.g. when "Uninstall VS Code Server from Host" has been run.
        elif [[ $event == DELETE_SELF ]]; then
          # See the comments above Restart in the service config.
          exit 0
        fi
      done < <(inotifywait -q -m -e CREATE,ISDIR -e DELETE_SELF --format '%w%f:%e' ~/.vscode-server/bin)
    '';
    wantedBy = [ "default.target" ];
  };
}
