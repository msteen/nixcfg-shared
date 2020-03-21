{ stdenv, lib, fetchurl, variants ? [ "Premium" "Premium-left" ] }:

with lib;

stdenv.mkDerivation rec {
  name = "${package-name}-${version}";
  package-name = "premium-xcursor-theme";
  version = "0.3";

  # FIXME: Direct donwload is no longer supported, find a mirror.
  src = fetchurl {
    url = "https://dl.opendesktop.org/api/files/download/id/1460735120/14485-Premium-${version}.tar.bz2";
    sha256 = "1qmyfgf100r5q0f5gd8zz3p3paf6wlrgr83jcjls0hybbnmzw2w4";
  };

  installPhase = ''
    for theme in ${concatStringsSep " " variants}; do
      mkdir -p $out/share/icons/$theme
      cp -R $theme/{cursors,index.theme} $out/share/icons/$theme/
    done
  '';

  meta = {
    description = "Premium X cursor theme";
    homepage = http://www.kde-look.org/content/show.php?content=14485;
    platforms = platforms.all;
    license = licenses.gpl3;
    maintainers = with maintainers; [ msteen ];
  };
}
