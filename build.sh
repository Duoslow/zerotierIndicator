#!/bin/bash
set -e
cd "$(dirname "$0")"

# Rebuilt from scratch: zip -r would otherwise merge into the existing archive
# and keep files that no longer exist in package/.
rm -f zerotier.plasmoid

if command -v zip >/dev/null 2>&1; then
    (cd package && zip -qr ../zerotier.plasmoid .)
else
    # zip is not installed everywhere; python ships a zip writer.
    python3 -c '
import os, zipfile
with zipfile.ZipFile("zerotier.plasmoid", "w", zipfile.ZIP_DEFLATED) as archive:
    for folder, _, files in os.walk("package"):
        for name in files:
            path = os.path.join(folder, name)
            archive.write(path, os.path.relpath(path, "package"))
'
fi

echo "Built zerotier.plasmoid"
echo "Install with: kpackagetool6 -t Plasma/Applet --install zerotier.plasmoid"
