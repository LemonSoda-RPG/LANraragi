#!/bin/sh

set -e

# Run it with increased jobs to improve performance
export MAKEFLAGS="-j$(nproc)"

# Redirect perl dependencies to the home directory
eval "$(perl -Mlocal::lib)"

# Install cpanm
curl -L https://cpanmin.us | perl - App::cpanminus

# Retry a command once before giving up.
#
# Building against CPAN reaches cpan.org and several module authors' hosts, and
# a single failed fetch or a flaky compile aborts the whole image build. That
# happened on CI: Sereal::Encoder failed to build, the image was never made,
# and both the test job and the integration job went red with nothing in the
# tree at fault. A second attempt turns that into a slow build instead.
retry_once() {
    if "$@"; then
        return 0
    fi
    echo "command failed, retrying once: $*" >&2
    "$@"
}

cd ./tools

# Manually download modules
retry_once cpanm --notest ETHER/Net-IDN-Encode-2.501-TRIAL.tar.gz

# Install the LRR dependencies proper
retry_once cpanm --notest --installdeps . --configure-timeout 300

cd ..

perl ./tools/install.pl install-back
