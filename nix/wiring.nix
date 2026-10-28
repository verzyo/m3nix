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

    # zed loads every file in its themes directory, so only the selection is needed
    (wire "zed" (lib.mkIf config.programs.zed-editor.enable {
      programs.zed-editor.userSettings.theme = lib.mkDefault {
        mode = "system";
        dark = "Noctalia Dark";
        light = "Noctalia Light";
      };
    }))
  ];
}
