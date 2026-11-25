# points each app at its rendered theme, only when home manager manages that app
{
  config,
  lib,
  ...
}: let
  cfg = config.m3nix;
  wire = id: content: lib.mkIf (cfg.enable && cfg.apps.${id}.enable) content;
in {
  config = lib.mkMerge [
    (wire "foot" (lib.mkIf config.programs.foot.enable {
      programs.foot.settings.main.include = [cfg.apps.foot.outputs.foot];
      m3nix.placeholders = [cfg.apps.foot.outputs.foot];
    }))

    # zed loads every file in its themes directory, so only the selection is needed. m3nix's zed
    # template is a single theme that follows matugen's mode, so one name covers both
    (wire "zed" (lib.mkIf config.programs.zed-editor.enable {
      programs.zed-editor.userSettings.theme = lib.mkDefault "M3nix";
    }))
  ];
}
