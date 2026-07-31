# ios-codex

OpenAI Codex CLI iOS arm64 port — cross-compiled for jailbroken iOS devices.

## Builds

- **rootless** deb: `iphoneos-arm64` for rootless jailbreaks (Dopamine, palera1n rootless)
- **roothide** deb: `iphoneos-arm64e` for roothide bootstrap

## How it works

GitHub Actions macOS runner cross-compiles upstream [openai/codex](https://github.com/openai/codex) `codex-rs` Rust binary with `target = aarch64-apple-ios` and packages into `.deb`.

Patches applied:
- Remove `wayland-data-control` feature from `arboard` crate (not available on iOS)
- Add `target_os = "ios"` to process-hardening conditionals
- Add `__chkstk_darwin()` stub for iOS 13+ toolchain compatibility
- Disable LTO and increase codegen-units to avoid linker OOM

## Build Triggers
- Push to `main`
- Manual `workflow_dispatch`

## Install

```sh
dpkg -i com.openai.codex-rootless_*.deb   # rootless
dpkg -i com.openai.codex-roothide_*.deb   # roothide
uicache -r
```

## Author

xyzl
