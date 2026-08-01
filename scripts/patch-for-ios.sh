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

# 4. __chkstk_darwin: must be a C file linked into codex-cli.
#    Putting it in main.rs does NOT help — the C dependencies
#    (ring, onig_sys, zstd_sys) reference __chkstk_darwin from their
#    own .o files and the linker cannot resolve it across crate
#    boundaries.  A standalone C file + cc crate + build.rs is the
#    canonical fix.
cat <<'CEOF' > cli/src/ios_chkstk.c
#include <stddef.h>

void __chkstk_darwin(void) {}
CEOF

# 4b. Ensure codex-cli depends on the cc crate
if ! grep -qF '"cc"' cli/Cargo.toml; then
  sed -i '' '/^name = "codex-cli"$/a\
cc = "1"
' cli/Cargo.toml
fi

# 4c. Append a build.rs to codex-cli that compiles the stub on iOS aarch64.
#     Only append if ios_chkstk is not already referenced (idempotent).
if ! grep -q 'ios_chkstk' cli/build.rs 2>/dev/null; then
  cat >> cli/build.rs << 'BRSEOF'

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

fn main() {
    __codex_ios::build();
}
BRSEOF
fi

echo "[ios-codex] patches applied"
