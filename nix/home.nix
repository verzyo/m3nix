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

  # additional noctalia m3 tokens
  extraTokens = mode: {
    hover = "{{ colors.tertiary.${mode}.hex }}";
    on_hover = "{{ colors.on_tertiary.${mode}.hex }}";
  };

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
  };

  config = lib.mkIf cfg.enable {
    warnings = map (entry: "m3nix: skipping template ${entry}, it uses dynamic paths or a gtk extension, which are not supported yet") skipped;

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
