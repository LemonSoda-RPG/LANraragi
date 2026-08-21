#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source_formula="${repo_root}/tools/build/homebrew/Lanraragi.rb"
source_launcher="${repo_root}/tools/build/homebrew/lanraragi"
source_env_example="${repo_root}/tools/build/homebrew/lanraragi.env.example"
user_env="${XDG_CONFIG_HOME:-${HOME}/.config}/lanraragi/lanraragi.env"
brew_env=(env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_DEVELOPER=1)

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install it from https://brew.sh/" >&2
  exit 1
fi

brew_prefix="$(brew --prefix)"
brew_env_example="${brew_prefix}/etc/lanraragi.env.example"

# Reuse an existing local tap when available. Otherwise create a self-contained
# tap so a fresh checkout does not require a separate tap repository.
existing_tap="$(brew tap | awk '/\/lanraragi-local$/ { print; exit }')"
brew_tap="${LANRARAGI_BREW_TAP:-${existing_tap:-local/lanraragi-local}}"
if [[ "${brew_tap}" != */* ]]; then
  echo "LANRARAGI_BREW_TAP must use the form owner/repository" >&2
  exit 1
fi

tap_owner="${brew_tap%%/*}"
tap_name="${brew_tap#*/}"
tap_root="${brew_prefix}/Library/Taps/${tap_owner}/homebrew-${tap_name}"
tap_formula="${tap_root}/Formula/lanraragi.rb"
formula="${brew_tap}/lanraragi"
local_head="head \"file://${repo_root}/.git\", using: :git, branch: \"dev\""

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

if [[ ! -d "${tap_root}" ]]; then
  echo "Creating local Homebrew tap ${brew_tap}..."
  "${brew_env[@]}" brew tap-new --no-git "${brew_tap}"
fi

if [[ ! -d "$(dirname "${tap_formula}")" ]]; then
  echo "Tap formula directory not found: $(dirname "${tap_formula}")" >&2
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

echo "Validating the installed Homebrew package..."
service_was_running=0
if brew services list | awk '$1 == "lanraragi" && $2 ~ /^started/ { found = 1 } END { exit !found }'; then
  service_was_running=1
  echo "Stopping the existing LANraragi service for package validation..."
  brew services stop "${formula}"
  sleep 2
fi

restore_service() {
  if [[ "${service_was_running}" == 1 ]]; then
    brew services restart "${formula}" >/dev/null 2>&1 || true
  fi
}

trap restore_service EXIT
"${brew_env[@]}" brew test --verbose "${formula}"
trap - EXIT

if [[ -f "${brew_prefix}/opt/lanraragi/bin/lanraragi" ]]; then
  echo "Syncing launcher into current Homebrew install..."
  chmod u+w "${brew_prefix}/opt/lanraragi/bin/lanraragi"
  cp "${source_launcher}" "${brew_prefix}/opt/lanraragi/bin/lanraragi"
  chmod 555 "${brew_prefix}/opt/lanraragi/bin/lanraragi"
fi

echo "Restarting LANraragi service..."
brew services restart "${formula}"

echo "Done. Homebrew tap: ${brew_tap}"
echo "Open http://127.0.0.1:3000"
