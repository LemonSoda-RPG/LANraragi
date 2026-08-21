#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: build-bottle.sh

Build and test a Homebrew bottle from the current checkout without touching
the currently running LANraragi service.

Environment variables:
  LANRARAGI_BREW_TAP       Homebrew tap to use (owner/repository)
  LANRARAGI_BOTTLE_DIR     Output directory for the bottle files
  LRR_BOTTLE_TEST_PORT     Port used by the isolated package smoke test
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi
if [[ $# -gt 0 ]]; then
  echo "Unknown option: $1" >&2
  usage >&2
  exit 2
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source_formula="${repo_root}/tools/build/homebrew/Lanraragi.rb"
source_launcher="${repo_root}/tools/build/homebrew/lanraragi"
source_env_example="${repo_root}/tools/build/homebrew/lanraragi.env.example"
user_env="${XDG_CONFIG_HOME:-${HOME}/.config}/lanraragi/lanraragi.env"
brew_env=(env HOMEBREW_NO_AUTO_UPDATE=1 HOMEBREW_DEVELOPER=1)
bottle_dir="${LANRARAGI_BOTTLE_DIR:-${repo_root}}"
bottle_test_port="${LRR_BOTTLE_TEST_PORT:-3301}"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install it from https://brew.sh/" >&2
  exit 1
fi

brew_prefix="$(brew --prefix)"
brew_env_example="${brew_prefix}/etc/lanraragi.env.example"

# Reuse the same local tap as the normal rebuild workflow.
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

for required_file in "${source_formula}" "${source_launcher}" "${source_env_example}"; do
  if [[ ! -f "${required_file}" ]]; then
    echo "Required file not found: ${required_file}" >&2
    exit 1
  fi
done

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
  mkdir -p "$(dirname "${user_env}")"
  cp "${source_env_example}" "${user_env}"
fi

echo "Building Homebrew bottle contents without restarting LANraragi..."
if brew list --versions lanraragi >/dev/null 2>&1; then
  "${brew_env[@]}" brew reinstall --HEAD --build-bottle "${formula}"
else
  "${brew_env[@]}" brew install --HEAD --build-bottle "${formula}"
fi

echo "Validating the bottle build on an isolated port..."
(
  export LRR_NETWORK="http://127.0.0.1:${bottle_test_port}"
  "${brew_env[@]}" brew test --verbose "${formula}"
)

mkdir -p "${bottle_dir}"
echo "Generating Homebrew bottle in ${bottle_dir}..."
(
  cd "${bottle_dir}"
  "${brew_env[@]}" brew bottle --json "${formula}"
)

echo "Bottle files are in ${bottle_dir}"
echo "The running LANraragi service was not stopped or restarted."
