{ stdenv, fetchFromGitHub, libXrandr, libXinerama }:

stdenv.mkDerivation rec {
  name = "${pname}-${version}";
  pname = "srandrd";
  version = "0.6.0";

  src = fetchFromGitHub {
    owner = "jceb";
    repo = pname;
    rev = "6288a36a14b3d9ccd30f4a2d5f5f2f38b236d38b";
    sha256 = "1nzh9nqzljdh0dfjrygxy6waar79rrxzvlxn937nplvfvi7l2wvl";
  };

  buildInputs = [ libXrandr libXinerama ];

  makeFlags = "PREFIX=$(out)";

  meta = with stdenv.lib; {
    description = "Simple randr daemon that reacts to monitor hotplug events";
    homepage = https://github.com/jceb/srandrd;
    maintainers = with maintainers; [ msteen ];
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
