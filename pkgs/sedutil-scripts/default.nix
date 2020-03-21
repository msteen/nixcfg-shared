{ stdenv, makeWrapper, sedutil, sedutil-scripts-unwrapped }:

stdenv.mkDerivation rec {
  name = "sedutil-scripts";

  buildInputs = [ makeWrapper ];

  phases = [ "installPhase" ];

  installPhase = ''
    mkdir -p $out/bin
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-disk --prefix PATH : "${sedutil}/bin"
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-enable --prefix PATH : "${sedutil}/bin:$out/bin"
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-disable --prefix PATH : "${sedutil}/bin:$out/bin"
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-lock --prefix PATH : "${sedutil}/bin:$out/bin"
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-unlock --prefix PATH : "${sedutil}/bin:$out/bin"
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-pba --prefix PATH : "${sedutil}/bin:$out/bin"
    makeWrapper {${sedutil-scripts-unwrapped},$out}/bin/sedutil-passwd --prefix PATH : "${sedutil}/bin:$out/bin"
  '';

  meta = with stdenv.lib; {
    description = "Helper scripts for sedutil";
    maintainers = with maintainers; [ msteen ];
    license = licenses.gpl3;
    platforms = platforms.linux;
  };
}
