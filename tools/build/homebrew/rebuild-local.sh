#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tap_formula="/opt/homebrew/Library/Taps/jiacheng/homebrew-lanraragi-local/Formula/lanraragi.rb"
source_formula="${repo_root}/tools/build/homebrew/Lanraragi.rb"
local_head="head \"file://${repo_root}/.git\", using: :git, branch: \"dev\""
formula="jiacheng/lanraragi-local/lanraragi"

if [[ ! -f "${source_formula}" ]]; then
  echo "Formula not found: ${source_formula}" >&2
  exit 1
fi

if [[ ! -d "$(dirname "${tap_formula}")" ]]; then
  echo "Tap formula directory not found: $(dirname "${tap_formula}")" >&2
  echo "Run: brew tap jiacheng/lanraragi-local" >&2
  exit 1
fi

echo "Syncing Formula to local tap..."
cp "${source_formula}" "${tap_formula}"

echo "Pointing tap Formula HEAD to local source checkout..."
ruby -0pi -e "gsub(%q{head \"https://github.com/Difegue/LANraragi.git\", branch: \"dev\"}, %q{${local_head}})" "${tap_formula}"

if brew list --versions lanraragi >/dev/null 2>&1; then
  installed_versions="$(brew list --versions lanraragi)"
  if [[ "${installed_versions}" == *"HEAD-"* ]]; then
    echo "Rebuilding installed LANraragi HEAD from local source..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew reinstall --build-from-source "${formula}"
  else
    echo "LANraragi is installed as a stable build; switching it to local HEAD..."
    HOMEBREW_NO_AUTO_UPDATE=1 brew uninstall --force lanraragi
    HOMEBREW_NO_AUTO_UPDATE=1 brew install --HEAD --build-from-source "${formula}"
  fi
else
  echo "Installing LANraragi HEAD from local source..."
  HOMEBREW_NO_AUTO_UPDATE=1 brew install --HEAD --build-from-source "${formula}"
fi

echo "Restarting LANraragi service..."
brew services restart "${formula}"

echo "Done. Open http://127.0.0.1:3000"
