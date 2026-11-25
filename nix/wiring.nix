# points each app at its rendered theme, only when home manager manages that app
{
  config,
  options,
  lib,
  pkgs,
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

    # foot never rereads its config, so running terminals get the new colors over OSC
    (wire "foot" {
      m3nix.postRender = [
        "${pkgs.writeShellScript "m3nix-foot-reload" (builtins.readFile ./foot-reload.sh)} ${lib.escapeShellArg cfg.apps.foot.outputs.foot}"
      ];
    })

    # zed loads every file in its themes directory, so only the selection is needed. m3nix's zed
    # template is a single theme that follows matugen's mode, so one name covers both
    (wire "zed" (lib.mkIf config.programs.zed-editor.enable {
      programs.zed-editor.userSettings.theme = lib.mkDefault "M3nix";
    }))

    # niri-flake writes config.kdl from its settings, so the theme comes in as an include. it goes
    # last so its colors win over the config's own, and non-store includes are optional, so niri
    # validate and the first start before any render both pass. niri-flake has no enable switch and
    # reading settings here would recurse, so having its module is taken as using its settings
    (lib.optionalAttrs (options.programs ? niri.settings) (wire "niri" {
      programs.niri.settings.includes = lib.mkAfter [cfg.apps.niri.outputs.niri];
    }))
  ];
}
