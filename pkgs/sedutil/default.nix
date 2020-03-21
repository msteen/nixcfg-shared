{ stdenv, fetchFromGitHub, which, git }:

stdenv.mkDerivation rec {
  name = "sedutil-cli-${version}";
  version = "1.15.1";

  src = fetchFromGitHub {
    owner = "Drive-Trust-Alliance";
    repo = "sedutil";
    rev = version;
    sha256 = "0zg5v27vbrzzl2vqzks91zj48z30qgcshkqkm1g8ycnhi145l0mf";
  };

  buildInputs = [ which git ];

  postUnpack = "sourceRoot+=/linux/CLI; echo source root reset to \$sourceRoot";

  postPatch = "patchShebangs ..";

  buildPhase = ''
    gcc -Wall -o getpasswd ${./getpasswd.c}
    make CONF="Release_x86_64" build
  '';

  makeFlags = "PREFIX=$(out)";

  installPhase = ''
    mkdir -p $out/bin
    cp getpasswd $out/bin
    cp dist/Release_x86_64/GNU-Linux/sedutil-cli $out/bin
  '';

  meta = with stdenv.lib; {
    description = "TCG OPAL 2.00 SED Management Program";
    homepage = https://github.com/Drive-Trust-Alliance/sedutil;
    maintainers = with maintainers; [ msteen ];
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
