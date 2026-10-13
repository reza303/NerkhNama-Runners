#!/usr/bin/env bash
set -euo pipefail
cd app
if [[ "$PLATFORM" == mac ]]; then
  bash widget/macos/build.sh "$APP_VERSION"
  python3 -m venv "$RUNNER_TEMP/dmg-tools"
  source "$RUNNER_TEMP/dmg-tools/bin/activate"
  python3 -m pip install dmgbuild==1.6.7 ds-store==1.3.3 mac-alias==2.2.3
  archive="$PWD/widget/macos/dist/build-$APP_VERSION/NetEhraz-macOS.zip"
  checksum="$(shasum -a 256 "$archive" | cut -d ' ' -f 1)"
  bash widget/macos/scripts/build-dmg.sh "$APP_VERSION" "$archive" "$checksum"
  python3 widget/macos/scripts/test-installed-app.py "widget/macos/dist/dmg-$APP_VERSION/NerkhNama.dmg" "$APP_VERSION"
else
  cd widget/windows
  go test -race -count=1 ./...
  go vet -unsafeptr=false ./...
  mkdir -p dist
  go build -trimpath -ldflags='-H windowsgui -s -w' -o dist/NerkhNama.exe .
  (cd dist && sha256sum NerkhNama.exe > SHA256SUMS.txt)
fi
