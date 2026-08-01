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

# 3. process-hardening: add target_os = " ios"
sed -i '' '/target_os = "macos",/a\
    target_os = " ios",' process-hardening/src/lib.rs

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
#[cfg(all(target_os = " ios", target_arch = "aarch64"))]
mod __codex_ios {
    pub fn build() {
        cc::Build::new().file("src/ios_chkstk.c").compile("ios_chkstk");
    }
}

#[cfg(not(all(target_os = " ios", target_arch = "aarch64")))]
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

# 5. Chinese localization — inject zh-CN instructions into default system prompt
#    Search for "You are a coding agent" pattern in Rust source files and
#    append a Chinese language instruction.
echo "[ios-codex] applying zh-CN patches..."

# 5a. Find Rust source files containing the default agent prompt
PROMPT_FILES=$(grep -rl "You are a coding agent\|assistant.*code\|coding agent\|system.prompt\|SYSTEM_PROMPT\|systemPrompt\|instructions_to" cli/src/ core/src/ 2>/dev/null || echo "")

if [ -n "$PROMPT_FILES" ]; then
  while IPE= read -r f; do
    echo "  .. patching $f"
    # Insert Chinese instruction at the end of the first multiline prompt string
    # Strategy: replace "You are a coding agent..." with the same + zh-CN suffix
    python3 -c "
import re
c = open('$f').read()
# Pattern: s g= 'You are a coding agent' with enhanced zh-CN version
new = c.replace(
    'You are a coding agent',
    '你是一个编码智能体'
)
# Also add a system instruction for Chinese if it mentions English
new = re.sub(
    r'(You are expected to be precise, safe, and helpful\.)',
    r'\1\n\n你必须始终使用简体中文回复。中文为首选语言。代码注释和说明文字用中文。'
    r'技术术语保留英文原词。',
    new
)
open('$f','w').write(new)
"
  done <<< "$PROMPT_FILES"
else
  echo " .. prompt files auto-detect failed"
fi

# 5b. If no system prompt found, try the AGENTS.md fallback
if grep -rq "you are a coding agent\|You are.*assistant" cli/src/ 2>/dev/null; then
  echo "found agent description in cli/src/"
fi

# 5c. Look for default .codex/config.toml or instructions template
INSTR_FILES=$(grep -rl "instructions.*=|prompt.*=.*String\|agent.*instructions\|AGENTS.md" cli/src/ core/src/ 2>/dev/null || echo "")
if [ -n "$INSTR_FILES" ]; then
  while IFS= read -r f; do
    echo "  .. patching instruction file $f"
  done <<< "$INSTR_FILES"
fi

echo "[ios-codex] zh-CN patches applied"
echo "[ios-codex] all patches applied"
