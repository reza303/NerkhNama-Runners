#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$RUNNER_TEMP/encrypted-outputs"
# Only the owner can decrypt build logs or the allowlisted binary outputs.
# Source files, environment dumps and checkout credentials never enter the archive.
python3 - <<'PY'
import os, zipfile
from pathlib import Path
root=Path('app'); version=os.environ['APP_VERSION']; platform=os.environ['PLATFORM']; temp=Path(os.environ['RUNNER_TEMP'])
files=[temp/'build-private.log']
if platform=='mac':
    files += [root/f'widget/macos/dist/build-{version}/NetEhraz-macOS.zip',root/f'widget/macos/dist/build-{version}/SHA256SUMS.txt',root/f'widget/macos/dist/dmg-{version}/NerkhNama.dmg',root/f'widget/macos/dist/dmg-{version}/dmg-release.json',root/f'widget/macos/dist/dmg-{version}/installation-smoke.json']
else:
    files += [root/'widget/windows/dist/NerkhNama.exe',root/'widget/windows/dist/SHA256SUMS.txt']
with zipfile.ZipFile(temp/'native-outputs.zip','w',zipfile.ZIP_STORED) as z:
    for p in files:
        if p.is_file() and not p.is_symlink():
            z.write(p, 'diagnostics/build.log' if p==temp/'build-private.log' else p.relative_to(root).as_posix())
PY
password_file="$RUNNER_TEMP/native-password"
umask 077
openssl rand -base64 48 > "$password_file"
trap 'rm -f "$password_file" "$RUNNER_TEMP/native-outputs.zip"' EXIT
openssl enc -aes-256-cbc -salt -pbkdf2 -iter 200000 -pass "file:$password_file" -in "$RUNNER_TEMP/native-outputs.zip" -out "$RUNNER_TEMP/encrypted-outputs/native.zip.enc"
openssl pkeyutl -encrypt -pubin -inkey runner/diagnostic-public.pem -in "$password_file" -out "$RUNNER_TEMP/encrypted-outputs/native-password.enc" -pkeyopt rsa_padding_mode:oaep -pkeyopt rsa_oaep_md:sha256
