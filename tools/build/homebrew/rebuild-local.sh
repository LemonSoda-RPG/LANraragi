#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tap_formula="/opt/homebrew/Library/Taps/jiacheng/homebrew-lanraragi-local/Formula/lanraragi.rb"
source_formula="${repo_root}/tools/build/homebrew/Lanraragi.rb"
source_launcher="${repo_root}/tools/build/homebrew/lanraragi"
source_env_example="${repo_root}/tools/build/homebrew/lanraragi.env.example"
brew_env_example="/opt/homebrew/etc/lanraragi.env.example"
user_env="${XDG_CONFIG_HOME:-${HOME}/.config}/lanraragi/lanraragi.env"
local_head="head \"file://${repo_root}/.git\", using: :git, branch: \"dev\""
formula="jiacheng/lanraragi-local/lanraragi"
brew_env=(env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_DEVELOPER=1)

if [[ ! -f "${source_formula}" ]]; then
  echo "Formula not found: ${source_formula}" >&2
  exit 1
fi

if [[ ! -f "${source_launcher}" ]]; then
  echo "Launcher not found: ${source_launcher}" >&2
  exit 1
fi

if [[ ! -f "${source_env_example}" ]]; then
  echo "Env template not found: ${source_env_example}" >&2
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

echo "Syncing runtime env template..."
mkdir -p "$(dirname "${brew_env_example}")"
cp "${source_env_example}" "${brew_env_example}"
if [[ ! -f "${user_env}" ]]; then
  echo "Creating user runtime env file at ${user_env}..."
  mkdir -p "$(dirname "${user_env}")"
  cp "${source_env_example}" "${user_env}"
fi

if brew list --versions lanraragi >/dev/null 2>&1; then
  installed_versions="$(brew list --versions lanraragi)"
  if [[ "${installed_versions}" == *"HEAD-"* ]]; then
    echo "Rebuilding installed LANraragi HEAD from local source..."
    "${brew_env[@]}" brew reinstall --build-from-source "${formula}"
  else
    echo "LANraragi is installed as a stable build; switching it to local HEAD..."
    "${brew_env[@]}" brew uninstall --force lanraragi
    "${brew_env[@]}" brew install --HEAD --build-from-source "${formula}"
  fi
else
  echo "Installing LANraragi HEAD from local source..."
  "${brew_env[@]}" brew install --HEAD --build-from-source "${formula}"
fi

if [[ -f /opt/homebrew/opt/lanraragi/bin/lanraragi ]]; then
  echo "Syncing launcher into current Homebrew install..."
  chmod u+w /opt/homebrew/opt/lanraragi/bin/lanraragi
  cp "${source_launcher}" /opt/homebrew/opt/lanraragi/bin/lanraragi
  chmod 555 /opt/homebrew/opt/lanraragi/bin/lanraragi
fi

echo "Restarting LANraragi service..."
brew services restart "${formula}"

echo "Done. Open http://127.0.0.1:3000"
