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

# 3. process-hardening: make pre_main_hardening a no-op on iOS.
#    macOS hardening (setrlimit, unveil, pledge etc.) does not work on
#    iOS and causes "Operation not permitted".  Replace the body with
#    an empty function.
python3 -c "
import re
p = 'process-hardening/src/lib.rs'
t = open(p).read()
# Replace the pub fn pre_main_hardening() body: remove all cfg-specific
# blocks and make it a no-op.
t = re.sub(
    r'pub fn pre_main_hardening\(\) \{[^}]+\}',
    'pub fn pre_main_hardening() {} /* iOS: no-op */',
    t,
    flags=re.DOTALL
)
open(p,'w').write(t)
" 

# 4. __chkstk_darwin: C stub + cc build-dep + build.rs integration
cat <<'CEOF' > cli/src/ios_chkstk.c
#include <stddef.h>

void __chkstk_darwin(void) {}
CEOF

if ! grep -qF 'cc =' cli/Cargo.toml 2>/dev/null; then
  if grep -q '^\[build-dependencies\]' cli/Cargo.toml; then
    sed -i '' '/^\[build-dependencies\]/a\
cc = "1"
' cli/Cargo.toml
  else
    python3 -c "
t = open('cli/Cargo.toml').read()
if '[[bin]]' in t:
    t = t.replace('[[bin]]', '[build-dependencies]\ncc = \"1\"\n\n[[bin]]', 1)
else:
    t = t.rstrip() + '\n\n[build-dependencies]\ncc = \"1\"\n'
open('cli/Cargo.toml','w').write(t)
"
  fi
fi

if ! grep -q 'ios_chkstk' cli/build.rs 2>/dev/null; then
  cat > /tmp/_codex_prefix.rs << 'BRSEOF'
#[cfg(all(target_os = "ios", target_arch = "aarch64"))]
mod __codex_ios {
    pub fn build() {
        cc::Build::new().file("src/ios_chkstk.c").compile("ios_chkstk");
    }
}

#[cfg(not(all(target_os = "ios", target_arch = "aarch64")))]
mod __codex_ios {
    pub fn build() {}
}
BRSEOF

  if grep -q '^fn main()' cli/build.rs; then
    sed -i '' '/^fn main()/a\
    __codex_ios::build();
' cli/build.rs
  else
    cat >> cli/build.rs << 'BRSEOF'

fn main() {
    __codex_ios::build();
}
BRSEOF
  fi

  cat /tmp/_codex_prefix.rs cli/build.rs > /tmp/_codex_build_combined.rs
  mv /tmp/_codex_build_combined.rs cli/build.rs
  rm -f /tmp/_codex_prefix.rs
fi

# 6. Suppress "Model metadata for ... not found" warning on third-party models
WARN_SRC="core/src/session/turn_context.rs"
if [ -f "$WARN_SRC" ]; then
  echo "  .. patching $WARN_SRC to suppress metadata warning"
  python3 -c "
import re
t = open('$WARN_SRC').read()
t = re.sub(
    r'if tc\\.model_info\\.is_fallback_metadata \\{[^}]*\\}',
    '/* iOS: third-party model fallback warning suppressed */',
    t,
    flags=re.DOTALL
)
open('$WARN_SRC','w').write(t)
"
fi

echo "[ios-codex] all patches applied"
