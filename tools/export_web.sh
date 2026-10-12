#!/usr/bin/env bash
# Exports the browser build into build/web/ (no threads, so no special server headers needed).
# With --threads it exports the multi-threaded build into build/web-mt/ instead: faster, but the
# server must send Cross-Origin-Opener-Policy: same-origin and Cross-Origin-Embedder-Policy: require-corp.
# Downloads Godot's 4.3 export templates the first time (about 1 GB, only the web ones are kept).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT="${GODOT:-$(command -v godot || echo "$HOME/.local/bin/godot")}"
TPL="$HOME/.local/share/godot/export_templates/4.3.stable"
if [ ! -f "$TPL/web_nothreads_release.zip" ]; then
	mkdir -p "$TPL"
	tmp="$(mktemp -d)"
	curl -fsSL -o "$tmp/t.tpz" \
		"https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz"
	unzip -q -o "$tmp/t.tpz" 'templates/web_*' 'templates/version.txt' -d "$tmp"
	mv "$tmp"/templates/* "$TPL/"
	rm -rf "$tmp"
fi
PRESET="Web"; OUT="$ROOT/build/web"
if [ "${1:-}" = "--threads" ]; then PRESET="Web Threads"; OUT="$ROOT/build/web-mt"; fi
mkdir -p "$OUT"
# Keep Godot from importing the previous build's images (they would end up inside the next .pck).
touch "$ROOT/build/.gdignore"
rm -f "$ROOT"/build/web*/*.import
"$GODOT" --headless --path "$ROOT" --export-release "$PRESET" "$OUT/index.html"
cp "$ROOT/tools/web/.htaccess" "$ROOT/tools/web/HOW-TO-UPLOAD.txt" "$OUT/"
echo "web build in $OUT ($(du -sh "$OUT" | cut -f1))"
