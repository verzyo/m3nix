# recolors running foot terminals live: turns the freshly rendered foot theme into OSC color
# sequences and writes them to every pty we can write to. new terminals read the theme file itself,
# so both always match
theme=$1
[ -f "$theme" ] || exit 0

seq=
while IFS='=' read -r key value; do
	case $key in
	foreground) seq="$seq\033]10;#$value\007" ;;
	background) seq="$seq\033]11;#$value\007" ;;
	regular[0-7]) seq="$seq\033]4;${key#regular};#$value\007" ;;
	bright[0-7]) seq="$seq\033]4;$((${key#bright} + 8));#$value\007" ;;
	selection-background) seq="$seq\033]17;#$value\007" ;;
	selection-foreground) seq="$seq\033]19;#$value\007" ;;
	# foot's cursor is "<text color> <cursor color>"
	cursor) seq="$seq\033]12;#${value#* }\007" ;;
	esac
done <"$theme"

for pty in /dev/pts/[0-9]*; do
	if [ -w "$pty" ]; then
		printf '%b' "$seq" >"$pty" 2>/dev/null || true
	fi
done
