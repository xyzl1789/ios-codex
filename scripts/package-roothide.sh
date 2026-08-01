#!/bin/bash
# Package roothide deb from built binary.
# Usage: BIN=path/to/codex VERSION=x.y.z ./scripts/package-roothide.sh
set -e

RH=$(mktemp -d /tmp/roothide-pkg-XXXXXX)
trap 'rm -rf "$RH"' EXIT

mkdir -p "$RH/var/jb/DEBIAN"
mkdir -p "$RH/var/jb/usr/local/bin"
mkdir -p "$RH/var/jb/usr/local/libexec"
mkdir -p "$RH/var/jb/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex"
mkdir -p "$RH/var/jb/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/path"

# binary
cp "$BIN" "$RH/var/jb/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex"
chmod +x "$RH/var/jb/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex"

# launcher
cat > "$RH/var/jb/usr/local/bin/codex" << 'LSH'
#!/var/jb/usr/bin/sh
PREFIX="${JB_ROOT:-/var/jb}"
exec "${PREFIX}/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex" --instructions "你必须始终使用简体中文回复。所有对话、代码注释、说明文字均用中文。专有技术术语保留英文原词。" "$@"
LSH
chmod +x "$RH/var/jb/usr/local/bin/codex"

# rg shim
cat > "$RH/var/jb/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/path/rg" << 'RGEOF'
#!/bin/sh
exec grep -r "$@"
RGEOF
chmod +x "$RH/var/jb/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/path/rg"

# codex-update
cat > "$RH/var/jb/usr/local/bin/codex-update" << 'UPDEOF'
#!/var/jb/usr/bin/sh
echo "[ios-codex] update is handled via deb package; please install the latest .deb"
UPDEOF
chmod +x "$RH/var/jb/usr/local/bin/codex-update"

# codex-ios-repair
cat > "$RH/var/jb/usr/local/libexec/codex-ios-repair" << 'REPEOF'
#!/var/jb/usr/bin/sh
set -e
P="${JB_ROOT:-/var/jb}"
BIN="${P}/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex"
if [ -f "$BIN" ]; then
	ldid -S "$BIN" 2>/dev/null || true
	echo "[codex-ios] repaired"
fi
REPEOF
chmod +x "$RH/var/jb/usr/local/libexec/codex-ios-repair"

# postinst
cat > "$RH/var/jb/DEBIAN/postinst" << PE
#!/bin/sh
set -e
P="\${JB_ROOT:-/var/jb}"
BIN="\${P}/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex"
[ -f "\$BIN" ] && ldid -S "\$BIN" 2>/dev/null || true
echo "[codex-ios] roothide installed"
PE
chmod +x "$RH/var/jb/DEBIAN/postinst"

# postrm
cat > "$RH/var/jb/DEBIAN/postrm" << PR
#!/bin/sh
echo "[codex-ios] removing roothide Codex..."
rm -f /var/jb/usr/local/bin/codex 2>/dev/null
rm -f /var/jb/usr/local/bin/codex-update 2>/dev/null
rm -f /var/jb/usr/local/libexec/codex-ios-repair 2>/dev/null
rm -rf /var/jb/usr/local/lib/node_modules/@openai/codex 2>/dev/null
PR
chmod +x "$RH/var/jb/DEBIAN/postrm"

# control
cat > "$RH/var/jb/DEBIAN/control" << EOC
Package: com.openai.codex-ios
Name: Codex CLI iOS Port (roothide)
Version: ${VERSION}
Architecture: iphoneos-arm64e
Maintainer: xyzl
Author: xyzl
Section: Development
Priority: optional
Depends: firmware (>= 14.0)
Description: iOS port of OpenAI Codex CLI for roothide bootstrap.
 Cross-compiled codex-rs binary targeting aarch64-apple-ios.
EOC

mkdir -p dist
dpkg-deb -b "$RH/var/jb" "dist/com.openai.codex-roothide_${VERSION}_iphoneos-arm64e.deb"

rm -rf "$RH"
echo "[codex-ios] roothide deb done"
