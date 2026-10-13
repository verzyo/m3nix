#!/usr/bin/env sh

SEQUENCES=$(
  tr -d '\r\n' <<'EOF'
\033]10;#{{colors.on_surface.default.hex_stripped}}\007
\033]11;#{{colors.background.default.hex_stripped}}\007
\033]17;#{{colors.primary_container.default.hex_stripped}}\007
\033]12;#{{colors.primary.default.hex_stripped}}\007
\033]4;0;#{{colors.surface_container_lowest.default.hex_stripped}}\007
\033]4;8;#{{colors.outline.default.hex_stripped}}\007
\033]4;7;#{{colors.on_surface_variant.default.hex_stripped}}\007
\033]4;15;#{{colors.on_surface.default.hex_stripped}}\007
<* if {{ is_dark_mode }} *>
\033]4;1;#{{ "#f38ba8" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;9;#{{ "#eba0ac" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;2;#{{ "#a6e3a1" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;10;#{{ "#94e2d5" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;3;#{{ "#f9e2af" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;11;#{{ "#fab387" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;4;#{{ "#89b4fa" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;12;#{{ "#b4befe" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;5;#{{ "#cba6f7" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;13;#{{ "#f5c2e7" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;6;#{{ "#89dceb" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;14;#{{ "#74c7ec" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
<* else *>
\033]4;1;#{{ "#d20f39" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;9;#{{ "#e64553" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;2;#{{ "#40a02b" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;10;#{{ "#179299" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;3;#{{ "#df8e1d" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;11;#{{ "#fe640b" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;4;#{{ "#1e66f5" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;12;#{{ "#7287fd" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;5;#{{ "#8839ef" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;13;#{{ "#ea76cb" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;6;#{{ "#04a5e5" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
\033]4;14;#{{ "#209fb5" | to_color | harmonize: {{ colors.primary.default.hex }} | saturate: 15.0, "hsl" | format: "hex_stripped" }}\007
<* endif *>
EOF
)

for pty in /dev/pts/[0-9]*; do
  [ -w "$pty" ] && printf '%b' "$SEQUENCES" >"$pty" 2>/dev/null
done
