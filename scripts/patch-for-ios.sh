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

# === process-hardening: add target_os = "ios" to cfg block ===
python3 -c "
path = 'process-hardening/src/lib.rs'
with open(path) as f:
    content = f.read()
old = '    target_os = \"macos\",\n    target_os = \"freebsd\",'
new = '    target_os = \"macos\",\n    target_os = \"ios\",\n    target_os = \"freebsd\",'
if old not in content:
    print('ERROR: expected adjacent macos/freebsd lines not found!')
    raise SystemExit(1)
content = content.replace(old, new, 1)
assert 'target_os = \"ios\"' in content, 'patch failed'
with open(path, 'w') as f:
    f.write(content)
print('ios target inserted into process-hardening cfg block')
"

echo "[ios-codex] patches applied"
