# noctalia's template engine on its own, built from whatever noctalia source it is given
{
  lib,
  stdenv,
  pkg-config,
  python3,
  glib,
  nlohmann_json,
  sdbus-cpp_2,
  systemd,
  tomlplusplus,
  src,
}:
stdenv.mkDerivation {
  pname = "noctalia-theme";
  version = lib.fileContents "${src}/VERSION";

  inherit src;

  nativeBuildInputs = [pkg-config python3];
  buildInputs = [glib nlohmann_json sdbus-cpp_2 systemd tomlplusplus];

  # the source list follows upstream's includes, so new engine files need no change here
  buildPhase = ''
    runHook preBuild

    {
      python3 -I ${./sources.py} . ${./main.cpp}
      echo ${./main.cpp}
      find third_party/material_color_utilities/cpp -name '*.cc' ! -name '*_test.cc'
    } > sources.txt

    export NOCTALIA_CXXFLAGS="-std=c++23 -O2 -w -Isrc -isystem third_party/material_color_utilities \
      -DNOCTALIA_INSTALL_PREFIX=\"$out\" -DNOCTALIA_INSTALL_DATADIR=\"share\" -DNOCTALIA_VERSION=\"$version\" \
      $(pkg-config --cflags gio-2.0 sdbus-c++ tomlplusplus nlohmann_json)"

    mkdir obj
    while read -r file; do
      echo "$file obj/$(echo "$file" | tr / _).o"
    done < sources.txt | xargs -P "$NIX_BUILD_CORES" -n 2 sh -c '$CXX $NOCTALIA_CXXFLAGS -c "$1" -o "$2"' _

    $CXX obj/*.o $(pkg-config --libs gio-2.0 sdbus-c++ tomlplusplus) -o noctalia-theme

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 noctalia-theme $out/bin/noctalia-theme
    runHook postInstall
  '';

  meta = {
    description = "Noctalia's template renderer without the rest of the shell";
    license = lib.licenses.mit;
    mainProgram = "noctalia-theme";
    platforms = lib.platforms.linux;
  };
}
