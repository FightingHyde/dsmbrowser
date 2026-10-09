![build](https://github.com/USER/REPO/actions/workflows/build.yml/badge.svg)

## Download a build
Every push to `main` produces an artifact under **Actions → build → latest run**.
Tagging `v1.0.0` publishes a GitHub **Release** with the `.spk` and its `.sha256`.

## Build in CI
Nothing to set up — the workflow installs `patchelf`, caches the Debian `.deb`
closure between runs, builds, and verifies the archive contains `INFO`,
`package.tgz` and `bin/usr/bin/chromium` before uploading.
# DSMBrowser — native Chromium for Synology DSM

Builds a `.spk` that runs Chromium natively on the NAS (bundled glibc, Xvfb,
x11vnc, websockify, noVNC) and displays it inside a DSM desktop window.

## Build
  ./build.sh            # needs curl, python3, tar, dpkg; docker or a Debian host
  -> dist/DSMBrowser-1.0.0.spk

## Install
1. Package Center -> Manual Install -> DSMBrowser-1.0.0.spk
2. Start the package.
3. Control Panel -> Login Portal -> Advanced -> Reverse Proxy, add:
     source:      HTTPS  5001  /ws
     destination: HTTP   localhost  6080  /
4. Main Menu -> right-click "DSM Browser" -> Add to desktop.

## Notes
- Chromium runs as root, hence --no-sandbox.
- Edit pkg/etc/dsbrowser.conf for display size / start page.