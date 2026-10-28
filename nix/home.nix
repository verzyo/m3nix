{
  noctalia,
  community-templates,
}: {
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.m3nix;

  builtinApps = let
    templatesDir = "${noctalia}/assets/templates";
    builtinToml = lib.importTOML "${templatesDir}/builtin.toml";
  in
    lib.mapAttrs (id: meta:
      meta
      // {
        dir = templatesDir;
        entries = {${id} = builtinToml.templates.${id};};
      })
    builtinToml.catalog;

  communityApps = lib.concatMapAttrs (dir: type: let
    templatePath = "${community-templates}/${dir}/template.toml";
    templateToml = lib.importTOML templatePath;
  in
    lib.optionalAttrs (type == "directory" && builtins.pathExists templatePath) {
      ${dir} =
        templateToml.catalog.${dir}
        // {
          dir = "${community-templates}/${dir}";
          entries = templateToml.templates or {};
        };
    }) (builtins.readDir community-templates);

  apps = builtinApps // communityApps; # community entries win (on dupe)
  enabledApps = lib.filterAttrs (id: _: cfg.apps.${id}.enable) apps;

  cleanEntry = dir: spec: let
    abs = path: "${dir}/${path}";
  in
    lib.filterAttrs (_: value: value != null) {
      input_path = lib.mapNullable abs (spec.input_path or null);
      input_path_modes = lib.mapNullable (lib.mapAttrs (_: abs)) (spec.input_path_modes or null);
      output_path = spec.output_path or null;
      requires_path = spec.requires_path or null;
    };

  isSupported = spec: !(spec ? input_path_dynamic || spec ? output_path_dynamic || spec ? gtk_extension);

  templates = lib.concatMapAttrs (_: app:
    lib.mapAttrs (_: cleanEntry app.dir) (lib.filterAttrs (_: isSupported) app.entries))
  enabledApps;
  skipped = lib.concatLists (lib.mapAttrsToList (id: app:
    map (entry: "${id}.${entry}") (lib.attrNames (lib.filterAttrs (_: spec: !isSupported spec) app.entries)))
  enabledApps);

  templatesToml = (pkgs.formats.toml {}).generate "m3nix-templates.toml" {
    inherit templates;
  };

  # base16 slot for each ansi color, bright ones from base24 when the scheme has them
  ansiSlots = {
    red = {
      normal = "08";
      bright = "12";
    };
    yellow = {
      normal = "0A";
      bright = "13";
    };
    green = {
      normal = "0B";
      bright = "14";
    };
    cyan = {
      normal = "0C";
      bright = "15";
    };
    blue = {
      normal = "0D";
      bright = "16";
    };
    magenta = {
      normal = "0E";
      bright = "17";
    };
  };

  # tinted theming yaml (palette or flat layout) or an attrset of baseXX colors, keyed by slot
  schemeColors = scheme: let
    raw =
      if builtins.isAttrs scheme
      then lib.mapAttrs' (name: lib.nameValuePair (lib.removePrefix "base" name)) scheme
      else
        lib.listToAttrs (lib.concatMap (line: let
          match = builtins.match ''[[:space:]]*base([0-9A-Fa-f]{2})[[:space:]]*:[[:space:]]*["']?#?([0-9A-Fa-f]{6})["']?.*'' line;
        in
          lib.optional (match != null) (lib.nameValuePair (lib.elemAt match 0) (lib.elemAt match 1)))
        (lib.splitString "\n" (builtins.readFile scheme)));
  in
    lib.mapAttrs' (slot: color: lib.nameValuePair (lib.toUpper slot) "#${lib.toLower (lib.removePrefix "#" color)}") raw;

  modes = ["dark" "light"];

  base16 = lib.genAttrs modes (mode: lib.mapNullable schemeColors cfg.base16.scheme.${mode}.source);
  missingSlots = mode:
    lib.optionals (base16.${mode} != null)
    (lib.filter (slot: !(base16.${mode} ? ${slot})) (lib.mapAttrsToList (_: slots: slots.normal) ansiSlots));

  # noctalia fills in any terminal token missing here from the m3 roles
  base16Tokens = mode: let
    colors = base16.${mode};
    filters = cfg.base16.scheme.${mode}.filters;
    # theme.json must hold plain #rrggbb, the app templates do their own formatting
    filtered = color:
      if filters == []
      then color
      else ''{{ "${color}" | to_color | ${lib.concatStringsSep " | " filters} | format: "hex" }}'';
  in
    lib.optionalAttrs (colors != null) (lib.concatMapAttrs (name: slots: {
        "terminal_normal_${name}" = filtered colors.${slots.normal};
        "terminal_bright_${name}" = filtered (colors.${slots.bright} or colors.${slots.normal});
      })
      ansiSlots);

  # additional noctalia m3 tokens
  extraTokens = mode:
    {
      hover = "{{ colors.tertiary.${mode}.hex }}";
      on_hover = "{{ colors.on_tertiary.${mode}.hex }}";
    }
    // base16Tokens mode;

  themeJsonMode = mode: ''
    "${mode}": {
    <* for name, value in colors *>
      "{{ name }}": "{{ value.${mode}.hex }}",
    <* endfor *>
    ${lib.concatStringsSep ",\n" (lib.mapAttrsToList (name: expr: ''"${name}": "${expr}"'') (extraTokens mode))}
    }
  '';
in {
  options.m3nix = {
    enable = lib.mkEnableOption "m3nix theming";

    packages = {
      matugen = lib.mkPackageOption pkgs "matugen" {};
      noctalia = lib.mkPackageOption pkgs "noctalia" {};
    };

    apps =
      lib.mapAttrs (_: app: {
        enable = lib.mkEnableOption "the ${app.name} template (${app.category})";
      })
      apps;

    base16.scheme = lib.genAttrs modes (mode: {
      source = lib.mkOption {
        type = lib.types.nullOr (lib.types.oneOf [lib.types.path lib.types.str (lib.types.attrsOf lib.types.str)]);
        default = null;
        example = lib.literalExpression ''"''${pkgs.base16-schemes}/share/themes/catppuccin-${
            if mode == "dark"
            then "mocha"
            else "latte"
          }.yaml"'';
        description = ''
          Base16 or base24 scheme for the ${mode} mode terminal colors, as a Tinted Theming yaml file
          or an attrset of `baseXX` colors. When null, noctalia derives them from the material roles.
        '';
      };

      filters = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["blend: {{ colors.primary.${mode}.hex }}, 0.3" ''saturate: 10.0, "hsl"''];
        description = ''
          Matugen filters applied in order to each ${mode} mode base16 color, written without the
          leading `|`. They can reference the generated palette, e.g. `{{ colors.primary.${mode}.hex }}`.
          Leave out `format`, m3nix always outputs hex and the app templates format it themselves.
        '';
      };
    });
  };

  config = lib.mkIf cfg.enable {
    assertions =
      map (mode: {
        assertion = missingSlots mode == [];
        message = "m3nix: base16.scheme.${mode}.source is missing ${lib.concatMapStringsSep ", " (slot: "base${slot}") (missingSlots mode)}";
      })
      modes;

    warnings =
      map (entry: "m3nix: skipping template ${entry}, it uses dynamic paths or a gtk extension, which are not supported yet") skipped
      ++ map (mode: "m3nix: base16.scheme.${mode}.filters has no effect without base16.scheme.${mode}.source")
      (lib.filter (mode: base16.${mode} == null && cfg.base16.scheme.${mode}.filters != []) modes);

    home.packages = with cfg.packages; [
      matugen
      noctalia
    ];

    xdg.configFile."matugen/config.toml".source = (pkgs.formats.toml {}).generate "matugen-config.toml" {
      config = {};

      templates.m3nix = let
        themeJson = "${config.xdg.stateHome}/m3nix/theme.json";
        themeJsonTemplate = pkgs.writeText "m3nix-theme.json" ''
          {
          ${themeJsonMode "dark"},
          ${themeJsonMode "light"}
          }
        '';
      in {
        input_path = "${themeJsonTemplate}";
        output_path = themeJson;
        post_hook = "${lib.getExe' cfg.packages.noctalia "noctalia"} theme --theme-json '${themeJson}' --default-mode {{ mode }} -c ${templatesToml}";
      };
    };
  };
}
