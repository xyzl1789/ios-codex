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
t = t.replace(
    'use supports_color::Stream;',
    'use supports_color::Stream;\n\n#[cfg(all(target_os = \"ios\", target_arch = \"aarch64\"))]\n#[unsafe(no_mangle)]\npub extern \"C\" fn __chkstk_darwin() {}',
    1
)
open('cli/src/main.rs','w').write(t)
print('  .. __chkstk_darwin inserted')
"
fi

# === process-hardening: disable ALL hardening on iOS ===
python3 -c "
p = 'process-hardening/src/lib.rs'
t = open(p).read()

# Remove any stale 'target_os = ios' lines (cleanup from prior patches)
t = t.replace('    target_os = \\\"ios\\\",\n', '')
# If ios was added inline like 'macos\"\n    target_os = \"ios\"' remove it
t = t.replace('\n    target_os = \"ios\",', '')

# Add #[cfg(not(target_os = \"ios\"))] to pre_main_hardening_linux
t = t.replace(
    '#[cfg(any(target_os = \"linux\", target_os = \"android\"))]\npub(crate) fn pre_main_hardening_linux() {',
    '#[cfg(all(not(target_os = \"ios\"), any(target_os = \"linux\", target_os = \"android\")))]\npub(crate) fn pre_main_hardening_linux() {'
)
# Guard pre_main_hardening_macos
t = t.replace(
    '#[cfg(target_os = \"macos\")]\npub(crate) fn pre_main_hardening_macos() {',
    '#[cfg(all(target_os = \"macos\", not(target_os = \"ios\")))]\npub(crate) fn pre_main_hardening_macos() {'
)
# Guard pre_main_hardening_bsd
t = t.replace(
    '#[cfg(any(target_os = \"freebsd\", target_os = \"openbsd\"))]\npub(crate) fn pre_main_hardening_bsd() {',
    '#[cfg(all(not(target_os = \"ios\"), any(target_os = \"freebsd\", target_os = \"openbsd\")))]\npub(crate) fn pre_main_hardening_bsd() {'
)

open(p,'w').write(t)
print('  .. hardening disabled on ios')
"

echo "[ios-codex] patches applied"
