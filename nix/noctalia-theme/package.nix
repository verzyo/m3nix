# noctalia's template engine on its own, built from whatever noctalia source it is given
#
# nothing here mirrors upstream's build by hand: plan.py takes the sources, include dirs and defines
# from upstream, and the compile and link flags come from every pkg-config module in buildInputs.
# if upstream gains a new dependency, adding its package to buildInputs is the only change needed.
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
  version =
    lib.fileContents "${src}/VERSION"
    + lib.optionalString (src ? lastModifiedDate) "-unstable-${lib.concatStringsSep "-" (builtins.match "(.{4})(.{2})(.{2}).*" src.lastModifiedDate)}";

  inherit src;

  nativeBuildInputs = [pkg-config python3];
  buildInputs = [glib nlohmann_json sdbus-cpp_2 systemd tomlplusplus];

  buildPhase = ''
    runHook preBuild

    python3 -I ${./plan.py} . sources.txt cflags.txt ${./main.cpp}

    modules=$(pkg-config --list-all | cut -d' ' -f1 | sort)
    echo "-std=c++23 -O2 -w $(pkg-config --cflags $modules)" >> cflags.txt

    mkdir obj
    n=0
    while read -r file; do
      echo "$file obj/$((n++)).o"
    done < sources.txt | xargs -P "$NIX_BUILD_CORES" -n 2 sh -c '$CXX @cflags.txt -c "$1" -o "$2"' _

    $CXX obj/*.o -Wl,--as-needed $(pkg-config --libs $modules) -o noctalia-theme

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 noctalia-theme $out/bin/noctalia-theme
    runHook postInstall
  '';

  # renders a template, so a binary that links but no longer works fails the build
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    echo '{"dark": {"primary": "#6750a4"}}' > theme.json
    echo '{{ colors.primary.default.hex }} {{ colors.terminal_normal_red.default.hex }}' > template.txt
    $out/bin/noctalia-theme --theme-json theme.json -r template.txt:rendered.txt
    grep -Eq '^#6750a4 #[0-9a-f]{6}$' rendered.txt

    echo '{"dark": {"surface": "#141218", "primary": "#6750a4"}}' > theme.json
    echo '{{ colors.surface.default.hex }} {{ colors.primary.default.hex }}' > template.txt
    $out/bin/noctalia-theme --theme-json theme.json --pure-black -r template.txt:rendered.txt
    grep -Eq '^#000000 #6750a4$' rendered.txt
    runHook postInstallCheck
  '';

  meta = {
    description = "Noctalia's template renderer without the rest of the shell";
    license = lib.licenses.mit;
    mainProgram = "noctalia-theme";
    platforms = lib.platforms.linux;
  };
}
