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

# 4. __chkstk_darwin: C stub + cc build-dep + build.rs integration
#    C deps (ring, onig_sys, zstd_sys) reference __chkstk_darwin from
#    their own .o files, so the symbol must come from a C object file.

cat <<'CEOF' > cli/src/ios_chkstk.c
#include <stddef.h>

void __chkstk_darwin(void) {}
CEOF

# 4b. Add cc = "1" to [build-dependencies] if not present
if ! grep -qF 'cc =' cli/Cargo.toml 2>/dev/null; then
  if grep -q '^\[build-dependencies\]' cli/Cargo.toml; then
    sed -i '' '/^\[build-dependencies\]/a\
cc = "1"
' cli/Cargo.toml
  else
    # insert before [[bin]] or at end
    python3 -c "
import re
t = open('cli/Cargo.toml').read()
if '[[bin]]' in t:
    t = t.replace('[[bin]]', '[build-dependencies]\ncc = \"1\"\n\n[[bin]]', 1)
else:
    t = t.rstrip() + '\n\n[build-dependencies]\ncc = \"1\"\n'
open('cli/Cargo.toml','w').write(t)
"
  fi
fi

# 4c. Patch build.rs — prepend helper module + insert call into existing fn main()
if ! grep -q 'ios_chkstk' cli/build.rs 2>/dev/null; then
  # If build.rs has its own fn main(), keep it and just insert the call
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
    # build.rs exists but (unlikely) has no main — add one
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

echo "[ios-codex] patches applied"
