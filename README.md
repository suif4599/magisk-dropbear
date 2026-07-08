# magisk-dropbear

Continuous Android packaging of [Dropbear SSH](https://github.com/mkj/dropbear),
distributed as a Magisk module.

This repository contains **packaging code only** — build scripts, a Magisk
module template, and a single small Android-specific patch. The Dropbear
source is **not** stored here. It is pulled in unmodified as a git submodule
under [dropbear/](dropbear/) at build time.

## What gets built

Statically-linked Android (aarch64-linux-android21) binaries:

| Binary           | Purpose                                  |
|------------------|------------------------------------------|
| `dropbear`       | SSH server                               |
| `dbclient`       | SSH client                               |
| `dropbearkey`    | Host / user key generator                |
| `dropbearconvert`| Key format converter                     |
| `scp`            | Secure copy (legacy protocol)            |

These are packaged into a Magisk module zip that installs into
`/system/bin/` and starts a dropbear server on boot (configurable port,
pubkey-only auth, host keys under `/data/adb/dropbear/`).

## Build

Requirements: Nix with flakes enabled.

```bash
git submodule update --init
bash scripts/build.sh
```

Output: `build-android/magisk-dropbear-v<version>.zip`.

To also push to a connected device over adb:

```bash
bash scripts/build.sh --push
```

### What `build.sh` does

1. Enters the cross-compile dev shell (`nix develop .#cross`) and runs
   [scripts/build-android.sh](scripts/build-android.sh), which applies the
   patch, configures, and builds the binaries.
2. Resets the `dropbear/` submodule to a pristine state — reverts the
   applied patch and drops all build outputs. This is the "revert patch"
   step that used to be done manually.
3. Runs [scripts/build-magisk.sh](scripts/build-magisk.sh) to assemble the
   zip from the magisk template + built binaries, with version strings
   rendered from upstream's most recent `DROPBEAR_*` tag.

## Patch against upstream

[patches/0001-android-stop-pubkey-perm-walk-at-authkeysdir.patch](patches/0001-android-stop-pubkey-perm-walk-at-authkeysdir.patch)

Dropbear walks the full directory chain checking permissions on every
pubkey auth attempt. On Android `/data` is group-writable (`drwxrwx--x`)
by design, so the walk fails before reaching the authorized_keys
directory. The patch adds an early stop at the configured
`-D <authorized_keys_dir>`.

The patch is applied inside the build and reverted before packaging —
the submodule is always left clean, which keeps upstream rebases trivial.

## Versioning

The module version follows upstream: every build reads the most recent
`DROPBEAR_<version>` tag from the submodule's git history and derives both
the human-readable version string (`v2026.92`) and the integer versionCode
(`20260092` = `YYYY * 10000 + minor`) from it.

To track a new upstream release:

```bash
git -C dropbear checkout <new-tag-or-commit>
git add dropbear
git commit -m "bump dropbear to <version>"
```

## License

This repository is **packaging only**. The Dropbear source retains its
own license; no copyright claim is made over it.

- **Packaging code** (everything in this repository except the `dropbear/`
  submodule) is Copyright (c) 2026 suif4599, under the MIT License — see
  [LICENSE](LICENSE).
- **Dropbear** is Copyright (c) 2002-2020 Matt Johnston (with portions
  copyright (c) 2004 Mihnea Stoenescu), under its own MIT-style license —
  see [dropbear/LICENSE](dropbear/LICENSE). That file also carries notices
  for third-party components statically linked into the binaries
  (LibTomCrypt, LibTomMath, OpenSSH, PuTTY, TweetNaCl).

See [NOTICE](NOTICE) for the full attribution summary. The Magisk module
zip bundles all relevant license texts under `legal/`.
