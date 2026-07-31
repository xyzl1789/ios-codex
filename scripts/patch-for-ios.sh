#!/bin/bash
# Apply iOS-specific patches to upstream codex-rs.
# Run from repo root (upstream/ is a sibling).
set -e
cd upstream/codex-rs

# 1. arboard: remove wayland feature (not available on iOS)
sed -i '' 's/arboard = { version = "3", features = \["wayland-data-control"\] }/arboard = { version = "3" }/' Cargo.toml

# 2. Release profile: disable LTO and increase codegen-units
sed -i '' 's/^lto = .*/lto = "off"/' Cargo.toml
sed -i '' 's/^codegen-units = .*/codegen-units = 16/' Cargo.toml

# 3. process-hardening: add target_os = "ios"
sed -i '' '/target_os = "macos",/a\
    target_os = "ios",' process-hardening/src/lib.rs

# 4. cli/main.rs: add __chkstk_darwin stub
sig='use tracing_subscriber::EnvFilter;'
sed -i '' "/^${sig}$/a\\
\\
// iOS compat\\
#[cfg(all(target_os = \"ios\", target_arch = \"aarch64\"))]\\
#[unsafe(no_mangle)]\\
pub extern \"C\" fn __chkstk_darwin() {}" cli/src/main.rs

echo "[ios-codex] patches applied"
