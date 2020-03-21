{ stdenv, lib, fetchurl, makeWrapper, dpkg, systemd, xorg, qt5, openssl, hicolor_icon_theme }:

with lib;

let
  deps = [
    systemd.lib
    stdenv.cc.cc.lib
    xorg.libX11
    xorg.libXi
    xorg.libXtst
    xorg.libXext
    qt5.qtbase
    qt5.qtdeclarative
    qt5.qtquickcontrols
    openssl
    hicolor_icon_theme
  ];

in stdenv.mkDerivation rec {
  name = "${package-name}-${version}";
  package-name = "synergy";
  version = "2.0.5";

  src = fetchurl {
    url = https://binaries.symless.com/v2.0.5/synergy_2.0.5.stable~b1345%2B3f23b557_amd64.deb;
    sha256 = "1pvp8j5qda1dih7z22w839dbykkf9m1b6qc9bhyg9gsqs5dm0xxv";
    name = "${package-name}_${version}.stable_amd64.deb";
  };

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ dpkg ] ++ deps;

  # ./result/bin/synergy-tests: ./result/bin/synergy-tests: no version information available (required by ./result/bin/synergy-tests)
  # https://github.com/NixOS/patchelf/issues/99#issuecomment-355536880
  dontStrip = true;

  phases = [ "unpackPhase" "installPhase" "fixupPhase" ];

  unpackPhase = ''
    dpkg-deb -x $src .
  '';

  installPhase = ''
    mkdir -p $out
    cp -r ./usr/bin $out
    cp -r ./usr/share $out

    for elf in $out/bin/synergy-*; do
      patchelf --set-interpreter "$(cat ${stdenv.cc}/nix-support/dynamic-linker)" --set-rpath ${makeLibraryPath deps} $elf
    done
  '';

  meta = {
    homepage = https://symless.com/synergy;
    description = "Keyboard and mouse sharing solution. Synergy allows you to share one mouse and keyboard between multiple computers. Work seamlessly across Windows, macOS and Linux.";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with maintainers; [ msteen ];
  };
}
