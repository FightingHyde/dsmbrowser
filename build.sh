#!/usr/bin/env bash
set -euo pipefail

PKG=DSMBrowser
VER="${PKG_VERSION:-1.0.0}"
NOVNC_VER="${NOVNC_VER:-v1.5.0}"
TARGET=/var/packages/$PKG/target
HERE=$(cd "$(dirname "$0")" && pwd)
WORK="$HERE/.work"
OUT="$HERE/dist"
ROOT="$WORK/root"
LOADER="$TARGET/bin/lib64/ld-linux-x86-64.so.2"
RPATH="$TARGET/bin/usr/lib/x86_64-linux-gnu:$TARGET/bin/lib/x86_64-linux-gnu"

PKGS="chromium xvfb x11vnc websockify python3-minimal noVNC \
 fonts-dejavu-core fontconfig libnss3 libgtk-3-0 libgbm1 libasound2 \
 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 libxkbcommon0 \
 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdrm2 libpango-1.0-0 \
 libcairo2 libexpat1 libxfixes3 libxext6 libxrender1 libxshmfence1 \
 libxcursor1 libxi6 libxtst6 libsm6 libice6 libxss1 libglib2.0-0 \
 libdbus-1-3 libsystemd0 libselinux1 libudev1 libnspr4 libfontconfig1 \
 libfreetype6 libavahi-client3 libavahi-common3"

echo ">> $PKG $VER"

for t in curl python3 tar dpkg file; do
  command -v "$t" >/dev/null || { echo "missing host tool: $t"; exit 1; }
done
if ! command -v patchelf >/dev/null 2>&1; then
  echo ">> installing patchelf"
  SUDO=""; [ "$(id -u)" = 0 ] || SUDO="sudo"
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq patchelf
fi

mkdir -p "$WORK/debs" "$OUT" "$HERE/pkg/web"
rm -rf "$ROOT"; mkdir -p "$ROOT"

# ---- 1. debs (cached or fetched) ----
mkdir -p "$WORK/debs"
count_debs() { find "$WORK/debs" -maxdepth 1 -name '*.deb' | wc -l; }

if [ "${REUSE_DEBS:-0}" = "1" ] && [ "$(count_debs)" -gt 0 ]; then
  echo ">> reusing $(count_debs) cached debs"
elif command -v docker >/dev/null 2>&1; then
  echo ">> fetching debs in debian:bookworm"
  docker run --rm -v "$WORK/debs:/debs" -w /debs debian:bookworm bash -euc '
    apt-get update -qq
    apt-get download \
      $(apt-cache depends --recurse --no-recommends --no-suggests \
          --no-conflicts --no-breaks --no-replaces --no-enhances \
          '"$PKGS"' | grep "^\w" | sort -u) > /dev/null
    find /debs -maxdepth 1 -name "*.deb" | wc -l'
else
  echo ">> fetching debs with local apt"
  SUDO=""; [ "$(id -u)" = 0 ] || SUDO="sudo"
  ( cd "$WORK/debs" && \
    $SUDO apt-get update -qq && \
    $SUDO apt-get download \
      $(apt-cache depends --recurse --no-recommends --no-suggests \
          --no-conflicts --no-breaks --no-replaces --no-enhances \
          $PKGS | grep '^\w' | sort -u) > /dev/null )
fi

n=$(count_debs)
[ "$n" -gt 0 ] || { echo "!! fetched 0 debs"; ls -la "$WORK/debs"; exit 1; }
echo ">> $n debs"

# ---- 2. extract ----
echo ">> extracting"
while IFS= read -r -d '' d; do dpkg-deb -x "$d" "$ROOT"; done \
  < <(find "$WORK/debs" -maxdepth 1 -name '*.deb' -print0)
[ -x "$ROOT/usr/bin/chromium" ] || { echo "no chromium binary in $ROOT"; exit 1; }

# ---- 3. rebase loader + rpath ----
echo ">> patchelf"
find "$ROOT" -type f \( -name '*.so' -o -name '*.so.*' -o -perm -u+x \) -print0 |
while IFS= read -r -d '' f; do
  file -b "$f" | grep -q '^ELF' || continue
  patchelf --set-rpath "$RPATH" "$f" 2>/dev/null || true
  patchelf --print-interpreter "$f" >/dev/null 2>&1 && \
    patchelf --set-interpreter "$LOADER" "$f" 2>/dev/null || true
done

# ---- 4. noVNC ----
echo ">> noVNC $NOVNC_VER"
curl -fsSL "https://github.com/novnc/noVNC/archive/refs/tags/$NOVNC_VER.tar.gz" -o "$WORK/novnc.tgz"
rm -rf "$WORK/noVNC-${NOVNC_VER#v}" "$HERE/pkg/web/novnc"
tar -xzf "$WORK/novnc.tgz" -C "$WORK"
mkdir -p "$HERE/pkg/web/novnc"
cp -a "$WORK/noVNC-${NOVNC_VER#v}/." "$HERE/pkg/web/novnc/"

# ---- 5. icons ----
echo ">> icons"
rm -rf "$HERE/pkg/ui/images"
python3 "$HERE/tools/make_icons.py" "$HERE/pkg/ui/images" "$HERE/pkg"

# ---- 6. stamp version, pack ----
echo "$VER" | grep -Eq '^[0-9]+(\.[0-9]+)*(-[0-9]+)?$' || { echo "bad version: $VER"; exit 1; }
sed -i '/^extractsize=/d' "$HERE/pkg/INFO"
sed -i "s/^version=.*/version=\"$VER\"/" "$HERE/pkg/INFO"

echo ">> packing"
rm -rf "$WORK/payload"; mkdir -p "$WORK/payload"
cp -a "$ROOT" "$WORK/payload/bin"
cp -a "$HERE/pkg/web" "$WORK/payload/web"
tar -czf "$HERE/pkg/package.tgz" -C "$WORK/payload" .
echo "extractsize=$(du -sk "$WORK/payload" | awk '{print $1}')" >> "$HERE/pkg/INFO"
chmod +x "$HERE/pkg/scripts/"*
rm -f "$OUT"/*.spk

# DSM's pkg_make_spk uses a PLAIN (uncompressed) tar for the outer .spk.
# A gzipped .spk is rejected with "Invalid file format."
( cd "$HERE/pkg" && tar --format=ustar -cf "$OUT/$PKG-$VER.spk" \
    INFO PACKAGE_ICON.PNG PACKAGE_ICON_256.PNG \
    conf etc package.tgz scripts ui )
echo
echo "done -> $OUT/$PKG-$VER.spk ($(du -h "$OUT/$PKG-$VER.spk" | cut -f1))"
