wrapScript() {
  (( $# < 2 )) && die "At least the original script and the wrapper path should be given"
  local original=$1 wrapper=$2
  shift
  shift
  cp "$original" "$wrapper"
  patchShebangs "$wrapper"
  wrapProgram "$wrapper" "$@"
}
