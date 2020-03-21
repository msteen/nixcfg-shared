{ stdenv, fetchurl, cmake, gcc, gfortran, openmpi, python }:

stdenv.mkDerivation rec {
  name = "${pname}-${version}";
  pname = "sundials";
  version = "3.1.0";

  src = fetchurl {
    url = "https://computation.llnl.gov/projects/${pname}/download/${pname}-${version}.tar.gz";
    sha256 = "0fnlrpj6qjamxahd70r4vsgv85kxbgh93gxqk5xzf9ln6a7jzm8q";
  };

  buildInputs = [ cmake gcc gfortran openmpi python ];

  # The PDFs will be removed as part of the default cmake behavior,
  # so they will not be available at `postInstall`.
  prePatch = ''
    mkdir -p $out/share/doc
    find ./doc -name '*.pdf' -exec cp {} "$out/share/doc" \;
  '';

  preConfigure = ''
    export cmakeFlags=$(echo \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_INSTALL_INCLUDEDIR=include \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DMPI_ENABLE=ON \
      -DPTHREAD_ENABLE=ON \
      -DOPENMP_ENABLE=ON \
      -DFCMIX_ENABLE=ON \
      -DEXAMPLES_ENABLE_C=ON \
      -DEXAMPLES_ENABLE_CXX=ON \
      -DEXAMPLES_ENABLE_F77=ON \
      -DEXAMPLES_ENABLE_F90=ON \
      -DEXAMPLES_INSTALL=ON \
      -DEXAMPLES_INSTALL_PATH=$out/share/examples \
      "$cmakeFlags")
  '';

  meta = with stdenv.lib; {
    homepage = https://computation.llnl.gov/projects/sundials;
    description = "Suite of nonlinear differential/algebraic equation solvers";
    license = licenses.bsd3;
    platforms = platforms.all;
  };
}
