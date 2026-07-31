#!/bin/bash
# Package rootless deb from built binary.
# Usage: BIN=path/to/codex VERSION=x.y.z ./scripts/package-rootless.sh
set -e
ROOTLESS_PKG_DIR=$(mktemp -d /tmp/rootless-pkg-XXXXXX)
trap 'rm -rf "$ROOTLESS_PKG_DIR"' EXIT

cp -r packaging/debian/* "$ROOTLESS_PKG_DIR/"
cp "$BIN" "$ROOTLESS_PKG_DIR/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex"
chmod +x "$ROOTLESS_PKG_DIR/usr/local/lib/node_modules/@openai/codex/vendor/aarch64-apple-ios/codex/codex"

CONTROL="$ROOTLESS_PKG_DIR/DEBIAN/control"
sed -i '' "s/^Version:.*/Version: ${VERSION}/" "$CONTROL"
sed -i '' "s/^Maintainer:.*/Maintainer: xyzl/" "$CONTROL"
sed -i '' "s/^Author:.*/Author: xyzl/" "$CONTROL"
sed -i '' "s/^Architecture:.*/Architecture: iphoneos-arm64/" "$CONTROL"
sed -i '' "s/^Package:.*/Package: com.openai.codex-ios/" "$CONTROL"

mkdir -p dist
dpkg-deb -b "$ROOTLESS_PKG_DIR" "dist/com.openai.codex-rootless_${VERSION}_iphoneos-arm64.deb"

rm -rf "$ROOTLESS_PKG_DIR"
echo "[ios-codex] rootless deb done"
