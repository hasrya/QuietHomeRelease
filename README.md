# Quiet Home releases

Release files for Quiet Home, an ad-free home screen for the Fire TV Stick 4K Max. Quiet Home Installer (Android phone app) downloads from here.

| Path | Contents |
|---|---|
| `stable.json`, `beta.json` | Latest version on each channel, with SHA-256 of each file |
| `v<version>/` | `QuietHome.apk`, `quiethome-setup.sh`, `quiethome-undo.sh`, `SHA256SUMS` |

APK signing certificate SHA-256: `9dc2b9fcb71bec8463f6b2967f25595253a1ec07585b9b8d48eaccf9183dcfa6`

Published by [.github/workflows/publish.yml](.github/workflows/publish.yml): hourly, the newest tag on each channel (`vX.Y.Z` stable, `vX.Y.Z-beta` beta), or a version by hand from Actions > Publish > Run workflow. Needs the secret `SOURCE_KEY` (read-only deploy key on the source repo).
