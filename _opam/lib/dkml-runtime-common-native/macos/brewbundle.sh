#!/bin/sh
# Homebrew's bundle tap, needed for reproducible build auditing in
# crossplatform-functions.sh's install_reproducible_system_packages().
#
# Some environments like the Opam sandbox will stop Homebrew from auto-installing its own tap.
# But those environments do not mimic real Homebrew installation because 'brew bundle ...'
# is automatically installed per https://github.com/Homebrew/homebrew-bundle/tree/4756e4c4cf95485c5ea4da27375946c1dac2c71d#installation,
# and it is an "official" tap per
# https://github.com/Homebrew/brew/blob/master/Library/Homebrew/official_taps.rb#L11-L18 .
#
# So the mitigation is to:
# a) Place a source tarball of https://github.com/Homebrew/homebrew-bundle at
#    dl/homebrew-bundle.tar.gz. For opam, use extra-source:[] to download a Git
#    tarball without tripping over the sandbox firewall
# b) Recreate a local file git repository
# c) Use install_reproducible_system_packages's DKML_REPRODUCIBLE_SYSTEM_BREWFILE
#    environment variable to specify the Brewfile that will be present in the
#    current directory
#
# This is best-effort. No ./Brewfile is created if brew can't be located
# or brew can't run successfully.
#
# Test with: brew untap homebrew/bundle
set -eufx
if command -v brew; then
    install -d dl/homebrew-bundle
    tar xCfz dl/homebrew-bundle dl/homebrew-bundle.tar.gz --strip-components=1

    # shellcheck disable=SC2046
    eval $(brew shellenv)
    HOMEBREW_BREW_FILE="$(command -v brew)"
    HOMEBREW_LIBRARY="${HOMEBREW_REPOSITORY}/Library"
    HOMEBREW_PATH="$PATH"
    HOMEBREW_CACHE="$PWD/dl/homebrew-cache"
    export HOMEBREW_BREW_FILE HOMEBREW_PATH HOMEBREW_CACHE

    # Clone the Library which contains the Taps/
    # (and also Homebrew/ which is all the core scripts).
    # * [-a] will copy and continue even if there are errors (like dangling symlinks).
    install -d dl/homebrew
    cp -a "$HOMEBREW_LIBRARY" dl/homebrew/ || true
    HOMEBREW_LIBRARY="$PWD/dl/homebrew/Library"
    export HOMEBREW_LIBRARY

    # Install the tap manually by copying it. If we had used
    # 'brew tap homebrew/bundle [URL]' or more specifically
    # '/bin/bash "${HOMEBREW_LIBRARY}/Homebrew/brew.sh" tap homebrew/bundle [URL]'
    # then brew would try to update its own configuration repository to say the tap was installed.
    # It would fail with 'error: could not lock config file .git/config: Operation not permitted'
    # because we are in a sandbox. We would have to ignore that error even though the tap was installed.
    # too many sandbox permissions, even with a file:// URL).
    install -d "${HOMEBREW_LIBRARY}/Taps/homebrew"
    cp -rp dl/homebrew-bundle "${HOMEBREW_LIBRARY}/Taps/homebrew/"

    if /bin/bash "${HOMEBREW_LIBRARY}/Homebrew/brew.sh" bundle dump; then
        test -e Brewfile
    else
        echo '# This Brewfile is empty because brew bundle dump failed on the build machine' > Brewfile
    fi
fi
