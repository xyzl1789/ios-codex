#!/bin/bash
set -e
cd upstream/codex-rs

# === arboard: remove wayland feature (sed, tolerant to line shifts) ===
sed -i '' 's/arboard = { version = "3", features = \["wayland-data-control"\] }/arboard = { version = "3" }/' Cargo.toml

# === Release profile: disable LTO, increase codegen-units ===
sed -i '' 's/^lto = .*/lto = "off"/' Cargo.toml
sed -i '' 's/^codegen-units = .*/codegen-units = 16/' Cargo.toml
# Cargo.toml already has strip = "symbols" (inherited)

# === cli/src/main.rs: __chkstk_darwin stub ===
if grep -q "__chkstk_darwin" cli/src/main.rs 2>/dev/null; then
  echo "  .. __chkstk_darwin already present"
else
  python3 -c "
import re
p = 'cli/src/main.rs'
t = open(p).read()
# Insert after the last 'use std::' line before the next section
t = t.replace(
    'use supports_color::Stream;',
    'use supports_color::Stream;\\n\\n#[cfg(all(target_os = \"ios\", target_arch = \"aarch64\"))]\\n#[unsafe(no_mangle)]\\npub extern \"C\" fn __chkstk_darwin() {}',
    1
)
open(p,'w').write(t)
print('  .. __chkstk_darwin inserted')
"
fi

# === process-hardening: add target_os = "ios" ===
# Add 'ios' to the cfg list for SET_RLIMIT_CORE_FAILED_EXIT_CODE (not pre_main_hardening)
python3 -c "
import re
p = 'process-hardening/src/lib.rs'
t = open(p).read()
# Insert 'target_os = \"ios\",' after 'target_os = \"macos\",' line
t = re.sub(
    r'(target_os = \"macos\",\n)',
    r'\1    target_os = \"ios\",\n',
    t,
    count=1
)
open(p,'w').write(t)
print('  .. target_os = ios inserted')
"

echo "[ios-codex] patches applied"
