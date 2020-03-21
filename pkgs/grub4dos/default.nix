{ stdenv, fetchzip, nasm }:

let arch =
  if stdenv.isi686 then "i386"
  else if stdenv.isx86_64 then "x86_64"
  else throw "Unknown architecture";
in stdenv.mkDerivation rec {
  name = "grub4dos-${version}";
  version = "0.4.5c-2016-01-18";

  src = fetchzip {
    url = https://github.com/chenall/grub4dos/archive/3c1d05f39e49ec1d7543caa825df00068b96620b.zip;
    sha256 = "10kiijd4z9yxjidpqq4n4k3q5h9c07n6qji4na52hq063c1pv3xg";
  };

  nativeBuildInputs = [ nasm ];

  hardeningDisable = [ "stackprotector" ];

  configureFlags = [ "--host=${arch}-pc-linux-gnu" "--enable-preset-menu=${./menu.lst}" ];

  postInstall = ''
    mv $out/lib/grub/${arch}-pc/* $out/lib/grub
    rmdir $out/lib/grub/${arch}-pc
    chmod +x $out/lib/grub/bootlace.com
  '';

  dontStrip = true;
  dontPatchELF = true;

  meta = with stdenv.lib; {
    homepage = http://grub4dos.chenall.net/;
    description = "GRUB for DOS is the DOS extension of GRUB";
    maintainers = with maintainers; [ abbradar ];
    platforms = platforms.linux;
    license = licenses.gpl2;
  };
}
