{ writeShellScriptBin, lib, nmap, gnugrep }:

writeShellScriptBin "port-up" ''
  PATH=${lib.makeBinPath [ nmap gnugrep ]}

  if (( $# != 2 )); then
    echo "port-up <host> <port>" >&2
    exit 1
  fi

  # -n = no DNS resolution
  # -PS = TCP SYN ping (faking establishing a connection)
  nmap \
    --unprivileged \
    -n \
    --initial-rtt-timeout 100ms \
    --max-retries 0 \
    -PS"$2" \
    -p "$2" \
    "$1" 2>/dev/null | grep -q '1 host up'
''
