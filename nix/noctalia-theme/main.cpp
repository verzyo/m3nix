// renders noctalia templates from a precomputed theme.json, the subset of `noctalia theme` m3nix needs
#include "theme/color.h"
#include "theme/fixed_palette.h"
#include "theme/palette.h"
#include "theme/template_engine.h"

#include <cstdio>
#include <fstream>
#include <nlohmann/json.hpp>
#include <string>
#include <string_view>
#include <vector>

namespace theme = noctalia::theme;

namespace {

  void usage(const char* argv0) {
    std::fprintf(stderr,
                 "usage: %s --theme-json <file> [--default-mode dark|light] [-c <templates.toml>] [-r <in:out>]...\n",
                 argv0);
  }

  bool loadThemeJson(const std::string& path, theme::GeneratedPalette& palette) {
    std::ifstream file(path);
    if (!file) {
      std::fprintf(stderr, "error: cannot open %s\n", path.c_str());
      return false;
    }

    const auto root = nlohmann::json::parse(file, nullptr, false);
    if (root.is_discarded() || !root.is_object()) {
      std::fprintf(stderr, "error: %s is not a json object\n", path.c_str());
      return false;
    }

    for (const auto& [mode, tokens] : {std::pair{"dark", &palette.dark}, std::pair{"light", &palette.light}}) {
      if (!root.contains(mode) || !root[mode].is_object())
        continue;
      for (const auto& [name, value] : root[mode].items()) {
        if (!value.is_string())
          continue;
        try {
          (*tokens)[name] = theme::Color::fromHex(value.get<std::string>()).toArgb();
        } catch (...) {
          std::fprintf(stderr, "warning: skipping %s.%s, not a color\n", mode, name.c_str());
        }
      }
    }

    if (palette.dark.empty() && palette.light.empty()) {
      std::fprintf(stderr, "error: %s has no dark or light tokens\n", path.c_str());
      return false;
    }
    return true;
  }

} // namespace

int main(int argc, char* argv[]) {
  std::string themeJson;
  std::string defaultMode = "dark";
  std::string config;
  std::vector<std::string> renders;

  for (int i = 1; i < argc; ++i) {
    const std::string_view arg = argv[i];
    const bool hasValue = i + 1 < argc;
    if (arg == "--theme-json" && hasValue)
      themeJson = argv[++i];
    else if (arg == "--default-mode" && hasValue)
      defaultMode = argv[++i];
    else if ((arg == "-c" || arg == "--config") && hasValue)
      config = argv[++i];
    else if ((arg == "-r" || arg == "--render") && hasValue)
      renders.emplace_back(argv[++i]);
    else {
      usage(argv[0]);
      return 2;
    }
  }

  if (themeJson.empty() || (config.empty() && renders.empty())) {
    usage(argv[0]);
    return 2;
  }

  theme::GeneratedPalette palette;
  if (!loadThemeJson(themeJson, palette))
    return 1;
  // fills whatever terminal tokens theme.json left out, exactly like noctalia does
  theme::synthesizeTerminalPaletteTokens(palette);

  theme::TemplateEngine::Options options;
  options.defaultMode = defaultMode;
  theme::TemplateEngine engine(theme::TemplateEngine::makeThemeData(palette), std::move(options));

  for (const auto& spec : renders) {
    const auto colon = spec.find(':');
    if (colon == std::string::npos) {
      std::fprintf(stderr, "error: invalid render spec (expected input:output): %s\n", spec.c_str());
      return 1;
    }
    if (!engine.renderFile(spec.substr(0, colon), spec.substr(colon + 1)).success)
      return 1;
  }

  if (!config.empty() && !engine.processConfigFile(config))
    return 1;

  return 0;
}
