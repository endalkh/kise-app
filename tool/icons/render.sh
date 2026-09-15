#!/usr/bin/env bash
# Render the Kise coin into the app's icons and in-app asset, from tool/icons/coin.html.
#
#   app/tool/icons/render.sh
#
# Needs Google Chrome (headless) and sips (macOS). The coin is backend/static/coin.svg — the website's
# logo and favicon — so the app icon and the website mark are the same file. Output:
#   assets/brand/coin.png                             in-app mark, transparent, 512px
#   ios/Runner/Assets.xcassets/AppIcon.appiconset/*   opaque dark tile, every size in Contents.json
#   android/.../mipmap-*/ic_launcher.png              legacy icon: the coin on transparent
#   android/.../mipmap-*/ic_launcher_foreground.png   adaptive-icon foreground (coin at 66%)
set -euo pipefail
cd "$(dirname "$0")/../.."
CHROME="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"
PAGE="file://$PWD/tool/icons/coin.html"
TMP="$(mktemp -d)"

shot() { # variant out
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --default-background-color=00000000 \
    --virtual-time-budget=5000 --window-size=1024,1024 --screenshot="$2" "$PAGE?variant=$1" 2>/dev/null
}
shot coin "$TMP/coin.png"
shot ios  "$TMP/ios.png"
shot fg   "$TMP/fg.png"

resize() { sips -z "$2" "$2" "$1" --out "$3" >/dev/null; }

mkdir -p assets/brand
resize "$TMP/coin.png" 512 assets/brand/coin.png

# iOS: every filename/size pair listed in Contents.json.
ICONSET=ios/Runner/Assets.xcassets/AppIcon.appiconset
python3 - "$ICONSET/Contents.json" <<'PY' | while read -r file px; do resize "$TMP/ios.png" "$px" "$ICONSET/$file"; done
import json, sys
for img in json.load(open(sys.argv[1]))["images"]:
    size = float(img["size"].split("x")[0]); scale = int(img["scale"].rstrip("x"))
    print(img["filename"], int(size * scale))
PY

# Android: legacy launcher icon plus adaptive foreground, per density.
RES=android/app/src/main/res
for pair in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d="${pair%%:*}"; px="${pair##*:}"
  resize "$TMP/coin.png" "$px" "$RES/mipmap-$d/ic_launcher.png"
  resize "$TMP/fg.png" "$((px * 108 / 48))" "$RES/mipmap-$d/ic_launcher_foreground.png"
done
rm -rf "$TMP"
echo "icons rendered"
