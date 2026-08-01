#!/bin/bash
set -e
cd upstream

# Apply the canonical iOS codex patch
git apply ../patches/0001-ios-codex.patch

echo "[ios-codex] patch applied"
