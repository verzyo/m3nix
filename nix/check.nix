# runs the whole pipeline with every template enabled: matugen renders theme.json, its hook runs
# noctalia-theme over all templates, and every output must come out rendered. catches upstream
# catalog, template or engine changes that would otherwise only show up after a switch
{
  pkgs,
  home-manager,
  homeModule,
}: let
  inherit (pkgs) lib;
  home = "/home/m3nix-check";

  hm = home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    modules = [
      homeModule
      ({options, ...}: {
        home = {
          username = "m3nix-check";
          homeDirectory = home;
          stateVersion = "25.11";
        };

        m3nix = {
          enable = true;
          apps = lib.mapAttrs (_: _: {enable = true;}) options.m3nix.apps;
          # exercises the base16 path in one mode and the derived terminal colors in the other
          base16.scheme.dark = {
            source = "${pkgs.base16-schemes}/share/themes/catppuccin-mocha.yaml";
            filters = ["blend: {{ colors.primary.dark.hex }}, 0.3"];
          };
        };
      })
    ];
  };
  cfg = hm.config;

  # paths as the shell sees them, so it expands the same $XDG_* variables noctalia does; matugen
  # entries come already expanded against the fake home
  shellPath = path: ''"${lib.replaceStrings [''"'' "`" "~/" "${home}/"] [''\"'' "\\`" "$HOME/" "$HOME/"] path}"'';
  inHome = path: !(lib.hasPrefix "/" path);

  # entries gated on a system path (e.g. /usr/bin/app) can't be faked here, the rest all must render
  entries = lib.attrValues cfg.m3nix.templates;
  checkable = lib.filter (spec: lib.all inHome (lib.toList (spec.requires_path or []))) entries;
  required = lib.unique (lib.concatMap (spec: lib.toList (spec.requires_path or [])) checkable);
  outputs = lib.unique (lib.concatMap (spec: lib.toList spec.output_path) checkable);
in
  pkgs.runCommand "m3nix-render-all" {
    nativeBuildInputs = [cfg.m3nix.packages.matugen pkgs.jq];
    passAsFile = ["warnings"];
    warnings = lib.concatLines cfg.warnings;
  } ''
    export HOME=$TMPDIR/home
    export XDG_CONFIG_HOME=$HOME/.config XDG_DATA_HOME=$HOME/.local/share \
      XDG_STATE_HOME=$HOME/.local/state XDG_CACHE_HOME=$HOME/.cache
    sed 's|${home}|'"$HOME"'|g' ${cfg.xdg.configFile."matugen/config.toml".source} > config.toml
    cat "$warningsPath"

    # pretend every app is installed so no entry gets skipped, both by requires_path and by
    # noctalia gating entries that share an input on their client's config dir existing
    outputs=(${lib.concatMapStringsSep " " shellPath outputs})
    ${lib.concatMapStringsSep "\n" (path: "mkdir -p ${shellPath path}") required}
    for file in "''${outputs[@]}"; do mkdir -p "$(dirname "$file")"; done

    # matugen exits 0 even when its hook fails, so success is judged by the outputs alone,
    # cleared before each mode so one mode can't pass on what the other rendered
    for mode in dark light; do
      echo "rendering $mode"
      rm -f "''${outputs[@]}" "$XDG_CACHE_HOME/m3nix/theme.json"
      matugen color hex '#6750a4' --mode "$mode" --config config.toml
      jq -e '.dark.primary and .light.primary and .dark.terminal_normal_red' \
        "$XDG_CACHE_HOME/m3nix/theme.json" > /dev/null

      rendered=0 failed=0
      for file in "''${outputs[@]}"; do
        if [ ! -s "$file" ]; then
          echo "not rendered: $file" >&2
          failed=$((failed + 1))
        elif grep -q '{{ *colors\.' "$file"; then
          echo "unrendered tokens left in: $file" >&2
          failed=$((failed + 1))
        else
          rendered=$((rendered + 1))
        fi
      done
      echo "$mode: ${toString (lib.length entries)} templates, $rendered outputs rendered, $failed failed"
      [ "$failed" -eq 0 ]
    done

    touch $out
  ''
