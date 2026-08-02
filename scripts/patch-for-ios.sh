#!/bin/bash
set -e
cd upstream/codex-rs

# === arboard: remove wayland feature ===
sed -i '' 's/arboard = { version = "3", features = \["wayland-data-control"\] }/arboard = { version = "3" }/' Cargo.toml

# === Release profile: disable LTO, increase codegen-units ===
sed -i '' 's/^lto = .*/lto = "off"/' Cargo.toml
sed -i '' 's/^codegen-units = .*/codegen-units = 16/' Cargo.toml

# === cli/src/main.rs: __chkstk_darwin stub ===
if ! grep -q "__chkstk_darwin" cli/src/main.rs 2>/dev/null; then
  python3 -c "
t = open('cli/src/main.rs').read()
t = t.replace('use supports_color::Stream;', 'use supports_color::Stream;\n\n#[cfg(all(target_os = \"ios\", target_arch = \"aarch64\"))]\n#[unsafe(no_mangle)]\npub extern \"C\" fn __chkstk_darwin() {}', 1)
open('cli/src/main.rs','w').write(t)
"
fi

# === process-hardening: skip hardening on iOS ===
# Instead of patching lib.rs, just erase pre_main_hardening call from main.rs
# (simpler, no risk of breaking compile)
sed -i '' 's/codex_process_hardening::pre_main_hardening();/\/\* iOS: hardening disabled \*\/ if cfg!(not\(target_os = "ios"\)) { codex_process_hardening::pre_main_hardening(); }/' cli/src/main.rs

echo "[ios-codex] patches applied"
