{ stdenv, fetchFromGitHub, pkgconfig, qmake, qtbase, qtx11extras }:

with stdenv.lib;

stdenv.mkDerivation rec {
  name = "${pname}-${version}";
  pname = "qarma";
  version = "unstable-2017-02-14";

  src = fetchFromGitHub {
    owner = "luebking";
    repo = "qarma";
    rev = "70dcb9d37fa246e2b261fe23969dd9215a7011bc";
    sha256 = "1nxpp7q1cqqqkm1s35w2h60p1f5fr9qq4z0f2cj1cjn073n2cc18";
  };

  nativeBuildInputs = [ pkgconfig qmake ];
  buildInputs = [ qtbase qtx11extras ];

  postPatch = ''
    substituteInPlace qarma.pro --replace /usr/bin $out/bin
  '';

  qmakeFlags = [ "qarma.pro" ];

  postInstall = ''
    ln -s $out/bin/qarma $out/bin/zenity
  '';

  meta = {
    description = "Zenity Clone for Qt4/Qt5";
    homepage = https://github.com/luebking/qarma;
    platforms = platforms.all;
    license = licenses.gpl2;
    maintainers = with maintainers; [ msteen ];
  };
}
