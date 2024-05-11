#!/bin/sh
# ----------------------------
# Copyright 2021 Diskuv, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------
#
# @jonahbeckford: 2021-09-07
# - This file is licensed differently than the rest of the DkML distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
######################################
# crossplatform-functions.sh
#
# Meant to be `source`-d.
#
# Can be run within a container or outside of a container.
#

export SHARE_OCAML_OPAM_REPO_RELPATH=share/dkml/repro
export SHARE_REPRODUCIBLE_BUILD_RELPATH=share/dkml/repro
export SHARE_FUNCTIONS_RELPATH=share/dkml/functions

# Prefer dash if it is there because it is average 4x faster than bash and should
# be much more secure. Otherwise /bin/sh which should always be a POSIX
# compatible shell.
#
# Output:
#   - env:DKML_POSIX_SHELL - The path to the POSIX shell. Only set if it wasn't already
#     set.
#   - env:DKML_HOST_POSIX_SHELL - The host's path to the POSIX shell. Only set if it wasn't already
#     set. On a Windows host (Cygwin/MSYS2) this will be a Windows path; on Unix this will be a Unix
#     path.
# References:
#   - https://unix.stackexchange.com/questions/148035/is-dash-or-some-other-shell-faster-than-bash
autodetect_posix_shell() {
    export DKML_POSIX_SHELL
    export DKML_HOST_POSIX_SHELL
    if [ -n "${DKML_POSIX_SHELL:-}" ] && [ -n "${DKML_HOST_POSIX_SHELL}" ]; then
        return
    # On MSYS2 especially, binaries look like they exist simultaneously in /usr/bin and /bin but
    # only if you are inside MSYS2. The binaries in /bin are in fact a mount of /usr/bin.
    # This is a critical problem for `opam exec -- /bin/dash.exe` which will fail because Opam cannot
    # see the mount.
    elif [ -e /usr/bin/dash.exe ]; then
        DKML_POSIX_SHELL=/usr/bin/dash.exe
    elif [ -e /usr/bin/dash ]; then
        DKML_POSIX_SHELL=/usr/bin/dash
    elif [ -e /bin/dash.exe ]; then
        DKML_POSIX_SHELL=/bin/dash.exe
    elif [ -e /bin/dash ]; then
        DKML_POSIX_SHELL=/bin/dash
    elif [ -e /bin/sh.exe ]; then
        DKML_POSIX_SHELL=/bin/sh.exe
    else
        DKML_POSIX_SHELL=/bin/sh
    fi
    if [ -x /usr/bin/cygpath ]; then
        DKML_HOST_POSIX_SHELL=$(/usr/bin/cygpath -aw "$DKML_POSIX_SHELL")
    else
        DKML_HOST_POSIX_SHELL="$DKML_POSIX_SHELL"
    fi
}

# Set the parent directory of DiskuvOCamlHome.
#
# Always defined, even on Unix. It is your responsibility to check if it exists.
#
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
set_dkmlparenthomedir() {
    if [ -n "${LOCALAPPDATA:-}" ]; then
        DKMLPARENTHOME_BUILDHOST="$LOCALAPPDATA\\Programs\\DkML"
    else
        # shellcheck disable=SC2034
        DKMLPARENTHOME_BUILDHOST="${XDG_DATA_HOME:-$HOME/.local/share}/dkml"
    fi
}

set_default_dkmlnativedir() {
    if [ -n "${LOCALAPPDATA:-}" ]; then
        DKMLNATIVEDIR_BUILDHOST="$LOCALAPPDATA\\Programs\\DkMLNative"
    elif is_macos_build_machine; then
        DKMLNATIVEDIR_BUILDHOST="$HOME/Applications/DkMLNative"
    else
        # shellcheck disable=SC2034
        DKMLNATIVEDIR_BUILDHOST="${XDG_DATA_HOME:-$HOME/.local/share}/dkml-native"
    fi
}

# Detects DkML and sets its variables.
#
# If the environment variables already exist they are not overwritten.
# Setting these variables is useful for example _during_ a deployment, where the
# version of dkmlvars.sh in the filesystem is either pre-deployment (too old) or not present.
#
# Inputs:
# - env:DiskuvOCamlVarsVersion - optional
# - env:DiskuvOCamlHome - optional
# - env:DiskuvOCamlBinaryPaths - optional
# - env:DiskuvOCamlDeploymentId - optional
# - env:DiskuvOCamlVersion - optional
# - env:DiskuvOCamlMSYS2Dir - optional
# - env:DiskuvOCamlForceDefaults - optional. if nonzero (defaults to 0) then uses defaults for DkML even if installed.
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:DKMLVERSION - set if DkML installed. The installed version number
# - env:DKMLHOME_BUILDHOST - set if DkML installed. Path will be in Windows (semicolon separated) or Unix (colon separated) format
# - env:DKMLHOME_UNIX - set if DkML installed. Path will be in Unix (colon separated) format
# - env:DKMLBINPATHS_BUILDHOST - set if DkML installed. Paths will be in Windows (semicolon separated) or Unix (colon separated) format
# - env:DKMLBINPATHS_UNIX - set if DkML installed. Paths will be in Unix (colon separated) format
# - env:DKMLMSYS2DIR_BUILDHOST - set if DkML installed MSYS2. Directory will be in Windows format
# Return Code:
# - 1 if the installed or overridden DkML is misconfigured. 0 if defaults were used or installed/overridden DkML is valid.
default_dkmlvars() {
    set_default_dkmlnativedir # Native is the default mode, not Bytecode
    autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override=2
    if [ -x /usr/bin/cygpath ]; then
        autodetect_dkmlvars_DiskuvOCamlHome_Override=$(/usr/bin/cygpath -a "$DKMLNATIVEDIR_BUILDHOST")
    else
        autodetect_dkmlvars_DiskuvOCamlHome_Override=$DKMLNATIVEDIR_BUILDHOST
    fi
    autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override="$autodetect_dkmlvars_DiskuvOCamlHome_Override/usr/bin;$autodetect_dkmlvars_DiskuvOCamlHome_Override/bin"
    autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override="default-592592597"
    autodetect_dkmlvars_DiskuvOCamlVersion_Override=2.1.1
    autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override=
}
autodetect_dkmlvars() {
    autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override=${DiskuvOCamlVarsVersion:-}
    autodetect_dkmlvars_DiskuvOCamlHome_Override=${DiskuvOCamlHome:-}
    autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override=${DiskuvOCamlBinaryPaths:-}
    autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override=${DiskuvOCamlDeploymentId:-}
    autodetect_dkmlvars_DiskuvOCamlVersion_Override=${DiskuvOCamlVersion:-}
    autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override=${DiskuvOCamlMSYS2Dir:-}
    autodetect_dkmlvars_DiskuvOCaml_ForceDefaults=${DiskuvOCamlForceDefaults:-0}

    set_dkmlparenthomedir

    # Init output vars
    DKMLVERSION=
    DKMLHOME_UNIX=
    DKMLHOME_BUILDHOST=
    DKMLBINPATHS_UNIX=
    DKMLBINPATHS_BUILDHOST=
    DKMLMSYS2DIR_BUILDHOST=

    if is_unixy_windows_build_machine; then
        if [ "${autodetect_dkmlvars_DiskuvOCaml_ForceDefaults:-}" = "0" ] && [ -e "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh" ]; then
            if [ -x /usr/bin/cygpath ]; then
                autodetect_dkmlvars_VARSSCRIPT=$(/usr/bin/cygpath -a "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh")
                # shellcheck disable=SC1090
                . "$autodetect_dkmlvars_VARSSCRIPT"
            else
                # shellcheck disable=SC1090
                . "$DKMLPARENTHOME_BUILDHOST\\dkmlvars.sh"
            fi
        else
            default_dkmlvars
        fi
    else
        if [ "${autodetect_dkmlvars_DiskuvOCaml_ForceDefaults:-}" = "0" ] && [ -e "$DKMLPARENTHOME_BUILDHOST/dkmlvars.sh" ]; then
            # shellcheck disable=SC1091
            . "$DKMLPARENTHOME_BUILDHOST/dkmlvars.sh"
        else
            default_dkmlvars
        fi
    fi
    # Overrides
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override:-}" ]; then DiskuvOCamlVarsVersion="$autodetect_dkmlvars_DiskuvOCamlVarsVersion_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlHome_Override:-}" ]; then DiskuvOCamlHome="$autodetect_dkmlvars_DiskuvOCamlHome_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override:-}" ]; then DiskuvOCamlBinaryPaths="$autodetect_dkmlvars_DiskuvOCamlBinaryPaths_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override:-}" ]; then DiskuvOCamlDeploymentId="$autodetect_dkmlvars_DiskuvOCamlDeploymentId_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlVersion_Override:-}" ]; then DiskuvOCamlVersion="$autodetect_dkmlvars_DiskuvOCamlVersion_Override"; fi
    if [ -n "${autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override:-}" ]; then DiskuvOCamlMSYS2Dir="$autodetect_dkmlvars_DiskuvOCamlMSYS2Dir_Override"; fi
    # Check if any vars are still unset (we do the Windows-specific DiskuvOCamlMSYS2Dir a bit later)
    if [ -z "${DiskuvOCamlVarsVersion:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlHome:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlBinaryPaths:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlDeploymentId:-}" ]; then return 1; fi
    if [ -z "${DiskuvOCamlVersion:-}" ]; then return 1; fi

    # Validate DiskuvOCamlVarsVersion. Can be v1 or v2 since only the .sexp file changed in v2.
    if [ ! "$DiskuvOCamlVarsVersion" = "1" ] && [ ! "$DiskuvOCamlVarsVersion" = "2" ]; then
        printf "FATAL: Only able to read DkML variables version '1' and '2'. Instead DkML variables for %s were on version '%s'\n" "$DiskuvOCamlHome" "$DiskuvOCamlVarsVersion" >&2
        exit 107
    fi

    # shellcheck disable=SC2034
    DKMLVERSION="$DiskuvOCamlVersion"

    # Unixize DiskuvOCamlHome
    if [ -x /usr/bin/cygpath ]; then
        DKMLHOME_UNIX=$(/usr/bin/cygpath -au "$DiskuvOCamlHome")
        DKMLHOME_BUILDHOST=$(/usr/bin/cygpath -aw "$DiskuvOCamlHome")
    else
        DKMLHOME_UNIX="$DiskuvOCamlHome"
        # shellcheck disable=SC2034
        DKMLHOME_BUILDHOST="$DiskuvOCamlHome"
    fi
    # Unixize DiskuvOCamlMSYS2Dir
    if is_unixy_windows_build_machine; then
        if [ -z "${DiskuvOCamlMSYS2Dir:-}" ]; then return 1; fi
        if [ -x /usr/bin/cygpath ]; then
            DKMLMSYS2DIR_BUILDHOST=$(/usr/bin/cygpath -aw "$DiskuvOCamlMSYS2Dir")
        else
            DKMLMSYS2DIR_BUILDHOST="$DiskuvOCamlMSYS2Dir"
        fi
    else
        # shellcheck disable=SC2034
        DKMLMSYS2DIR_BUILDHOST=
    fi

    # Pathize DiskuvOCamlBinaryPaths
    if [ -x /usr/bin/cygpath ]; then
        # Going from Windows to Unix is safe. Going from Unix to Windows is safe.
        # But Windows to Windows has garbled output from cygpath.
        DKMLBINPATHS_UNIX=$(/usr/bin/cygpath --path "$DiskuvOCamlBinaryPaths")
        DKMLBINPATHS_BUILDHOST=$(/usr/bin/cygpath -w --path "$DKMLBINPATHS_UNIX")
    else
        DKMLBINPATHS_UNIX="$DiskuvOCamlBinaryPaths"
        # shellcheck disable=SC2034
        DKMLBINPATHS_BUILDHOST="$DiskuvOCamlBinaryPaths"
    fi

    return 0
}

# Set OCAMLHOME and OPAMHOME if part of DKML system installation.
autodetect_ocaml_and_opam_home() {
    # Set DKMLHOME_UNIX
    autodetect_dkmlvars || true

    # Set OCAMLHOME and OPAMHOME from DKMLHOME
    OCAMLHOME=
    OPAMHOME=
    if [ -n "$DKMLHOME_UNIX" ]; then
        if [ -x "$DKMLHOME_UNIX/usr/bin/ocaml" ] || [ -x "$DKMLHOME_UNIX/usr/bin/ocaml.exe" ]; then
            OCAMLHOME=$DKMLHOME_UNIX
        elif [ -x "$DKMLHOME_UNIX/bin/ocaml" ] || [ -x "$DKMLHOME_UNIX/bin/ocaml.exe" ]; then
            # shellcheck disable=SC2034
            OCAMLHOME=$DKMLHOME_UNIX
        fi
        if [ -x "$DKMLHOME_UNIX/usr/bin/opam" ] || [ -x "$DKMLHOME_UNIX/usr/bin/opam.exe" ]; then
            OPAMHOME=$DKMLHOME_UNIX
        elif [ -x "$DKMLHOME_UNIX/bin/opam" ] || [ -x "$DKMLHOME_UNIX/bin/opam.exe" ]; then
            # shellcheck disable=SC2034
            OPAMHOME=$DKMLHOME_UNIX
        fi
    fi
}

__autodetect_system_path_push_git() {
    # Add Git at beginning of PATH
    autodetect_system_path_GITEXE=$(command -v git || true)
    if [ -n "$autodetect_system_path_GITEXE" ]; then
        autodetect_system_path_GITDIR=$(PATH=/usr/bin:/bin dirname "$autodetect_system_path_GITEXE")
        case "$autodetect_system_path_GITDIR" in
            /usr/bin|/bin)
                # __autodetect_system_path_push_usr_bin is responsible for
                # /usr/bin and /bin
                ;;
            *)
                # Handle Scoop which places bash.exe in the same directory as
                # git.exe.
                # Confer: https://github.com/diskuv/dkml-installer-ocaml/issues/34
                # Example:
                #    ~/scoop/shims/git.exe
                #    ~/scoop/shims/bash.exe
                # but need the better directory:
                #    ~/scoop/apps/git/current/cmd/git.exe
                #    <no bash.exe!>
                autodetect_system_path_GITGRANDDIR=$(PATH=/usr/bin:/bin dirname "$autodetect_system_path_GITDIR")
                if [ -x "$autodetect_system_path_GITGRANDDIR/apps/git/current/cmd/git.exe" ]; then
                    autodetect_system_path_GITDIR="$autodetect_system_path_GITGRANDDIR/apps/git/current/cmd"
                fi
                # Add to DKML_SYSTEM_PATH
                if [ -n "${DKML_SYSTEM_PATH:-}" ]; then
                    DKML_SYSTEM_PATH="$autodetect_system_path_GITDIR:$DKML_SYSTEM_PATH"
                else
                    DKML_SYSTEM_PATH="$autodetect_system_path_GITDIR"
                fi
        esac
    fi
}
__autodetect_system_path_push_usr_bin() {
    __autodetect_system_path_push_usr_bin_PATH=

    if is_cygwin_build_machine; then
        __autodetect_system_path_push_usr_bin_PATH=/usr/bin:/bin
    elif is_msys2_msys_build_machine; then
        # /bin is a mount (essentially a symlink) to /usr/bin on MSYS2
        __autodetect_system_path_push_usr_bin_PATH=/usr/bin
    else
        __autodetect_system_path_push_usr_bin_PATH=/usr/bin:/bin
    fi

    if [ -n "${DKML_SYSTEM_PATH:-}" ]; then
        DKML_SYSTEM_PATH="$__autodetect_system_path_push_usr_bin_PATH:$DKML_SYSTEM_PATH"
    else
        DKML_SYSTEM_PATH="$__autodetect_system_path_push_usr_bin_PATH"
    fi
}

__autodetect_system_path_helper() {
    __autodetect_system_path_helper_ORDER=$1
    shift

    export DKML_SYSTEM_PATH
    if [ -x /usr/bin/cygpath ]; then
        autodetect_system_path_SYSDIR=$(/usr/bin/cygpath --sysdir)
        autodetect_system_path_WINDIR=$(/usr/bin/cygpath --windir)
        # folder 38 = C:\Program Files typically
        autodetect_system_path_PROGRAMFILES=$(/usr/bin/cygpath --folder 38)
    fi

    if is_cygwin_build_machine || is_msys2_msys_build_machine; then
        DKML_SYSTEM_PATH=$autodetect_system_path_PROGRAMFILES/PowerShell/7:$autodetect_system_path_SYSDIR:$autodetect_system_path_WINDIR:$autodetect_system_path_SYSDIR/Wbem:$autodetect_system_path_SYSDIR/WindowsPowerShell/v1.0:$autodetect_system_path_SYSDIR/OpenSSH
    else
        DKML_SYSTEM_PATH=
        # RHEL has a Developer Toolset which should be in the path for things
        # like the latest GCC compilers. It is used, for example, by dockcross Linux.
        # Confer: https://access.redhat.com/documentation/en-us/red_hat_developer_toolset/12/html/12.0_release_notes/index
        if [ -e /opt/rh ]; then
            for __autodetect_system_path_helper_I in 19 18 17 16 15 14 13 12 11 10 9 8 7 6 4; do
                if [ -d /opt/rh/devtoolset-$__autodetect_system_path_helper_I/root/usr/bin ]; then
                    DKML_SYSTEM_PATH=/opt/rh/devtoolset-$__autodetect_system_path_helper_I/root/usr/bin
                    break
                fi
            done
        fi
    fi

    case "$__autodetect_system_path_helper_ORDER" in
        USR_BIN_FIRST)
            __autodetect_system_path_push_git
            __autodetect_system_path_push_usr_bin
            ;;
        *)
            __autodetect_system_path_push_usr_bin
            __autodetect_system_path_push_git
    esac

    # Set DKMLHOME_UNIX if available
    autodetect_dkmlvars || true

    # Add $DKMLHOME_UNIX/bin at beginning of PATH
    if [ -n "${DKMLHOME_UNIX:-}" ] && [ -d "$DKMLHOME_UNIX/bin" ]; then
        DKML_SYSTEM_PATH="$DKMLHOME_UNIX/bin:$DKML_SYSTEM_PATH"
    fi
}

# Get a path that has system binaries, and Git, and nothing else.
#
# Purpose: Use whenever you have something meant to be reproducible.
#
# On Windows this includes the Cygwin/MSYS2 paths, the  but also Windows directories
# like C:\Windows\System32 and C:\Windows\System32\OpenSSH and Powershell directories and
# also the essential binaries in $env:DiskuvOCamlHome\bin. The general binaries in $env:DiskuvOCamlHome\usr\bin are not
# included.
#
# Output:
#   env:DKML_SYSTEM_PATH - A PATH containing only system directories like /usr/bin.
#      The path will be in Unix format (so a path on Windows MSYS2 could be /c/Windows/System32)
autodetect_system_path() {
    __autodetect_system_path_helper USR_BIN_FIRST
}

# Get a path that has system binaries, and Git, and nothing else.
#
# Purpose: Use whenever you have something meant to be reproducible.
# This function places Git before /usr/bin in the PATH. This is rarely a good idea
# because, on Windows, package managers like Chocolately and Scoop place
# git.exe and bash.exe in the same directory; that means their bash.exe can
# easily conflict with whatever shell (ex. MSYS2 bash) that runs this script.
#
# The only situation where it makes sense is if you know you must use the
# system git (ex. Git for Windows). In that situation you don't want any
# private git (ex. MSYS2 from DkML) to be used if present (that would
# happen if you used `autodetect_system_path`).
#
# On Windows this includes the Cygwin/MSYS2 paths, the  but also Windows directories
# like C:\Windows\System32 and C:\Windows\System32\OpenSSH and Powershell directories and
# also the essential binaries in $env:DiskuvOCamlHome\bin. The general binaries in $env:DiskuvOCamlHome\usr\bin are not
# included.
#
# Output:
#   env:DKML_SYSTEM_PATH - A PATH containing only system directories like /usr/bin.
#      The path will be in Unix format (so a path on Windows MSYS2 could be /c/Windows/System32)
autodetect_system_path_with_git_before_usr_bin() {
    __autodetect_system_path_helper GIT_FIRST
}

# Get standard locations of Unix system binaries like `/usr/bin/mv` (or `/bin/mv`).
#
# Will not return anything in `/usr/local/bin` or `/usr/sbin`. Use when you do not
# know whether the PATH has been set correctly, or when you do not know if the
# system binary exists.
#
# At some point in the future, this function will error out if the required system binaries
# do not exist. Most system binaries are common to all Unix/Linux/macOS installations but
# some (like `comm`) may need to be installed for proper functioning of DKML.
#
# Outputs:
# - env:DKMLSYS_MV - Location of `mv`
# - env:DKMLSYS_CHMOD - Location of `chmod`
# - env:DKMLSYS_UNAME - Location of `uname`
# - env:DKMLSYS_ENV - Location of `env`
# - env:DKMLSYS_AWK - Location of `awk`
# - env:DKMLSYS_SED - Location of `sed`
# - env:DKMLSYS_COMM - Location of `comm`
# - env:DKMLSYS_INSTALL - Location of `install`
# - env:DKMLSYS_RM - Location of `rm`
# - env:DKMLSYS_SORT - Location of `sort`
# - env:DKMLSYS_CAT - Location of `cat`
# - env:DKMLSYS_STAT - Location of `stat`
# - env:DKMLSYS_GREP - Location of `grep`
# - env:DKMLSYS_CURL - Location of `curl` (empty if not found)
# - env:DKMLSYS_WGET - Location of `wget` (empty if not found)
# - env:DKMLSYS_TR - Location of `tr`
autodetect_system_binaries() {
    if [ -z "${DKMLSYS_MV:-}" ]; then
        if [ -x /usr/bin/mv ]; then
            DKMLSYS_MV=/usr/bin/mv
        else
            DKMLSYS_MV=/bin/mv
        fi
    fi
    if [ -z "${DKMLSYS_CHMOD:-}" ]; then
        if [ -x /usr/bin/chmod ]; then
            DKMLSYS_CHMOD=/usr/bin/chmod
        else
            DKMLSYS_CHMOD=/bin/chmod
        fi
    fi
    if [ -z "${DKMLSYS_UNAME:-}" ]; then
        if [ -x /usr/bin/uname ]; then
            DKMLSYS_UNAME=/usr/bin/uname
        else
            DKMLSYS_UNAME=/bin/uname
        fi
    fi
    if [ -z "${DKMLSYS_ENV:-}" ]; then
        if [ -x /usr/bin/env ]; then
            DKMLSYS_ENV=/usr/bin/env
        else
            DKMLSYS_ENV=/bin/env
        fi
    fi
    if [ -z "${DKMLSYS_AWK:-}" ]; then
        if [ -x /usr/bin/awk ]; then
            DKMLSYS_AWK=/usr/bin/awk
        else
            DKMLSYS_AWK=/bin/awk
        fi
    fi
    if [ -z "${DKMLSYS_SED:-}" ]; then
        if [ -x /usr/bin/sed ]; then
            DKMLSYS_SED=/usr/bin/sed
        else
            DKMLSYS_SED=/bin/sed
        fi
    fi
    if [ -z "${DKMLSYS_COMM:-}" ]; then
        if [ -x /usr/bin/comm ]; then
            DKMLSYS_COMM=/usr/bin/comm
        else
            DKMLSYS_COMM=/bin/comm
        fi
    fi
    if [ -z "${DKMLSYS_INSTALL:-}" ]; then
        if [ -x /usr/bin/install ]; then
            DKMLSYS_INSTALL=/usr/bin/install
        else
            DKMLSYS_INSTALL=/bin/install
        fi
    fi
    if [ -z "${DKMLSYS_RM:-}" ]; then
        if [ -x /usr/bin/rm ]; then
            DKMLSYS_RM=/usr/bin/rm
        else
            DKMLSYS_RM=/bin/rm
        fi
    fi
    if [ -z "${DKMLSYS_SORT:-}" ]; then
        if [ -x /usr/bin/sort ]; then
            DKMLSYS_SORT=/usr/bin/sort
        else
            DKMLSYS_SORT=/bin/sort
        fi
    fi
    if [ -z "${DKMLSYS_CAT:-}" ]; then
        if [ -x /usr/bin/cat ]; then
            DKMLSYS_CAT=/usr/bin/cat
        else
            DKMLSYS_CAT=/bin/cat
        fi
    fi
    if [ -z "${DKMLSYS_STAT:-}" ]; then
        if [ -x /usr/bin/stat ]; then
            DKMLSYS_STAT=/usr/bin/stat
        else
            DKMLSYS_STAT=/bin/stat
        fi
    fi
    if [ -z "${DKMLSYS_GREP:-}" ]; then
        if [ -x /usr/bin/grep ]; then
            DKMLSYS_GREP=/usr/bin/grep
        else
            DKMLSYS_GREP=/bin/grep
        fi
    fi
    if [ -z "${DKMLSYS_CURL:-}" ]; then
        if [ -x /usr/bin/curl ]; then
            DKMLSYS_CURL=/usr/bin/curl
        elif [ -x /bin/curl ]; then
            DKMLSYS_CURL=/bin/curl
        else
            DKMLSYS_CURL=
        fi
    fi
    if [ -z "${DKMLSYS_WGET:-}" ]; then
        if [ -x /usr/bin/wget ]; then
            DKMLSYS_WGET=/usr/bin/wget
        elif [ -x /bin/wget ]; then
            DKMLSYS_WGET=/bin/wget
        else
            DKMLSYS_WGET=
        fi
    fi
    if [ -z "${DKMLSYS_TR:-}" ]; then
        if [ -x /usr/bin/tr ]; then
            DKMLSYS_TR=/usr/bin/tr
        else
            DKMLSYS_TR=/bin/tr
        fi
    fi
    export DKMLSYS_MV DKMLSYS_CHMOD DKMLSYS_UNAME DKMLSYS_ENV DKMLSYS_AWK DKMLSYS_SED DKMLSYS_COMM DKMLSYS_INSTALL
    export DKMLSYS_RM DKMLSYS_SORT DKMLSYS_CAT DKMLSYS_STAT DKMLSYS_GREP DKMLSYS_CURL DKMLSYS_WGET DKMLSYS_TR
}

# Is a Windows build machine if we are in a MSYS2 or Cygwin environment.
#
# Better alternatives
# -------------------
#
# 1. If you are checking to see if you should do a cygpath, then just guard it
#    like so:
#       if [ -x /usr/bin/cygpath ]; then
#           do_something $(/usr/bin/cygpath ...) ...
#       fi
#    This clearly guards what you are about to do (cygpath) with what you will
#    need (cygpath).
# 2. is_arg_windows_platform
is_unixy_windows_build_machine() {
    if is_msys2_msys_build_machine || is_cygwin_build_machine; then
        return 0
    fi
    return 1
}

# Is a MSYS2 environment with the MSYS or MINGW64 subsystem?
# * MSYS2 can also do MinGW 32-bit and 64-bit subsystems. Used by DkML
# * MINGW64 used by Git Bash (aka. GitHub Actions `shell: bash`)
# https://www.msys2.org/docs/environments/
is_msys2_msys_build_machine() {
    if [ -e /usr/bin/msys-2.0.dll ] && {
        [ "${MSYSTEM:-}" = "MSYS" ] || [ "${MSYSTEM:-}" = "MINGW64" ] || [ "${MSYSTEM:-}" = "UCRT64" ] || [ "${MSYSTEM:-}" = "CLANG64" ] || [ "${MSYSTEM:-}" = "MINGW32" ] || [ "${MSYSTEM:-}" = "CLANG32" ] || [ "${MSYSTEM:-}" = "CLANGARM64" ]
    }; then
        return 0
    fi
    return 1
}

is_cygwin_build_machine() {
    if [ -e /usr/bin/cygwin1.dll ]; then
        return 0
    fi
    return 1
}

is_macos_build_machine() {
    if [ -x /usr/bin/uname ] && [ "$(/usr/bin/uname -s)" = Darwin ]; then
        return 0
    fi
    return 1
}

# Inputs:
# - $1 - The PLATFORM
is_arg_windows_platform() {
    case "$1" in
        windows_x86)    return 0;;
        windows_x86_64) return 0;;
        windows_arm32)  return 0;;
        windows_arm64)  return 0;;
        dev)            if is_unixy_windows_build_machine; then return 0; else return 1; fi ;;
        *)              return 1;;
    esac
}

# Linux and Android are Linux based platforms
# Inputs:
# - $1 - The PLATFORM
# Outputs:
# - BUILDHOST_ARCH
is_arg_linux_based_platform() {
    autodetect_buildhost_arch
    case "$1" in
        linux_*)    return 0;;
        android_*)  return 0;;
        dev)
            case "$BUILDHOST_ARCH" in
                linux_*)    return 0;;
                android_*)  return 0;;
                *)          return 1;;
            esac
            ;;
        *)          return 1;;
    esac
}

# macOS and iOS are Darwin based platforms
# Inputs:
# - $1 - The PLATFORM
# Outputs:
# - BUILDHOST_ARCH
is_arg_darwin_based_platform() {
    autodetect_buildhost_arch
    case "$1" in
        darwin_*)  return 0;;
        dev)
            case "$BUILDHOST_ARCH" in
                darwin_*)  return 0;;
                *)         return 1;;
            esac
            ;;
        *)          return 1;;
    esac
}

# Install files that will always be in a reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110co
#  env:DKMLDIR - The directory with .dkmlroot
install_reproducible_common() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_common_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$install_reproducible_common_BOOTSTRAPDIR"
    install_reproducible_file .dkmlroot
    install_reproducible_file vendor/drc/unix/crossplatform-functions.sh
    install_reproducible_file vendor/drc/unix/_common_tool.sh
}

# Install any non-common files that go into your reproducible build.
# All installed files will have the executable bit set.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110co
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the script that will be installed.
#       It will be deployed relative to $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
install_reproducible_file() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    _install_reproducible_file_RELFILE="$1"
    shift
    _install_reproducible_file_RELDIR=$(dirname "$_install_reproducible_file_RELFILE")
    _install_reproducible_file_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
    # When we rerun a setup script from within
    # the reproducible target directory we may be installing on top of ourselves; that is, installing with
    # the source and destination files being the same file.
    # shellcheck disable=SC3013
    if [ /dev/null -ef /dev/null ] 2>/dev/null; then
        # This script accepts the -ef operator
        if [ ! "$DKMLDIR"/"$_install_reproducible_file_RELFILE" -ef "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELFILE" ]; then
            "$DKMLSYS_INSTALL" "$DKMLDIR"/"$_install_reproducible_file_RELFILE" "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
        fi
    else
        # Sigh; portable scripts are not required to have a [ f1 -ef f2 ] operator. So we compare inodes (assuming `stat` supports `-c`)
        install_reproducible_file_STAT1=$("$DKMLSYS_STAT" -c '%i' "$DKMLDIR"/"$_install_reproducible_file_RELFILE")
        if [ -e "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELFILE" ]; then
            install_reproducible_file_STAT2=$("$DKMLSYS_STAT" -c '%i' "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELFILE")
        else
            install_reproducible_file_STAT2=
        fi
        if [ ! "$install_reproducible_file_STAT1" = "$install_reproducible_file_STAT2" ]; then
            "$DKMLSYS_INSTALL" "$DKMLDIR"/"$_install_reproducible_file_RELFILE" "$_install_reproducible_file_BOOTSTRAPDIR"/"$_install_reproducible_file_RELDIR"/
        fi
    fi
}

# Install any deterministically generated files that go into your
# reproducible build.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110co
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path to the generated script.
#  $2 - The location of the script that will be installed.
#       It must be specified relative to $DEPLOYDIR_UNIX.
install_reproducible_generated_file() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_generated_file_SRCFILE="$1"
    shift
    install_reproducible_generated_file_RELFILE="$1"
    shift
    install_reproducible_generated_file_RELDIR=$(dirname "$install_reproducible_generated_file_RELFILE")
    install_reproducible_generated_file_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELDIR"/
    "$DKMLSYS_RM" -f "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELFILE" # ensure if exists it is a regular file or link but not a directory
    "$DKMLSYS_INSTALL" "$install_reproducible_generated_file_SRCFILE" "$install_reproducible_generated_file_BOOTSTRAPDIR"/"$install_reproducible_generated_file_RELFILE"
}

# Install a README.md file that go into your reproducible build.
#
# The @@BOOTSTRAPDIR_UNIX@@ is a macro you can use inside the Markdown file
# which will be replaced with the relative path to the BOOTSTRAPNAME folder;
# it will have a trailing slash.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110co
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the .md file that will be installed.
#       It will be deployed as 'README.md' in the bootstrap folder of $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
install_reproducible_readme() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_readme_RELFILE="$1"
    shift

    # Needs to be in the standard location (so can be reproduced again)
    install_reproducible_file "$install_reproducible_readme_RELFILE"

    # Also place as a standalone README at the top of the reproducible tree
    install_reproducible_readme_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    "$DKMLSYS_INSTALL" -d "$install_reproducible_readme_BOOTSTRAPDIR"
    "$DKMLSYS_SED" "s,@@BOOTSTRAPDIR_UNIX@@,$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME/,g" "$DKMLDIR"/"$install_reproducible_readme_RELFILE" > "$install_reproducible_readme_BOOTSTRAPDIR"/README.md
}

# Changes the suffix of a string and print to the standard output.
# change_suffix TEXT OLD_SUFFIX NEW_SUFFIX
#
# This function can handle old and suffixes containing:
# * A-Za-z0-9
# * commas (,)
# * dashes (-)
# * underscores (_)
# * periods (.)
# * ampersands (@)
#
# Other characters may work, but they are not officially supported by this function.
change_suffix() {
    change_suffix_TEXT="$1"
    shift
    change_suffix_OLD_SUFFIX="$1"
    shift
    change_suffix_NEW_SUFFIX="$1"
    shift

    # Set DKMLSYS_*
    autodetect_system_binaries

    printf "%s" "$change_suffix_TEXT" | "$DKMLSYS_AWK" -v REPLACE="$change_suffix_NEW_SUFFIX" "{ gsub(/$change_suffix_OLD_SUFFIX/,REPLACE); print }"
}

# Replaces all occurrences of the search term with a replacement string, and print to the standard output.
# replace_all TEXT SEARCH REPLACE
#
# This function can handle SEARCH text containing:
# * A-Za-z0-9
# * commas (,)
# * dashes (-)
# * underscores (_)
# * periods (.)
# * ampersands (@)
#
# Other characters may work, but they are not officially supported by this function.
#
# Any characters can be used in TEXT and REPLACE.
replace_all() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    replace_all_TEXT="$1"
    shift
    replace_all_SEARCH="$1"
    shift
    replace_all_REPLACE="$1"
    shift
    replace_all_REPLACE=$(printf "%s" "$replace_all_REPLACE" | "$DKMLSYS_SED" 's#\\#\\\\#g') # escape all backslashes for awk

    printf "%s" "$replace_all_TEXT" | "$DKMLSYS_AWK" -v REPLACE="$replace_all_REPLACE" "{ gsub(/$replace_all_SEARCH/,REPLACE); print }"
}

# Install a script that can re-install necessary system packages.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110co
#  env:DKMLDIR - The directory with .dkmlroot
#  env:DKML_REPRODUCIBLE_SYSTEM_BREWFILE - Optional Brewfile of all system packages. If the package manager
#       is Homebrew, and this is specified, then instead of
#       querying Homebrew with 'brew bundle dump' this Brewfile contains the result already.
#       The file produced by 'brew bundle dump' is named 'Brewfile'.
#  $1 - The path of the script that will be created, relative to $DEPLOYDIR_UNIX.
#       Must end with `.sh`.
#  $@ - All remaining arguments are how to invoke the run script ($1).
install_reproducible_system_packages() {
    # Set DKMLSYS_*
    autodetect_system_binaries
    # Set BUILDHOST_ARCH
    autodetect_buildhost_arch

    install_reproducible_system_packages_SCRIPTFILE="$1"
    shift
    install_reproducible_system_packages_PACKAGEFILE=$(change_suffix "$install_reproducible_system_packages_SCRIPTFILE" .sh .packagelist.txt)
    if [ "$install_reproducible_system_packages_PACKAGEFILE" = "$install_reproducible_system_packages_SCRIPTFILE" ]; then
        printf "%s" "FATAL: The run script $install_reproducible_system_packages_SCRIPTFILE must end with .sh" >&2
        exit 1
    fi
    install_reproducible_system_packages_SCRIPTDIR=$(dirname "$install_reproducible_system_packages_SCRIPTFILE")
    install_reproducible_system_packages_BOOTSTRAPRELDIR=$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install_reproducible_system_packages_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$install_reproducible_system_packages_BOOTSTRAPRELDIR
    "$DKMLSYS_INSTALL" -d "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"/

    if is_msys2_msys_build_machine && [ -x /git-bash.exe ]; then
        # Git Bash
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        printf "#!/bin/sh\necho Install Git for Windows from https://git-scm.com/download/win which gives you Git Bash. Git Bash should be used to run the remaining scripts\n" > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif [ -x /usr/bin/pacman ] || [ -x /usr/sbin/pacman ]; then
        # Works on MSYS2 (bin) and ArchLinux (sbin)
        # https://wiki.archlinux.org/title/Pacman/Tips_and_tricks#List_of_installed_packages
        if [ -x /usr/bin/pacman ]; then
            pacmanexe=/usr/bin/pacman
        else
            pacmanexe=/usr/sbin/pacman
        fi
        "$pacmanexe" -Qqet > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        printf "#!/bin/sh\nexec %s -S \"\$@\" --needed - < '%s'\n" "$pacmanexe" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE" > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif is_cygwin_build_machine; then
        cygcheck.exe -c -d > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "%s\n" "#!/bin/sh"
            printf "%s\n" "if [ ! -e /usr/local/bin/cyg-get ]; then wget -O /usr/local/bin/cyg-get 'https://gitlab.com/cogline.v3/cygwin/-/raw/2049faf4b565af81937d952292f8ae5008d38765/cyg-get?inline=false'; fi"
            printf "%s\n" "if [ ! -x /usr/local/bin/cyg-get ]; then chmod +x /usr/local/bin/cyg-get; fi"
            printf "readarray -t pkgs < <(awk 'display==1{print \$1} \$1==\"Package\"{display=1}' '%s')\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE"
            # shellcheck disable=SC2016
            printf "%s\n" 'set -x ; /usr/local/bin/cyg-get install ${pkgs[@]}'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif is_arg_darwin_based_platform "$BUILDHOST_ARCH"; then
        # Use a Brewfile.lock.json as the package manifest.
        # However, when `brew` is not available (ex. Xcode runs CMake with a PATH that excludes homebrew) it is likely
        # that no brew installed packages are available either.
        if command -v brew >/dev/null; then
            # Brew exists and its installed packages can be used in the rest of the reproducible scripts.
            if [ -n "${DKML_REPRODUCIBLE_SYSTEM_BREWFILE:-}" ] && [ -e "${DKML_REPRODUCIBLE_SYSTEM_BREWFILE}" ]; then
                $DKMLSYS_INSTALL \
                    "$DKML_REPRODUCIBLE_SYSTEM_BREWFILE" \
                    "$install_reproducible_system_packages_BOOTSTRAPDIR/$install_reproducible_system_packages_PACKAGEFILE"
                # For troubleshooting and a bit of security, place a comment saying the Brewfile was provided not queried
                printf "\n# This Brewfile was provided to install_reproducible_system_packages() rather than queried.\n# It is possible that this Brewfile was out of date with the system Brew bottles and taps.\n" >> "$install_reproducible_system_packages_BOOTSTRAPDIR/$install_reproducible_system_packages_PACKAGEFILE"
            else
                install_reproducible_system_packages_OLDDIR=$PWD
                if ! cd "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"; then echo "FATAL: Could not cd to script directory" >&2; exit 107; fi
                #   Read-only Homebrew without any fancy interactive display
                $DKMLSYS_ENV \
                    HOMEBREW_NO_AUTO_UPDATE=1 \
                    HOMEBREW_NO_ANALYTICS=1 \
                    HOMEBREW_NO_COLOR=1 \
                    HOMEBREW_NO_EMOJI=1 \
                    brew bundle dump --force # creates a Brewfile in current directory
                if ! cd "$install_reproducible_system_packages_OLDDIR"; then echo "FATAL: Could not cd to old directory" >&2; exit 107; fi
                $DKMLSYS_MV \
                    "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTDIR"/Brewfile \
                    "$install_reproducible_system_packages_BOOTSTRAPDIR/$install_reproducible_system_packages_PACKAGEFILE"
            fi

            {
                printf "%s\n" "#!/bin/sh"
                printf "set -x ; brew bundle install --file '%s'\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE"
            } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        else
            # Brew and its installed packages are not available in the rest of the reproducible scripts.
            {
                printf "%s\n" "#!/bin/sh"
                printf "# Brew was not used so nothing to install\n"
                printf "true\n"
            } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        fi
    elif [ -x /usr/bin/dpkg ]; then
        # Debian/Ubuntu package restoration
        /usr/bin/dpkg --get-selections > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            # Technique from https://unix.stackexchange.com/questions/176134/installing-packages-by-importing-the-list-with-dpkg-set-selections
            printf "#!/bin/sh\n"
            printf "sudo apt-cache dumpavail | sudo dpkg --merge-avail\n"
            printf "sudo dpkg --set-selections < '%s'\n" "$install_reproducible_system_packages_BOOTSTRAPRELDIR/$install_reproducible_system_packages_PACKAGEFILE"
            printf 'sudo apt-get dselect-upgrade\n'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif [ -x /usr/bin/rpm ] && [ -x /usr/bin/zypper ]; then
        # OpenSUSE packages
        /usr/bin/rpm -qa > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "#!/bin/sh\n"
            printf "sudo /usr/bin/zypper install "
            awk 'NF==1 {printf "%s ", $1}' "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
            printf '\n'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        # truncate package list, since already embedded in script
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
    elif [ -x /usr/bin/rpm ] && [ -x /usr/bin/dnf ]; then
        # newer Oracle Linux / Fedora packages
        /usr/bin/rpm -qa > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "#!/bin/sh\n"
            printf "sudo /usr/bin/dnf install "
            awk 'NF==1 {printf "%s ", $1}' "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
            printf ' -y\n'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        # truncate package list, since already embedded in script
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
    elif [ -x /usr/bin/rpm ] && [ -x /usr/bin/yum ]; then
        # older Fedora packages
        /usr/bin/rpm -qa > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "#!/bin/sh\n"
            printf "sudo /usr/bin/yum -y install "
            awk 'NF==1 {printf "%s ", $1}' "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
            printf '\n'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        # truncate package list, since already embedded in script
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
    elif [ -x /sbin/apk ]; then
        # Alpine packages
        /sbin/apk info > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        {
            printf "#!/bin/sh\n"
            printf "sudo /sbin/apk add "
            awk 'NF==1 {printf "%s ", $1}' "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
            printf '\n'
        } > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
        # truncate package list, since already embedded in script
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
    elif [ -n "${DEFAULT_DOCKCROSS_IMAGE:-}" ] || [ -e /dockcross ]; then
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        printf "#!/bin/sh\necho Run from inside the %s Docker container\n" "${DEFAULT_DOCKCROSS_IMAGE:-dockcross}" > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    elif [ -x /bin/busybox ]; then
        # minimal Alpine (often a minimal Docker container)
        true > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_PACKAGEFILE"
        printf "#!/bin/sh\necho Install Busybox to run the remaining scripts\n" > "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
    else
        printf "%s\n" "TODO: unsupported install_reproducible_system_packages platform" >&2
        exit 1
    fi
    "$DKMLSYS_CHMOD" 755 "$install_reproducible_system_packages_BOOTSTRAPDIR"/"$install_reproducible_system_packages_SCRIPTFILE"
}

# Install a script that can relaunch itself in a relocated position.
#
# Inputs:
#  env:DEPLOYDIR_UNIX - The deployment directory
#  env:BOOTSTRAPNAME - Examples include: 110co
#  env:DKMLDIR - The directory with .dkmlroot
#  $1 - The path of the pre-existing script that should be run.
#       It will be deployed relative to $DEPLOYDIR_UNIX and it
#       must be specified as an existing relative path to $DKMLDIR.
#       Must end with `.sh`.
#  $@ - All remaining arguments are how to invoke the run script ($1).
install_reproducible_script_with_args() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    install_reproducible_script_with_args_SCRIPTFILE="$1"
    shift
    install_reproducible_script_with_args_RECREATEFILE=$(change_suffix "$install_reproducible_script_with_args_SCRIPTFILE" .sh -noargs.sh)
    if [ "$install_reproducible_script_with_args_RECREATEFILE" = "$install_reproducible_script_with_args_SCRIPTFILE" ]; then
        printf "%s\n" "FATAL: The run script $install_reproducible_script_with_args_SCRIPTFILE must end with .sh" >&2
        exit 1
    fi
    install_reproducible_script_with_args_RECREATEDIR=$(dirname "$install_reproducible_script_with_args_SCRIPTFILE")
    install_reproducible_script_with_args_BOOTSTRAPRELDIR=$SHARE_REPRODUCIBLE_BUILD_RELPATH/$BOOTSTRAPNAME
    install_reproducible_script_with_args_BOOTSTRAPDIR=$DEPLOYDIR_UNIX/$install_reproducible_script_with_args_BOOTSTRAPRELDIR

    install_reproducible_file "$install_reproducible_script_with_args_SCRIPTFILE"
    "$DKMLSYS_INSTALL" -d "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEDIR"/
    {
        printf "#!/bin/sh\n"
        printf "set -euf\n"
        # shellcheck disable=SC2016
        printf 'if [ "${DKML_BUILD_TRACE:-}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then\n'
        printf "  exec bash -x %s " \
            "$install_reproducible_script_with_args_BOOTSTRAPRELDIR/$install_reproducible_script_with_args_SCRIPTFILE"
        escape_args_for_shell "$@"
        printf "\n"
        printf "else\n"
        printf "  exec %s " \
            "$install_reproducible_script_with_args_BOOTSTRAPRELDIR/$install_reproducible_script_with_args_SCRIPTFILE"
        escape_args_for_shell "$@"
        printf "\n"
        printf "fi\n"
    } > "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEFILE"
    "$DKMLSYS_CHMOD" 755 "$install_reproducible_script_with_args_BOOTSTRAPDIR"/"$install_reproducible_script_with_args_RECREATEFILE"
}

# Tries to find the host ABI.
#
# Beware: This function uses `uname` probing which is inaccurate during
# cross-compilation.
#
# Outputs:
# - env:BUILDHOST_ARCH will contain the host ABI.
autodetect_buildhost_arch() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    autodetect_buildhost_arch_SYSTEM=$("$DKMLSYS_UNAME" -s)
    autodetect_buildhost_arch_MACHINE=$("$DKMLSYS_UNAME" -m)
    # list from https://en.wikipedia.org/wiki/Uname and https://stackoverflow.com/questions/45125516/possible-values-for-uname-m
    case "${autodetect_buildhost_arch_SYSTEM}-${autodetect_buildhost_arch_MACHINE}" in
        Linux-armv7*)
            BUILDHOST_ARCH=linux_arm32v7;;
        Linux-armv6* | Linux-arm)
            BUILDHOST_ARCH=linux_arm32v6;;
        Linux-aarch64 | Linux-arm64 | Linux-armv8*)
            BUILDHOST_ARCH=linux_arm64;;
        Linux-i386 | Linux-i686)
            BUILDHOST_ARCH=linux_x86;;
        Linux-x86_64)
            BUILDHOST_ARCH=linux_x86_64;;
        Darwin-arm64)
            BUILDHOST_ARCH=darwin_arm64;;
        Darwin-x86_64)
            BUILDHOST_ARCH=darwin_x86_64;;
        *-i386 | *-i686)
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86
            else
                printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $autodetect_buildhost_arch_SYSTEM and $autodetect_buildhost_arch_MACHINE" >&2
                exit 1
            fi
            ;;
        *-x86_64)
            if is_unixy_windows_build_machine; then
                BUILDHOST_ARCH=windows_x86_64
            else
                printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $autodetect_buildhost_arch_SYSTEM and $autodetect_buildhost_arch_MACHINE" >&2
                exit 1
            fi
            ;;
        *)
            # Since:
            # 1) MSYS2 does not run on ARM/ARM64 (https://www.msys2.org/docs/environments/)
            # 2) MSVC does not use ARM/ARM64 as host machine (https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-160)
            # we do not support Windows ARM/ARM64 as a build machine
            printf "%s\n" "FATAL: Unsupported build machine type obtained from 'uname -s' and 'uname -m': $autodetect_buildhost_arch_SYSTEM and $autodetect_buildhost_arch_MACHINE" >&2
            exit 1
            ;;
    esac
}

# Fix the MSYS2 ambiguity problem described at https://github.com/msys2/MSYS2-packages/issues/2316. Our error is running:
#   cl -nologo -O2 -Gy- -MD -Feocamlrun.exe prims.obj libcamlrun.lib advapi32.lib ws2_32.lib version.lib /link /subsystem:console /ENTRY:wmainCRTStartup
# would warn
#   cl : Command line warning D9002 : ignoring unknown option '/subsystem:console'
#   cl : Command line warning D9002 : ignoring unknown option '/ENTRY:wmainCRTStartup'
# because the slashes (/) could mean Windows paths or Windows options. We force the latter.
#
# This is described in Automatic Unix ⟶ Windows Path Conversion
# at https://www.msys2.org/docs/filesystem-paths/
disambiguate_filesystem_paths() {
    if is_msys2_msys_build_machine; then
        export MSYS2_ARG_CONV_EXCL='*'
    fi
}

# Get the number of CPUs available.
#
# Inputs:
# - env:NUMCPUS. Optional. If set, no autodetection occurs.
# Outputs:
# - env:NUMCPUS . Maximum of 8 if detectable; otherwise 1. Always a number from 1 to 8, even
#   if on input env:NUMCPUS was set to text.
autodetect_cpus() {
    # Set DKMLSYS_*
    autodetect_system_binaries

    # initialize to 0 if not set
    if [ -z "${NUMCPUS:-}" ]; then
        NUMCPUS=0
    fi
    # type cast to a number (in case user gave a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if [ "${NUMCPUS}" -eq 0 ]; then
        # need temp directory
        if [ -n "${_CS_DARWIN_USER_TEMP_DIR:-}" ]; then # macOS (see `man mktemp`)
            autodetect_cpus_TEMPDIR=$(mktemp -d "$_CS_DARWIN_USER_TEMP_DIR"/dkmlcpu.XXXXX)
        elif [ -n "${TMPDIR:-}" ]; then # macOS (see `man mktemp`)
            autodetect_cpus_TEMPDIR=$(printf "%s" "$TMPDIR" | sed 's#/$##') # remove trailing slash on macOS
            autodetect_cpus_TEMPDIR=$(mktemp -d "$autodetect_cpus_TEMPDIR"/dkmlcpu.XXXXX)
        elif [ -n "${TMP:-}" ]; then # MSYS2 (Windows), Linux
            autodetect_cpus_TEMPDIR=$(mktemp -d "$TMP"/dkmlcpu.XXXXX)
        else
            autodetect_cpus_TEMPDIR=$(mktemp -d /tmp/dkmlcpu.XXXXX)
        fi

        # do calculations
        NUMCPUS=1
        if [ -n "${NUMBER_OF_PROCESSORS:-}" ]; then
            # Windows usually has NUMBER_OF_PROCESSORS
            NUMCPUS="$NUMBER_OF_PROCESSORS"
        elif [ -x /usr/bin/getconf ] && /usr/bin/getconf _NPROCESSORS_ONLN > "$autodetect_cpus_TEMPDIR"/numcpus 2>/dev/null && [ -s "$autodetect_cpus_TEMPDIR"/numcpus ]; then
            # getconf is POSIX standard; works on macOS; https://pubs.opengroup.org/onlinepubs/009604499/utilities/getconf.html
            NUMCPUS=$("$DKMLSYS_CAT" "$autodetect_cpus_TEMPDIR"/numcpus)
        elif [ -x /usr/bin/nproc ] && /usr/bin/nproc --all > "$autodetect_cpus_TEMPDIR"/numcpus 2>/dev/null && [ -s "$autodetect_cpus_TEMPDIR"/numcpus ]; then
            # nproc is usually available on Linux
            NUMCPUS=$("$DKMLSYS_CAT" "$autodetect_cpus_TEMPDIR"/numcpus)
        fi

        # clean temp directory
        rm -rf "$autodetect_cpus_TEMPDIR"
    fi
    # type cast again to a number (in case autodetection produced a string)
    NUMCPUS=$(( NUMCPUS + 0 ))
    if [ "${NUMCPUS}" -lt 1 ]; then
        NUMCPUS=1
    fi
    export NUMCPUS
}

# ex. VS16.11 from VSCMD_VER=16.11.3
vscmd_ver_to_vsstudio_msvspreference() {
    vscmd_ver_to_vsstudio_msvspreference_VER=$1
    shift
    #   shellcheck disable=SC2016
    printf "VS%s" "$vscmd_ver_to_vsstudio_msvspreference_VER" | "$DKMLSYS_AWK" 'BEGIN{RS="\r\n"; FS="."} {print $1 "." $2; exit}'
}

# Set VSDEV_HOME_UNIX and VSDEV_HOME_BUILDHOST, if Visual Studio was installed or detected during
# Windows DkML installation.
#
# Inputs:
# - $1 - Optional. If provided, then $1/include and $1/lib are added to INCLUDE and LIB, respectively
# - env:PLATFORM - Optional; if missing treated as 'dev'. This variable will select the Visual Studio
#   options necessary to cross-compile (or native compile) to the target PLATFORM. 'dev' is always
#   a native compilation.
# - env:WORK - Optional. If provided will be used as temporary directory
#
# ... If DKML_COMPILE_TYPE set to "VS" and all five (5) DKML_COMPILE_VS_* variables
#     are specified then the chosen Visual Studio will be automatically used.
# - env:DKML_COMPILE_SPEC - Optional. Only version "1" is supported
# - env:DKML_COMPILE_TYPE - Optional.
# - env:DKML_COMPILE_VS_DIR - Optional. If provided it must be an installation directory of Visual Studio.
#   The directory should contain VC and Common7 subfolders.
# - env:DKML_COMPILE_VS_VCVARSVER - Optional. If provided it must be a version that can locate the Visual Studio
#   installation in DKML_COMPILE_VS_DIR when `vsdevcmd.bat -vcvars_ver=VERSION` is invoked. Example: `14.26`
# - env:DKML_COMPILE_VS_WINSDKVER - Optional. If provided it must be a version that can locate the Windows SDK
#   kit when `vsdevcmd.bat -winsdk=VERSION` is invoked. Example: `10.0.18362.0`
# - env:DKML_COMPILE_VS_MSVSPREFERENCE - Optional. If provided it must be a MSVS_PREFERENCE environment variable
#   value that can locate the Visual Studio installation in DKML_COMPILE_VS_DIR when
#   https://github.com/metastack/msvs-tools's or Opam's `msvs-detect` is invoked. Example: `VS16.6`
# - env:DKML_COMPILE_VS_CMAKEGENERATOR - Optional. If provided it must be a CMake Generator that makes use of
#   the Visual Studio installation in DKML_COMPILE_VS_DIR. Example: `Visual Studio 16 2019`.
#   Full list at https://cmake.org/cmake/help/v3.22/manual/cmake-generators.7.html#visual-studio-generators
#
# ... If all five (5) variables below are set, they will be used (although DKML_COMPILE_VS_* has higher
#     precedence). They are directly from VsDevCmd.bat, and CLion and other IDEs sometimes set these
#     automatically if the user (you) has already chosen a specific Visual Studio compiler.
# - env:VSINSTALLDIR - Optional.
# - env:VCToolsVersion - Optional.
# - env:WindowsSDKVersion - Optional.
# - env:VSCMD_VER - Optional.
# - env:VisualStudioVersion - Optional.
#
# ... Otherwise configuration from $env:DiskuvOCamlHome/vsstudio.* is used.
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:VSDEV_HOME_UNIX is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# - env:VSDEV_HOME_BUILDHOST is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Will be Windows path if Windows. Empty if Visual Studio not detected.
# Return Values:
# - 0: Success or a non-Windows machine. A non-Windows machine will have all outputs set to blank
# - 1: Windows machine without proper DkML installation (typically you should exit fatally)
autodetect_vsdev() {
    export VSDEV_HOME_UNIX=
    export VSDEV_HOME_BUILDHOST=
    export VSDEV_VCVARSVER=
    export VSDEV_WINSDKVER=
    export VSDEV_MSVSPREFERENCE=
    export VSDEV_CMAKEGENERATOR=
    if ! is_unixy_windows_build_machine; then
        return 0
    fi

    # Set DKMLPARENTHOME_BUILDHOST
    set_dkmlparenthomedir
    # Set DKMLSYS_*
    autodetect_system_binaries

    if [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = VS ]; then
        autodetect_vsdev_VSSTUDIODIR=$DKML_COMPILE_VS_DIR
        autodetect_vsdev_VSSTUDIOVCVARSVER=$DKML_COMPILE_VS_VCVARSVER
        autodetect_vsdev_VSSTUDIOWINSDKVER=$DKML_COMPILE_VS_WINSDKVER
        autodetect_vsdev_VSSTUDIOMSVSPREFERENCE=$DKML_COMPILE_VS_MSVSPREFERENCE
        autodetect_vsdev_VSSTUDIOCMAKEGENERATOR=$DKML_COMPILE_VS_CMAKEGENERATOR
    elif [ -n "${VSINSTALLDIR:-}" ] && [ -n "${VCToolsVersion:-}" ] && [ -n "${WindowsSDKVersion:-}" ] && [ -n "${VSCMD_VER:-}" ] && [ -n "${VisualStudioVersion:-}" ]; then
        # ex. VSINSTALLDIR=C:\DiskuvOCaml\BuildTools\ (yes, including the backslash)
        autodetect_vsdev_VSSTUDIODIR=$(printf "%s" "$VSINSTALLDIR" | "$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' | "$DKMLSYS_SED" 's#\\$##')
        # ex. 14.29.30133 (note: this is different than DKML's vsstudio.vcvars_ver.txt
        # which is only M.N rather than M.N.O)
        autodetect_vsdev_VSSTUDIOVCVARSVER=$(printf "%s" "$VCToolsVersion" | "$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}')
        # ex. 10.0.19041.0\ (yes, including the backslash)
        #   shellcheck disable=SC2016
        autodetect_vsdev_VSSTUDIOWINSDKVER=$(printf "%s" "$WindowsSDKVersion" | "$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' | "$DKMLSYS_SED" 's#\\$##')
        # ex. VS16.11 from VSCMD_VER=16.11.3
        autodetect_vsdev_VSSTUDIOMSVSPREFERENCE=$(vscmd_ver_to_vsstudio_msvspreference "$VSCMD_VER")
        # VisualStudioVersion=16.0 -> Visual Studio 16 2019
        #   shellcheck disable=SC2016
        autodetect_vsdev_VSSTUDIOVER=$(printf "%s" "$VisualStudioVersion" | "$DKMLSYS_AWK" 'BEGIN{RS="\r\n"; FS="."} {print $1; exit}')
        case "$autodetect_vsdev_VSSTUDIOVER" in
        11) autodetect_vsdev_VSSTUDIOCMAKEGENERATOR="Visual Studio 11 2012";;
        12) autodetect_vsdev_VSSTUDIOCMAKEGENERATOR="Visual Studio 13 2013";;
        14) autodetect_vsdev_VSSTUDIOCMAKEGENERATOR="Visual Studio 14 2015";;
        15) autodetect_vsdev_VSSTUDIOCMAKEGENERATOR="Visual Studio 15 2017";;
        16) autodetect_vsdev_VSSTUDIOCMAKEGENERATOR="Visual Studio 16 2019";;
        17) autodetect_vsdev_VSSTUDIOCMAKEGENERATOR="Visual Studio 17 2022";;
        *)
          printf "ERROR: VisualStudioVersion=%s is not handled by autodetect_vsdev of crossplatform-functions.sh\n" "$VisualStudioVersion" >&2
          return 1
        esac
    else
        autodetect_vsdev_VSSTUDIO_DIRFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.dir.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_DIRFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIO_VCVARSVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.vcvars_ver.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_VCVARSVERFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIO_WINSDKVERFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.winsdk.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_WINSDKVERFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIO_MSVSPREFERENCEFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.msvs_preference.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIO_MSVSPREFERENCEFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIOCMAKEGENERATORFILE="$DKMLPARENTHOME_BUILDHOST/vsstudio.cmake_generator.txt"
        if [ ! -e "$autodetect_vsdev_VSSTUDIOCMAKEGENERATORFILE" ]; then return 1; fi
        autodetect_vsdev_VSSTUDIODIR=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_DIRFILE")
        autodetect_vsdev_VSSTUDIOVCVARSVER=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_VCVARSVERFILE")
        autodetect_vsdev_VSSTUDIOWINSDKVER=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_WINSDKVERFILE")
        autodetect_vsdev_VSSTUDIOMSVSPREFERENCE=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIO_MSVSPREFERENCEFILE")
        autodetect_vsdev_VSSTUDIOCMAKEGENERATOR=$("$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}' "$autodetect_vsdev_VSSTUDIOCMAKEGENERATORFILE")
    fi
    if [ -x /usr/bin/cygpath ]; then
        autodetect_vsdev_VSSTUDIODIR=$(/usr/bin/cygpath -au "$autodetect_vsdev_VSSTUDIODIR")
    fi
    VSDEV_HOME_UNIX="$autodetect_vsdev_VSSTUDIODIR"
    if [ -x /usr/bin/cygpath ]; then
        VSDEV_HOME_BUILDHOST=$(/usr/bin/cygpath -aw "$VSDEV_HOME_UNIX")
    else
        VSDEV_HOME_BUILDHOST="$VSDEV_HOME_UNIX"
    fi
    VSDEV_VCVARSVER="$autodetect_vsdev_VSSTUDIOVCVARSVER"
    VSDEV_WINSDKVER="$autodetect_vsdev_VSSTUDIOWINSDKVER"
    VSDEV_MSVSPREFERENCE="$autodetect_vsdev_VSSTUDIOMSVSPREFERENCE"
    VSDEV_CMAKEGENERATOR="$autodetect_vsdev_VSSTUDIOCMAKEGENERATOR"
}

# Creates a program launcher that will use the system PATH.
#
# create_system_launcher OUTPUT_SCRIPT
create_system_launcher() {
    create_system_launcher_OUTPUTFILE="$1"
    shift

    # Set DKML_SYSTEM_PATH
    autodetect_system_path
    # Set DKML_POSIX_SHELL if not already set
    autodetect_posix_shell
    # Set DKMLSYS_*
    autodetect_system_binaries

    create_system_launcher_OUTPUTDIR=$(PATH=/usr/bin:/bin dirname "$create_system_launcher_OUTPUTFILE")
    [ ! -e "$create_system_launcher_OUTPUTDIR" ] && $DKMLSYS_INSTALL -d "$create_system_launcher_OUTPUTDIR" # Avoid 'Operation not permitted' if /tmp

    if [ -x /usr/bin/cygpath ]; then
        create_system_launcher_SYSTEMPATHUNIX=$(/usr/bin/cygpath --path "$DKML_SYSTEM_PATH")
    else
        create_system_launcher_SYSTEMPATHUNIX="$DKML_SYSTEM_PATH"
    fi

    # With MSYS2
    # * it is quite possible to have Path and PATH in the same environment. Opam seems to use camel case, which
    #   is probably fine in Cygwin.
    if is_msys2_msys_build_machine; then
        create_system_launcher_ENVARGS=" --unset=PATH --unset=Path"
    else
        create_system_launcher_ENVARGS=
    fi

    printf "#!%s\nset -euf\nexec %s%s PATH='%s' %s\n" "$DKML_POSIX_SHELL" "$DKMLSYS_ENV" \
        "$create_system_launcher_ENVARGS" \
        "$create_system_launcher_SYSTEMPATHUNIX" '"$@"' > "$create_system_launcher_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$create_system_launcher_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$create_system_launcher_OUTPUTFILE".tmp "$create_system_launcher_OUTPUTFILE"
}

cmake_flag_on() {
    # Definition at https://cmake.org/cmake/help/latest/command/if.html#basic-expressions
    if [ -z "$1" ]; then
        return 1
    else
        case "$1" in
            *-NOTFOUND) return 1 ;;
            1|ON|On|on|YES|Yes|yes|TRUE|True|true|Y|y|1*|2*|3*|4*|5*|6*|7*|8*|9*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

cmake_flag_off() {
    # Definition at https://cmake.org/cmake/help/latest/command/if.html#basic-expressions
    if [ -z "$1" ]; then
        return 0
    else
        case "$1" in
            *-NOTFOUND) return 0 ;;
            1|ON|On|on|YES|Yes|yes|TRUE|True|true|Y|y|1*|2*|3*|4*|5*|6*|7*|8*|9*) return 1 ;;
            *) return 0 ;;
        esac
    fi
}

cmake_flag_notfound() {
    # Definition at https://cmake.org/cmake/help/latest/command/if.html#basic-expressions
    case "$1" in
        *-NOTFOUND) return 0 ;;
        *) return 1 ;;
    esac
}

# Detects a compiler like Visual Studio and sets its variables.
#
# autodetect_compiler [--sexp] OUTPUT_SCRIPT_OR_SEXP [EXTRA_PREFIX]
#
# Example:
#  autodetect_compiler /tmp/launcher.sh && /tmp/launcher.sh cl.exe /help
#
# The generated launcher.sh behaves like a `env` command. You may place environment variable
# definitions before your target executable. Also you may use `-u name` to unset an environment
# variable. In fact, if there is no compiler detected than the generated launcher.sh is simply
# a file containing the line `exec env "$@"`.
#
# The launcher script will use the system PATH; any existing PATH will be ignored.
#
# If `--sexp` was used, then the output file is an s-expr (https://github.com/janestreet/sexplib#lexical-conventions-of-s-expression)
# file. It contains an association list of the environment variables; that is, a list of pairs where each pair is a 2-element
# list (KEY VALUE). The s-exp output will always use the full PATH, but the variable PATH_COMPILER will be the
# parts of PATH that are specific to the compiler (you can prepend it to an existing PATH).
#
# If `--msvs-detect` was used, then the output file will be a script that can replace
# https://github.com/metastack/msvs-tools#msvs-detect. The shell output from the output script
# will be the Visual Studio installation detected by this function.
#
# Example:
#   DKML_TARGET_ABI=windows_x86 autodetect_compiler --msvs-detect /tmp/msvs-detect
#   eval `bash /tmp/msvs-detect` # this is what https://github.com/ocaml/opam/blob/c7759e08722520d3ab8a8e162f3841d270191490/configure#L3655 does
#   echo $MSVS_NAME # etc.
#
# Inputs:
# - $1 - Optional. If provided, then $1/include and $1/lib are added to INCLUDE and LIB, respectively
# - env:DKML_TARGET_ABI - Optional. This variable will select the compiler options necessary to cross-compile (or native compile)
#   to the target PLATFORM. 'dev' is not a target platform. Defaults to the build host architecture.
# - env:DKML_PREFER_CROSS_OVER_NATIVE - Optional. ON means prefer to create a cross-compiler, while OFF (the default)
#   means to prefer to create a native compiler. The only time the preference is used is when both native and cross compilers
#   are viable ways to produce a binary. Examples are:
#      1. Windows x64 host can cross-compile to x86 binaries, but it can also use a x86 compiler to natively build x86 binaries.
#         This is possible because 64-bit Windows Intel machines can run both x64 and x86.
#      2. Apple Silicon (Mac M1) can cross-compile from ARM64 to x86_64, but it can also use a x86_64 compiler (under Rosetta emulator)
#         to natively build x86_64 binaries.
#         This is possible because Apple Silicon with a Rosetta emulator can run both ARM64 and x86_64.
#   The tradeoff is that a native compiler will always produce the correct binaries if it can build the binary, but a cross-compiler
#   has more opportunities to build a binary because it can have more RAM (ex. bigger symbol tables are available on a Win64 host
#   cross-compiling to Win32 binary) and often runs faster (ex. QEMU emulation of a native compiler is slow). The tradeoff is similar to
#   precision (correctness for native compiler) versus recall (binaries can be produced in more situations, more quickly, than a native compiler).
#   The default is to prefer native compiler (ie. OFF) so that the generated binaries are always correct.
# - env:WORK - Optional. If provided will be used as temporary directory
# - env:DKML_COMPILE_SPEC - Optional. If specified will be a specification number, which determines which
#   other environment variables have to be supplied and the format of each variable.
#   Only spec 1 is supported today:
#   - env:DKML_COMPILE_TYPE - "SYS" for the system which compiles for the host ABI.
#   - env:DKML_COMPILE_TYPE - "VS" for Visual Studio. The following vars must be defined:
#     - env:DKML_COMPILE_VS_DIR - The
#       specified installation directory of Visual Studio will be used.
#       The directory should contain VC and Common7 subfolders.
#     - env:DKML_COMPILE_VS_VCVARSVER - Must be a version that can locate the Visual Studio
#       installation in DKML_COMPILE_VS_DIR when `vsdevcmd.bat -vcvars_ver=VERSION` is invoked. Example: `14.26`
#     - env:DKML_COMPILE_VS_WINSDKVER - Must be a version that can locate the Windows SDK
#       kit when `vsdevcmd.bat -winsdk=VERSION` is invoked. Example: `10.0.18362.0`
#     - env:DKML_COMPILE_VS_MSVSPREFERENCE - Must be a MSVS_PREFERENCE environment variable
#       value that can locate the Visual Studio installation in DKML_COMPILE_VS_DIR when
#       https://github.com/metastack/msvs-tools's or Opam's `msvs-detect` is invoked. Example: `VS16.6`
#   - env:DKML_COMPILE_TYPE - "CM" for CMake. The following CMake variables should be defined if they exist:
#     - env:DKML_COMPILE_CM_CONFIG - The value of the CMake generator expression $<CONFIG>
#     - env:DKML_COMPILE_CM_HAVE_AFL - Whether the CMake compiler is an AFL fuzzy compiler
#     - env:DKML_COMPILE_CM_CMAKE_SYSROOT - The CMake variable CMAKE_SYSROOT
#     - env:DKML_COMPILE_CM_CMAKE_SYSTEM_NAME - The CMake variable CMAKE_SYSTEM_NAME
#     - env:DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_ABI
#     - env:DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_TRIPLE
#     - env:DKML_COMPILE_CM_CMAKE_ANDROID_ARM_NEON
#     - env:DKML_COMPILE_CM_CMAKE_ANDROID_NDK_VERSION
#     - env:DKML_COMPILE_CM_CMAKE_AR
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILER_ID
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILER_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILER_AR - Typically set by Android's CMake toolchain to different but correct value compared to CMAKE_AR
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILER_RANLIB - Typically set by Android's CMake toolchain to different but correct value compared to CMAKE_RANLIB
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OBJECT
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OPTIONS_PIC
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OPTIONS_PIE
#     - env:DKML_COMPILE_CM_CMAKE_ASM_COMPILE_OPTIONS_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_ASM_FLAGS - All uppercased values of $<CONFIG> should be defined as well. The
#       _DEBUG/_RELEASE/_RELEASECOMPATFUZZ/_RELEASECOMPATPERF variables below are the standard $<CONFIG> that
#       come with DKSDK. Other $<CONFIG> may be defined as well on a per-project basis.
#     - env:DKML_COMPILE_CM_CMAKE_ASM_FLAGS_DEBUG
#     - env:DKML_COMPILE_CM_CMAKE_ASM_FLAGS_RELEASE
#     - env:DKML_COMPILE_CM_CMAKE_ASM_FLAGS_RELEASECOMPATFUZZ
#     - env:DKML_COMPILE_CM_CMAKE_ASM_FLAGS_RELEASECOMPATPERF
#     - env:DKML_COMPILE_CM_CMAKE_ASM_OSX_DEPLOYMENT_TARGET_FLAG
#     - env:DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_ASM_ATT_COMPILER - The CMake variable CMAKE_ASM-ATT_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_ASM_ATT_COMPILE_OBJECT - The CMake variable CMAKE_ASM-ATT_COMPILE_OBJECT
#     - env:DKML_COMPILE_CM_CMAKE_ASM_ATT_FLAGS - The CMake variable CMAKE_ASM-ATT_FLAGS
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILER_ID
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_PIC
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_PIE
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_SYSROOT
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_C_COMPILER_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS - All uppercased values of $<CONFIG> should be defined as well. The
#       _DEBUG/_RELEASE/_RELEASECOMPATFUZZ/_RELEASECOMPATPERF variables below are the standard $<CONFIG> that
#       come with DKSDK. Other $<CONFIG> may be defined as well on a per-project basis.
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_RELEASE
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_RELEASECOMPATFUZZ
#     - env:DKML_COMPILE_CM_CMAKE_C_FLAGS_RELEASECOMPATPERF
#     - env:DKML_COMPILE_CM_CMAKE_C_OSX_DEPLOYMENT_TARGET_FLAG
#     - env:DKML_COMPILE_CM_CMAKE_C_STANDARD_INCLUDE_DIRECTORIES
#     - env:DKML_COMPILE_CM_CMAKE_C_STANDARD_LIBRARIES
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILER
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILER_ID
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILE_OPTIONS_PIC
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILE_OPTIONS_PIE
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILE_OPTIONS_SYSROOT
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILE_OPTIONS_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_CXX_COMPILER_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_CXX_FLAGS - All uppercased values of $<CONFIG> should be defined as well. The
#       _DEBUG/_RELEASE/_RELEASECOMPATFUZZ/_RELEASECOMPATPERF variables below are the standard $<CONFIG> that
#       come with DKSDK. Other $<CONFIG> may be defined as well on a per-project basis.
#     - env:DKML_COMPILE_CM_CMAKE_CXX_FLAGS_DEBUG
#     - env:DKML_COMPILE_CM_CMAKE_CXX_FLAGS_RELEASE
#     - env:DKML_COMPILE_CM_CMAKE_CXX_FLAGS_RELEASECOMPATFUZZ
#     - env:DKML_COMPILE_CM_CMAKE_CXX_FLAGS_RELEASECOMPATPERF
#     - env:DKML_COMPILE_CM_CMAKE_CXX_OSX_DEPLOYMENT_TARGET_FLAG
#     - env:DKML_COMPILE_CM_CMAKE_CXX_STANDARD_INCLUDE_DIRECTORIES
#     - env:DKML_COMPILE_CM_CMAKE_CXX_STANDARD_LIBRARIES
#     - env:DKML_COMPILE_CM_CMAKE_OSX_DEPLOYMENT_TARGET
#     - env:DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P
#     - env:DKML_COMPILE_CM_CMAKE_LINKER
#     - env:DKML_COMPILE_CM_CMAKE_SHARED_LINKER_FLAGS
#     - env:DKML_COMPILE_CM_CMAKE_STATIC_LINKER_FLAGS
#     - env:DKML_COMPILE_CM_CMAKE_EXE_LINKER_FLAGS
#     - env:DKML_COMPILE_CM_CMAKE_MODULE_LINKER_FLAGS
#     - env:DKML_COMPILE_CM_CMAKE_NM
#     - env:DKML_COMPILE_CM_CMAKE_OBJDUMP
#     - env:DKML_COMPILE_CM_CMAKE_RANLIB
#     - env:DKML_COMPILE_CM_CMAKE_STRIP
#     - env:DKML_COMPILE_CM_CMAKE_LIBRARY_ARCHITECTURE
#     - env:DKML_COMPILE_CM_MSVC - The CMake variable MSVC
#   - If no DKML_COMPILE_SPEC or no DKML_COMPILE_TYPE above ...
#     | Machine = Darwin |
#     - env:DKML_COMPILE_DARWIN_OSX_DEPLOYMENT_TARGET - The minimum version of the target
#       platform (e.g. macOS or iOS) on which the target binaries are to be deployed.
#       Populates -mmacosx-version-min=MM.NN in clang.
# Outputs:
# - env:DKMLPARENTHOME_BUILDHOST
# - env:BUILDHOST_ARCH will contain the correct ARCH
# - env:DKML_SYSTEM_PATH
# - env:OCAML_HOST_TRIPLET is non-empty if `--host OCAML_HOST_TRIPLET` should be passed to OCaml's ./configure script when
#   compiling OCaml. Aligns with the PLATFORM variable that was specified, especially for cross-compilation.
# - env:DKML_TARGET_SYSROOT is the target's sysroot when cross-compiling (only available when DKML_COMPILE_TYPE=CM);
#   empty otherwise.
# - env:VSDEV_HOME_UNIX is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Empty otherwise
# - env:VSDEV_HOME_BUILDHOST is the Visual Studio installation directory containing VC and Common7 subfolders,
#   if and only if Visual Studio was detected. Will be Windows path if Windows. Empty if Visual Studio not detected.
# Launcher/s-exp Environment:
# - (When DKML_COMPILE_TYPE=VS) MSVS_PREFERENCE will be set for https://github.com/metastack/msvs-tools or
#   Opam's `msvs-detect` to detect which Visual Studio installation to use. Example: `VS16.6`
# - (When DKML_COMPILE_TYPE=VS) CMAKE_GENERATOR_RECOMMENDED will be set for build scripts to use a sensible generator
#   in `cmake -G <generator>` if there is not a more appropriate value. Example: `Visual Studio 16 2019`
# - (When DKML_COMPILE_TYPE=VS) CMAKE_GENERATOR_INSTANCE_RECOMMENDED will be set for build scripts to use a sensible
#   generator instance in `cmake -G ... -D CMAKE_GENERATOR_INSTANCE=<generator instance>`. Only set for Visual Studio where
#   it is the absolute path to a Visual Studio instance. Example: `C:\DiskuvOCaml\BuildTools`
# - (When DKML_COMPILE_TYPE=CM) ... In general, most variables follow the universal ./configure conventions
#   described at https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html _not_
#   github.com/ocaml/ocaml/configure non-standard behavior (which has ASPP, and doesn't separate AS
#   from ASFLAGS, etc.)
# - (When DKML_COMPILE_TYPE=CM) CC - C compiler
# - (When DKML_COMPILE_TYPE=CM) CFLAGS - C compiler flags
# - (When DKML_COMPILE_TYPE=CM) AS - Assembler (assembly language compiler)
# - (When DKML_COMPILE_TYPE=CM) ASFLAGS - Assembler flags
# - (When DKML_COMPILE_TYPE=CM) LDFLAGS - Extra flags to give to compilers when they are supposed to invoke the linker,
#   `ld`, such as -L. Libraries (-lfoo) should be added to the LDLIBS variable instead. IMPORTANT: this will almost
#   always be blank. Instead use DKML_COMPILE_CM_CMAKE_(EXE|STATIC|SHARED|MODULE)_LINKER_FLAGS to get appropriate
#   executable / shared lib / static lib / plugin flags
# - (When DKML_COMPILE_TYPE=CM) LDLIBS - Library flags or names given to compilers
#   when they are supposed to invoke the linker, `ld`. Non-library linker flags, such as -L, should go in the LDFLAGS
#   variable.
# - (When DKML_COMPILE_TYPE=CM) AR - Archive-maintaining program
# - (When DKML_COMPILE_TYPE=CM) DKML_COMPILE_CM_* - All these variables will be passed-through if CMake so
#   downstream OCaml/Opam/etc. can fine-tune what flags / environment variables get passed into
#   their `./configure` scripts
autodetect_compiler() {
    # Set BUILDHOST_ARCH (needed before we process arguments)
    autodetect_buildhost_arch

    # Handle --post-transform hook (default does nothing)
    autodetect_compiler_user_post_transform() {
        true
    }
    if [ "$1" = --post-transform ]; then
        shift
        autodetect_compiler_POSTTRANSFORM=$1
        shift
        autodetect_compiler_user_post_transform() {
            # shellcheck disable=SC1090
            . "$autodetect_compiler_POSTTRANSFORM"
        }
    fi

    # Handle output mode
    autodetect_compiler_OUTPUTMODE=LAUNCHER
    if [ "$1" = --sexp ]; then
        autodetect_compiler_OUTPUTMODE=SEXP
        shift
    elif [ "$1" = --msvs-detect ]; then
        autodetect_compiler_OUTPUTMODE=MSVS_DETECT
        shift
    fi
    autodetect_compiler_OUTPUTFILE="$1"
    shift
    if [ -n "${WORK:-}" ]; then
        autodetect_compiler_TEMPDIR=$WORK
    elif [ -n "${_CS_DARWIN_USER_TEMP_DIR:-}" ]; then # macOS (see `man mktemp`)
        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d "$_CS_DARWIN_USER_TEMP_DIR"/dkmlc.XXXXX)
    elif [ -n "${TMPDIR:-}" ]; then # macOS (see `man mktemp`)
        autodetect_compiler_TEMPDIR=$(printf "%s" "$TMPDIR" | sed 's#/$##') # remove trailing slash on macOS
        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d "$autodetect_compiler_TEMPDIR"/dkmlc.XXXXX)
    elif [ -n "${TMP:-}" ]; then # MSYS2 (Windows), Linux
        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d "$TMP"/dkmlc.XXXXX)
    else
        autodetect_compiler_TEMPDIR=$(PATH=/usr/bin:/bin mktemp -d /tmp/dkmlc.XXXXX)
    fi
    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_TEMPDIR_WIN=$(/usr/bin/cygpath -aw "$autodetect_compiler_TEMPDIR")
        autodetect_compiler_TEMPDIR_DOS=$(/usr/bin/cygpath -ad "$autodetect_compiler_TEMPDIR")
    else
        autodetect_compiler_TEMPDIR_WIN="$autodetect_compiler_TEMPDIR"
        autodetect_compiler_TEMPDIR_DOS="$autodetect_compiler_TEMPDIR"
    fi
    if [ -n "${DKML_TARGET_ABI:-}" ]; then
        autodetect_compiler_PLATFORM_ARCH=$DKML_TARGET_ABI
    else
        autodetect_compiler_PLATFORM_ARCH=$BUILDHOST_ARCH
    fi

    # OUTPUTFILE needs to be an absolute path because `. <file>` in MSYS2's
    # dash.exe needs explicit relative directory (ex. ./<file>) or absolute path
    case "$autodetect_compiler_OUTPUTFILE" in
        /*|?:*) # ex. /a/b/c or C:\Windows
            ;;
        *)
            # shellcheck disable=SC2034
            autodetect_compiler_OUTPUTFILE="$PWD/$autodetect_compiler_OUTPUTFILE" ;;
    esac


    # Validate compile spec
    autodetect_compiler_SPECBITS=""

    [ -n "${DKML_COMPILE_VS_DIR:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}1"
    [ -n "${DKML_COMPILE_VS_VCVARSVER:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}2"
    [ -n "${DKML_COMPILE_VS_WINSDKVER:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}3"
    [ -n "${DKML_COMPILE_VS_MSVSPREFERENCE:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}4"

    [ -n "${DKML_COMPILE_CM_CONFIG:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}a"
    [ -n "${DKML_COMPILE_CM_CMAKE_SYSTEM_NAME:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}b"
    [ -n "${DKML_COMPILE_CM_CMAKE_C_COMPILER:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}c"
    [ -n "${DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P:-}" ] && autodetect_compiler_SPECBITS="${autodetect_compiler_SPECBITS}d"

    if [ -z "${DKML_COMPILE_SPEC:-}" ]; then
        if [ ! "$autodetect_compiler_SPECBITS" = "" ]; then
            printf "No DKML compile environment variables should be passed without a DKML compile spec. Error code: %s\n" "$autodetect_compiler_SPECBITS" >&2
            exit 107
        fi
    elif [ "${DKML_COMPILE_SPEC:-}" = 1 ]; then
        case "${DKML_COMPILE_TYPE:-}" in
            SYS)
                # Autodetect system host compiler
                ;;
            VS)
                if [ ! "$autodetect_compiler_SPECBITS" = "1234" ]; then
                    printf "DKML compile spec 1 for Visual Studio (VS) was not followed. Error code: %s\n" "$autodetect_compiler_SPECBITS" >&2
                    exit 107
                fi
                ;;
            CM)
                if [ ! "$autodetect_compiler_SPECBITS" = "abcd" ]; then
                    printf "DKML compile spec 1 for CMake (CM) was not followed. Error code: %s\n" "$autodetect_compiler_SPECBITS" >&2
                    exit 107
                fi
                ;;
            *)
                printf "DKML compile spec 1 was not followed. DKML_COMPILE_TYPE must be SYS, VS or CM\n" >&2
                exit 107
            ;;
        esac
    else
        printf "Only DKML compile spec 1 is supported\n" >&2
        exit 107
    fi

    # Set DKML_POSIX_SHELL if not already set
    autodetect_posix_shell
    # Set DKML_SYSTEM_PATH
    autodetect_system_path

    # Set DKMLSYS_*
    autodetect_system_binaries

    # Initialize output script and variables in case of failure
    if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
        printf '()' > "$autodetect_compiler_OUTPUTFILE".tmp
        "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
    elif [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
        true > "$autodetect_compiler_OUTPUTFILE"
        "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE"
    elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
        create_system_launcher "$autodetect_compiler_OUTPUTFILE"
    fi
    export VSDEV_HOME_UNIX=
    export VSDEV_HOME_BUILDHOST=
    export DKML_TARGET_SYSROOT=

    # Host triplet:
    #   (TODO: Better link)
    #   https://gitlab.com/diskuv/diskuv-ocaml/-/blob/aabf3171af67a0a0ff4779c336867a7a43e3670f/etc/opam-repositories/diskuv-opam-repo/packages/ocaml-variants/ocaml-variants.4.12.0+options+dkml+msvc64/opam#L52-62
    export OCAML_HOST_TRIPLET=

    # Standardized variables
    autodetect_compiler_CC=
    autodetect_compiler_CXX=
    autodetect_compiler_CFLAGS=
    autodetect_compiler_CXXFLAGS=
    autodetect_compiler_AS=
    autodetect_compiler_ASFLAGS=
    autodetect_compiler_LD=
    autodetect_compiler_LDFLAGS=
    autodetect_compiler_LDLIBS=
    autodetect_compiler_MSVS_NAME=
    autodetect_compiler_MSVS_INC=
    autodetect_compiler_MSVS_LIB=
    autodetect_compiler_MSVS_PATH=

    # Internal variables
    autodetect_compiler_PATH_PREFIX=

    if [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ] ; then
        printf '@+ autodetect_compiler env\n' >&2
        "$DKMLSYS_ENV" | "$DKMLSYS_SED" 's/^/@env+| /' | "$DKMLSYS_AWK" '{print}' >&2
        printf '@env?| DKML_COMPILE_SPEC=%s\n' "${DKML_COMPILE_SPEC:-}" >&2
        printf '@env?| DKML_COMPILE_TYPE=%s\n' "${DKML_COMPILE_TYPE:-}" >&2
    fi

    if [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = VS ]; then
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_vsdev DKML_COMPILE_SPEC=1 DKML_COMPILE_TYPE=VS\n" >&2
        autodetect_vsdev # set DKMLPARENTHOME_BUILDHOST and VSDEV_*
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_compiler_vsdev DKML_COMPILE_SPEC=1 DKML_COMPILE_TYPE=VS\n" >&2
        autodetect_compiler_vsdev "$VSDEV_HOME_UNIX"
    elif [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = CM ]; then
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_compiler_cmake DKML_COMPILE_SPEC=1 DKML_COMPILE_TYPE=CM\n" >&2
        autodetect_compiler_cmake
    elif [ "${DKML_COMPILE_SPEC:-}" = 1 ] && [ "${DKML_COMPILE_TYPE:-}" = SYS ]; then
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_compiler_system DKML_COMPILE_SPEC=1 DKML_COMPILE_TYPE=SYS\n" >&2
        autodetect_compiler_system
    elif autodetect_vsdev && [ -n "$VSDEV_HOME_UNIX" ]; then
        # `autodetect_vsdev` will have set DKMLPARENTHOME_BUILDHOST and VSDEV_*
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_compiler_vsdev autodetect_vsdev=true VSDEV_HOME_UNIX=%s\n" "$VSDEV_HOME_UNIX" >&2
        autodetect_compiler_vsdev "$VSDEV_HOME_UNIX"
    elif [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_x86_64" ] || [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_arm64" ]; then
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_compiler_darwin PLATFORM_ARCH=darwin_{x86_64,arm64}\n" >&2
        autodetect_compiler_darwin
    else
        [ "${DKML_BUILD_TRACE:-OFF}" = OFF ] || printf "+: autodetect_compiler_system\n" >&2
        autodetect_compiler_system
    fi

    if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then
        autodetect_compiler_OUTPUTBASENAME=$(basename "$autodetect_compiler_OUTPUTFILE")
        printf "@+= autodetect_compiler > %s\n" "$autodetect_compiler_OUTPUTFILE" >&2
        "$DKMLSYS_SED" 's/^/@'"$autodetect_compiler_OUTPUTBASENAME"'+| /' "$autodetect_compiler_OUTPUTFILE" | "$DKMLSYS_AWK" '{print}' >&2
    fi

    # When $WORK is not defined, we have a unique directory that needs cleaning
    if [ -z "${WORK:-}" ]; then
        $DKMLSYS_RM -rf "$autodetect_compiler_TEMPDIR"
    fi
}

# Each s-exp string must follow OCaml syntax (escape double-quotes and backslashes)
# Since each name/value pair is an assocation list, we replace the first `=` in each line with `" "`.
# So if the input is: NAME=VALUE
# then the output is: NAME" "VALUE
autodetect_compiler_escape_sexp() {
    "$DKMLSYS_SED" 's#\\#\\\\#g; s#"#\\"#g; s#=#" "#; ' "$@"
}

# Since we will embed each name/value pair in single quotes
# (ie. Z=hi ' there ==> 'Z=hi '"'"' there') so it can be placed
# as a single `env` argument like `env 'Z=hi '"'"' there' ...`
# we need to replace single quotes (') with ('"'"').
autodetect_compiler_escape_envarg() {
    "$DKMLSYS_CAT" "$@" | escape_stdin_for_single_quote
}

# Sets _CMAKE_ASM_FLAGS and _CMAKE_(C|ASM|CXX)_FLAGS_FOR_CONFIG environment variables to the value
# of config-specific c_flags and asm_flags variable like
# `DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG` and `DKML_COMPILE_CM_CMAKE_ASM_ATT_FLAGS_DEBUG` when
# `DKML_COMPILE_CM_CONFIG` is `Debug`.
# The specific ASM variant defaults to ASM, but can be ASM_MASM, ASM_NASM or ASM_ATT.
autodetect_compiler_cmake_get_config_flags() {
    # ASM, ASM_MASM, ASM_NASM or ASM-ATT?
    autodetect_compiler_cmake_get_config_flags_ASM=ASM
    if [ -n "${DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER:-}" ]; then
        autodetect_compiler_cmake_get_config_flags_ASM=ASM_MASM
    elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER:-}" ]; then
        autodetect_compiler_cmake_get_config_flags_ASM=ASM_NASM
    elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_ATT_COMPILER:-}" ]; then
        autodetect_compiler_cmake_get_config_flags_ASM=ASM_ATT
    fi

    # example command: _CMAKE_C_FLAGS_FOR_CONFIG="$DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG"
    autodetect_compiler_cmake_get_config_flags_CONFIGUPPER=$(printf "%s" "$DKML_COMPILE_CM_CONFIG" | $DKMLSYS_TR '[:lower:]' '[:upper:]')
    {
      printf "_CMAKE_C_FLAGS_FOR_CONFIG=\"\${DKML_COMPILE_CM_CMAKE_C_FLAGS_%s:-}\"\n" "$autodetect_compiler_cmake_get_config_flags_CONFIGUPPER"
      printf "_CMAKE_CXX_FLAGS_FOR_CONFIG=\"\${DKML_COMPILE_CM_CMAKE_CXX_FLAGS_%s:-}\"\n" "$autodetect_compiler_cmake_get_config_flags_CONFIGUPPER"
      printf "_CMAKE_ASM_FLAGS=\"\${DKML_COMPILE_CM_CMAKE_%s_FLAGS:-}\"\n" "$autodetect_compiler_cmake_get_config_flags_ASM"
      printf "_CMAKE_ASM_FLAGS_FOR_CONFIG=\"\${DKML_COMPILE_CM_CMAKE_%s_FLAGS_%s:-}\"\n" "$autodetect_compiler_cmake_get_config_flags_ASM" "$autodetect_compiler_cmake_get_config_flags_CONFIGUPPER"
    } > "$autodetect_compiler_OUTPUTFILE.flags.source"
    # shellcheck disable=SC1090
    . "$autodetect_compiler_OUTPUTFILE.flags.source"
    $DKMLSYS_RM -f "$autodetect_compiler_OUTPUTFILE.flags.source"
}

# Users must use the DKML_TARGET_ABI and DKML_COMPILE_* environment variables so
# cross-compilation is unambiguous.
compiler_clear_environment() {
    # Unix autoconf
    export CC=
    export CXX=
    export CFLAGS=
    export CXXFLAGS=
    export AS=
    export ASFLAGS=
    export LD=
    export LDFLAGS=
    export LDLIBS=
    export AR=

    # msvs-detect
    export MSVS_NAME=
    export MSVS_PATH=
    export MSVS_INC=
    export MSVS_LIB=
    export MSVS_ML=
    export MSVS64_NAME=
    export MSVS64_PATH=
    export MSVS64_INC=
    export MSVS64_LIB=
    export MSVS64_ML=
    export MSVS_PREFERENCE=

    # Visual Studio
    export INCLUDE=
    export LIB=
}

# Used by DKML's autodetect_compiler() function to customize compiler
# variables before the variables are written to a launcher script.
#
# On entry autodetect_compiler() will have populated some or all of the
# following non-export variables:
#
# * autodetect_compiler_CFLAGS
# * autodetect_compiler_CC
# * autodetect_compiler_CXX
# * autodetect_compiler_CFLAGS
# * autodetect_compiler_CXXFLAGS
# * autodetect_compiler_AS
# * autodetect_compiler_ASFLAGS
# * autodetect_compiler_LD
# * autodetect_compiler_LDFLAGS
# * autodetect_compiler_LDLIBS
# * autodetect_compiler_MSVS_NAME
# * autodetect_compiler_MSVS_INC. Separated by semicolons. No trailing semicolon.
# * autodetect_compiler_MSVS_LIB. Separated by semicolons. No trailing semicolon.
# * autodetect_compiler_MSVS_PATH. Unix PATH format with no trailing colon.
#
# Generally the variables conform to the description in
# https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html.
# The compiler will have been chosen from:
# a) find the compiler selected/validated in the DkML installation
#    (Windows) or on first-use (Unix)
# b) the specific architecture that has been given in DKML_TARGET_ABI
#
# Also the function `export_binding NAME VALUE` will be available for you to
# add custom variables (like AR, NM, OBJDUMP, etc.) to the launcher script.
#
# On exit the `autodetect_compiler_VARNAME` variables may be changed by this
# script. They will then be used for github.com/ocaml/ocaml/configure.
#
# That is, you influence variables written to the launcher script by either:
# a) Changing autodetect_compiler_CFLAGS (etc.). Those values will be named as
#    CFLAGS (etc.) in the launcher script
# b) Explicitly adding names and values with `export_binding`
autodetect_compiler_write_output() {
    if [ "$#" -ge 1 ] && [ "$1" = "--has-supplied-post-transform" ]; then
        autodetect_compiler_has_supplied_post_transform=1
        shift
    else
        autodetect_compiler_has_supplied_post_transform=0
    fi
    {
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "(\n"

            # shellcheck disable=SC2317
            export_binding() {
                export_binding_NAME=$1
                shift
                export_binding_VALUE=$1
                shift
                export_binding_VALUE=$(escape_arg_as_ocaml_string "$export_binding_VALUE")
                printf "  (\"%s\" \"%s\")\n" "$export_binding_NAME" "$export_binding_VALUE"
            }

            # Post-transform
            DKML_TARGET_ABI="$autodetect_compiler_PLATFORM_ARCH" autodetect_compiler_user_post_transform
            if [ "$autodetect_compiler_has_supplied_post_transform" = 1 ]; then
                autodetect_compiler_supplied_post_transform
            fi

            # Universal ./configure flags
            # Reference: https://www.gnu.org/software/make/manual/html_node/Implicit-Variables.html
            autodetect_compiler_sexp_CC=$(escape_arg_as_ocaml_string "$autodetect_compiler_CC")
            printf "  (\"CC\" \"%s\")\n" "$autodetect_compiler_sexp_CC"
            autodetect_compiler_sexp_CXX=$(escape_arg_as_ocaml_string "$autodetect_compiler_CXX")
            printf "  (\"CXX\" \"%s\")\n" "$autodetect_compiler_sexp_CXX"
            autodetect_compiler_sexp_CFLAGS=$(escape_arg_as_ocaml_string "$autodetect_compiler_CFLAGS")
            printf "  (\"CFLAGS\" \"%s\")\n" "$autodetect_compiler_sexp_CFLAGS"
            autodetect_compiler_sexp_CXXFLAGS=$(escape_arg_as_ocaml_string "$autodetect_compiler_CXXFLAGS")
            printf "  (\"CXXFLAGS\" \"%s\")\n" "$autodetect_compiler_sexp_CXXFLAGS"
            autodetect_compiler_sexp_AS=$(escape_arg_as_ocaml_string "$autodetect_compiler_AS")
            printf "  (\"AS\" \"%s\")\n" "$autodetect_compiler_sexp_AS"
            autodetect_compiler_sexp_ASFLAGS=$(escape_arg_as_ocaml_string "$autodetect_compiler_ASFLAGS")
            printf "  (\"ASFLAGS\" \"%s\")\n" "$autodetect_compiler_sexp_ASFLAGS"
            autodetect_compiler_sexp_LD=$(escape_arg_as_ocaml_string "$autodetect_compiler_LD")
            printf "  (\"LD\" \"%s\")\n" "$autodetect_compiler_sexp_LD"
            autodetect_compiler_sexp_LDFLAGS=$(escape_arg_as_ocaml_string "$autodetect_compiler_LDFLAGS")
            printf "  (\"LDFLAGS\" \"%s\")\n" "$autodetect_compiler_sexp_LDFLAGS"
            autodetect_compiler_sexp_LDLIBS=$(escape_arg_as_ocaml_string "$autodetect_compiler_LDLIBS")
            printf "  (\"LDLIBS\" \"%s\")\n" "$autodetect_compiler_sexp_LDLIBS"

            # Passthrough all DKML_COMPILE_CM_* variables.
            # The first `sed` command removes any surrounding single quotes from any values.
            # The second `sed` command adds a surrounding parenthesis and double quote ("...") to each value.
            # shellcheck disable=SC2016
            set | "$DKMLSYS_AWK" 'BEGIN{FS="="} $1 ~ /^DKML_COMPILE_CM_/ {print}' \
                | "$DKMLSYS_SED" "s/^\([^=]*\)='\(.*\)'$/\1=\2/" \
                | autodetect_compiler_escape_sexp \
                | "$DKMLSYS_SED" 's/^/  ("/; s/$/")/'

            printf ")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "#!$DKML_POSIX_SHELL"
            printf "set -euf\n"
            if [ -n "${autodetect_compiler_PATH_PREFIX:-}" ]; then
                printf "export PATH='%s':\"\$PATH\"\n" "$autodetect_compiler_PATH_PREFIX"
            fi
            printf "%s\n" "exec $DKMLSYS_ENV \\"

            # shellcheck disable=SC2317
            export_binding() {
                export_binding_NAME=$1
                shift
                export_binding_VALUE=$1
                shift
                export_binding_VALUE=$(escape_args_for_shell "$export_binding_VALUE")
                printf "  %s=%s %s\n" "$export_binding_NAME" "$export_binding_VALUE" "\\"
            }

            # Post-transform
            DKML_TARGET_ABI="$autodetect_compiler_PLATFORM_ARCH" autodetect_compiler_user_post_transform
            if [ "$autodetect_compiler_has_supplied_post_transform" = 1 ]; then
                autodetect_compiler_supplied_post_transform
            fi

            # Universal ./configure flags
            autodetect_compiler_launcher_CC=$(escape_args_for_shell "$autodetect_compiler_CC")
            printf "  CC=%s %s\n" "$autodetect_compiler_launcher_CC" "\\"
            autodetect_compiler_launcher_CXX=$(escape_args_for_shell "$autodetect_compiler_CXX")
            printf "  CXX=%s %s\n" "$autodetect_compiler_launcher_CXX" "\\"
            autodetect_compiler_launcher_CFLAGS=$(escape_args_for_shell "$autodetect_compiler_CFLAGS")
            printf "  CFLAGS=%s %s\n" "$autodetect_compiler_launcher_CFLAGS" "\\"
            autodetect_compiler_launcher_CXXFLAGS=$(escape_args_for_shell "$autodetect_compiler_CXXFLAGS")
            printf "  CXXFLAGS=%s %s\n" "$autodetect_compiler_launcher_CXXFLAGS" "\\"
            autodetect_compiler_launcher_AS=$(escape_args_for_shell "$autodetect_compiler_AS")
            printf "  AS=%s %s\n" "$autodetect_compiler_launcher_AS" "\\"
            autodetect_compiler_launcher_ASFLAGS=$(escape_args_for_shell "$autodetect_compiler_ASFLAGS")
            printf "  ASFLAGS=%s %s\n" "$autodetect_compiler_launcher_ASFLAGS" "\\"
            autodetect_compiler_launcher_LD=$(escape_args_for_shell "$autodetect_compiler_LD")
            printf "  LD=%s %s\n" "$autodetect_compiler_launcher_LD" "\\"
            autodetect_compiler_launcher_LDFLAGS=$(escape_args_for_shell "$autodetect_compiler_LDFLAGS")
            printf "  LDFLAGS=%s %s\n" "$autodetect_compiler_launcher_LDFLAGS" "\\"
            autodetect_compiler_launcher_LDLIBS=$(escape_args_for_shell "$autodetect_compiler_LDLIBS")
            printf "  LDLIBS=%s %s\n" "$autodetect_compiler_launcher_LDLIBS" "\\"

            # Passthrough all DKML_COMPILE_CM_* variables
            # shellcheck disable=SC2016
            set | "$DKMLSYS_AWK" -v bslash="\\\\" 'BEGIN{FS="="} $1 ~ /^DKML_COMPILE_CM_/ {name=$1; value=$0; sub(/^[^=]*=/,"",value); print "  " name "=" value " " bslash}'

            # Add arguments
            printf "%s\n" '  "$@"'
        elif [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
            printf "%s\n" "#!$DKML_POSIX_SHELL"
            printf "set -euf\n"
            # Use (mostly) same command line processing as real msvs-detect
            # at https://github.com/metastack/msvs-tools/blob/master/msvs-detect
            #   shellcheck disable=SC2016
            printf "%s\n" '
DEBUG=0
MODE=0
OUTPUT=0
MT_REQUIRED=0
ML_REQUIRED=0
TARGET_ARCH=
SCAN_ENV=0

while [ $# -ne 0 ] ; do
  case "$1" in
    # Mode settings ($MODE)
    -a|--all)
      MODE=1
      shift 1;;
    -h|--help)
      MODE=2
      shift;;
    -v|--version)
      MODE=3
      shift;;

    # Simple flags ($MT_REQUIRED and $ML_REQUIRED)
    --with-mt)
      MT_REQUIRED=1
      shift;;
    --with-assembler)
      ML_REQUIRED=1
      shift;;

    # -o, --output ($OUTPUT)
    -o|--output)
      case "$2" in
        shell)
          ;;
        make)
          OUTPUT=1;;
        *)
          echo "$0: unrecognised option for $1: $2">&2
          exit 2;;
      esac
      shift 2;;
    -oshell|--output=shell)
      shift;;
    -omake|--output=make)
      OUTPUT=1
      shift;;
    -o*)
      echo "$0: unrecognised option for -o: ${1#-o}">&2
      exit 2;;
    --output=*)
      echo "$0: unrecognised option for --output: ${1#--output=}">&2
      exit 2;;

    # -x, --arch ($TARGET_ARCH)
    -x|--arch)
      case "$2" in
        86|x86)
          TARGET_ARCH=x86;;
        64|x64)
          TARGET_ARCH=x64;;
        *)
          echo "$0: unrecognised option for $1: $2">&2
          exit 2
      esac
      shift 2;;
    -x86|-xx86|--arch=x86|--arch=86)
      TARGET_ARCH=x86
      shift;;
    -x64|-xx64|--arch=x64|--arch=64)
      TARGET_ARCH=x64
      shift;;
    -x*)
      echo "$0: unrecognised option for -x: ${1#-x}">&2
      exit 2;;
    --arch=*)
      echo "$0: unrecognised option for --arch: ${1#--arch}">&2
      exit 2;;

    # -d, --debug ($DEBUG)
    -d*)
      DEBUG=${1#-d}
      if [[ -z $DEBUG ]] ; then
        DEBUG=1
      fi
      shift;;
    --debug=*)
      DEBUG=${1#*=}
      shift;;
    --debug)
      DEBUG=1
      shift;;

    # End of option marker
    --)
      shift
      break;;

    # Invalid options
    --*)
      echo "$0: unrecognised option: ${1%%=*}">&2
      exit 2;;
    -*)
      echo "$0: unrecognised option: ${1:1:1}">&2
      exit 2;;

    # MSVS_PREFERENCE (without end-of-option marker)
    *)
      break;;
  esac
done

if [ -n "${1+x}" ] ; then
  if [ $MODE -eq 1 ] ; then
    echo "$0: cannot specify MSVS_PREFERENCE and --all">&2
    exit 2
  else
    MSVS_PREFERENCE="$@"
  fi
fi
'
            printf "%s\n" "
output_make ()
{
  VALUE=\$2
  VALUE=\${VALUE//#/\\\\\\#}
  echo \"\$1=\${VALUE//\\$/\\$\\$}\"
}
"
            # shellcheck disable=SC2317
            export_binding() {
                true
            }

            # Post-transform
            DKML_TARGET_ABI="$autodetect_compiler_PLATFORM_ARCH" autodetect_compiler_user_post_transform
            if [ "$autodetect_compiler_has_supplied_post_transform" = 1 ]; then
                autodetect_compiler_supplied_post_transform
            fi

            # MSVS_NAME
            printf "MSVS_NAME='%s'\n" "$autodetect_compiler_MSVS_NAME"

            # MSVS_PATH which must be in Unix PATH format with a trailing colon
            printf "MSVS_PATH='%s:'\n" "$autodetect_compiler_MSVS_PATH"

            # MSVS_INC which must have a trailing semicolon
            printf "MSVS_INC='%s;'\n" "$autodetect_compiler_MSVS_INC"

            # MSVS_LIB which must have a trailing semicolon
            printf "MSVS_LIB='%s;'\n" "$autodetect_compiler_MSVS_LIB"

            # MSVS_ML
            printf "MSVS_ML='%s'\n" "$autodetect_compiler_AS"

            #   shellcheck disable=SC2016
            printf 'case "$OUTPUT" in\n'
            printf '0)\n'
            #   Print a script snippet that will dump MSVS_NAME, MSVS64_PATH, etc. variables to standard output
            #   with proper quoting
            #   `set` does proper quoting
            printf "  set | awk '%s';;\n" \
                '/^MS(VS|VS64)_(NAME|PATH|INC|LIB|ML)=/{print}'
            printf '1)\n'
            #   shellcheck disable=SC2016
            printf '
  output_make MSVS_NAME "$MSVS_NAME"
  output_make MSVS_PATH "$MSVS_PATH"
  output_make MSVS_INC "$MSVS_INC"
  output_make MSVS_LIB "$MSVS_LIB"
  output_make MSVS_ML "$MSVS_ML"
  ;;
'
            printf 'esac\n'
        fi
    } > "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_CHMOD" +x "$autodetect_compiler_OUTPUTFILE".tmp
    "$DKMLSYS_MV" "$autodetect_compiler_OUTPUTFILE".tmp "$autodetect_compiler_OUTPUTFILE"
}

autodetect_compiler_cmake() {
    # DKML_TARGET_SYSROOT
    DKML_TARGET_SYSROOT=${DKML_COMPILE_CM_CMAKE_SYSROOT:-}

    # Choose which assembler should be used
    autodetect_compiler_cmake_THE_AS=
    if [ -n "${DKML_COMPILE_CM_CMAKE_ASM_COMPILER:-}" ]; then
        autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_COMPILER
    elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER:-}" ]; then
        autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_NASM_COMPILER
    elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER:-}" ]; then
        autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_MASM_COMPILER
    elif [ -n "${DKML_COMPILE_CM_CMAKE_ASM_ATT_COMPILER:-}" ]; then
        autodetect_compiler_cmake_THE_AS=$DKML_COMPILE_CM_CMAKE_ASM_ATT_COMPILER
    fi

    # Platform-specific requirements
    # ----

    autodetect_compiler_cmake_Specific_ASFLAGS=
    autodetect_compiler_cmake_Specific_CFLAGS=
    autodetect_compiler_cmake_Specific_CXXFLAGS=
    autodetect_compiler_cmake_Specific_LDFLAGS=

    # == Linux including Android ==

    if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Linux" ] || [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Android" ]; then
        # [Android]
        #
        # https://developer.android.com/ndk/guides/standalone_toolchain#building_open_source_projects_using_standalone_toolchains
        # > # Tell configure what flags Android requires.
        # > export CFLAGS="-fPIE -fPIC"
        # > export LDFLAGS="-pie"
        # Since they may be CMake string arrays (ex. `-fPIE;-pie`) we replace all semicolons with spaces.
        #
        # 2023-03-22 update: -fPIE is causing the same issues as Linux below when combined with -fPIC.
        #
        # [Linux]
        #
        # For Linux, the situation for PIE/PIC depends on the recency of the Linux distribution. Newer Linux distros enable PIE
        # by default, while older ones (like the dockcross ones used by DkSDK/setup-dkml for portability) do not enable PIE.
        # See https://stackoverflow.com/questions/43367427/32-bit-absolute-addresses-no-longer-allowed-in-x86-64-linux
        #
        # Either way, add PIC like Android recommends. However PIE is more complicated. Take base.v0.15.1/src/int_math_stubs.c
        # for example. When `gcc -fPIC -fPIE` (from a dune build), and then inspect with `readelf -r int_math_stubs.o`, we see
        # a non-PIC relocation R_X86_64_PC32. However just -fPIC does the right relocations. So we just do -fPIE on Linux.
        if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Android" ]; then
            #autodetect_compiler_cmake_PIC_PIE="${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_PIE:-} ${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_PIC:-}"
            autodetect_compiler_cmake_PIC_PIE="${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_PIC:-}"
        else
            autodetect_compiler_cmake_PIC_PIE="${DKML_COMPILE_CM_CMAKE_C_COMPILE_OPTIONS_PIC:-}"
        fi
        autodetect_compiler_cmake_Specific_CFLAGS=$(printf "%s\n" "$autodetect_compiler_cmake_Specific_CFLAGS${autodetect_compiler_cmake_PIC_PIE:+ $autodetect_compiler_cmake_PIC_PIE}" | $DKMLSYS_SED 's/;/ /g')
        autodetect_compiler_cmake_Specific_CXXFLAGS=$(printf "%s\n" "$autodetect_compiler_cmake_Specific_CXXFLAGS${autodetect_compiler_cmake_PIC_PIE:+ $autodetect_compiler_cmake_PIC_PIE}" | $DKMLSYS_SED 's/;/ /g')
        if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Android" ]; then
            #     For LDFLAGS since CMake does not have a linker pie options variable (ie. CMAKE_LINKER_OPTIONS_PIE) we hardcode it;
            #     we intentionally do not use CMAKE_C_LINK_OPTIONS_PIE since that is for the C compiler (clang) not the linker (ld.lld).
            autodetect_compiler_cmake_Specific_LDFLAGS="--pie${autodetect_compiler_cmake_Specific_LDFLAGS:+ $autodetect_compiler_cmake_Specific_LDFLAGS}"
        fi
    fi

    # == Android ==

    if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Android" ]; then
        # https://developer.android.com/ndk/guides/standalone_toolchain#abi_compatibility
        # > By default, an ARM Clang standalone toolchain will target the armeabi-v7a ABI.
        # > To use NEON instructions, you must use the -mfpu compiler flag: -mfpu=neon.
        # > Also, make sure to provide the following two flags to the linker: -march=armv7-a -Wl,--fix-cortex-a8.
        # > The first flag instructs the linker to pick toolchain libraries which are tailored for armv7-a. The 2nd flag is required as a workaround for a CPU bug in some Cortex-A8 implementations.
        # > You don't have to use any specific compiler flag when targeting the other ABIs.
        if cmake_flag_on "${DKML_COMPILE_CM_CMAKE_ANDROID_ARM_NEON:-}"; then
        autodetect_compiler_cmake_Specific_CFLAGS="$autodetect_compiler_cmake_Specific_CFLAGS -mfpu=neon"
        autodetect_compiler_cmake_Specific_CXXFLAGS="$autodetect_compiler_cmake_Specific_CXXFLAGS -mfpu=neon"
        fi
        if [ "${DKML_COMPILE_CM_CMAKE_ANDROID_ARCH_ABI:-}" = armeabi-v7a ]; then
        autodetect_compiler_cmake_Specific_LDFLAGS="$autodetect_compiler_cmake_Specific_LDFLAGS --fix-cortex-a8"
        autodetect_compiler_cmake_Specific_CFLAGS="$autodetect_compiler_cmake_Specific_CFLAGS -march=armv7-a"
        autodetect_compiler_cmake_Specific_CXXFLAGS="$autodetect_compiler_cmake_Specific_CXXFLAGS -march=armv7-a"
        fi

        # https://android.googlesource.com/platform/ndk/+/master/docs/BuildSystemMaintainers.md#additional-required-arguments
        autodetect_compiler_cmake_NDK_MAJVER=$(printf "%s\n" "${DKML_COMPILE_CM_CMAKE_ANDROID_NDK_VERSION:-16}" | sed 's/[.].*//')
        if [ "$autodetect_compiler_cmake_NDK_MAJVER" -lt 23 ]; then
        autodetect_compiler_cmake_Specific_CFLAGS="$autodetect_compiler_cmake_Specific_CFLAGS -mstackrealign"
        autodetect_compiler_cmake_Specific_CXXFLAGS="$autodetect_compiler_cmake_Specific_CXXFLAGS -mstackrealign"
        fi
    fi

    # == Darwin ==

    if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Darwin" ]; then
        if [ -n "${DKML_COMPILE_CM_CMAKE_OSX_DEPLOYMENT_TARGET:-}" ]; then
            if [ -n "${DKML_COMPILE_CM_CMAKE_ASM_OSX_DEPLOYMENT_TARGET_FLAG:-}" ]; then
                autodetect_compiler_cmake_Specific_ASFLAGS="$autodetect_compiler_cmake_Specific_ASFLAGS $DKML_COMPILE_CM_CMAKE_ASM_OSX_DEPLOYMENT_TARGET_FLAG$DKML_COMPILE_CM_CMAKE_OSX_DEPLOYMENT_TARGET"
            fi
            if [ -n "${DKML_COMPILE_CM_CMAKE_C_OSX_DEPLOYMENT_TARGET_FLAG:-}" ]; then
                autodetect_compiler_cmake_Specific_CFLAGS="$autodetect_compiler_cmake_Specific_CFLAGS $DKML_COMPILE_CM_CMAKE_C_OSX_DEPLOYMENT_TARGET_FLAG$DKML_COMPILE_CM_CMAKE_OSX_DEPLOYMENT_TARGET"
            fi
            if [ -n "${DKML_COMPILE_CM_CMAKE_CXX_OSX_DEPLOYMENT_TARGET_FLAG:-}" ]; then
                autodetect_compiler_cmake_Specific_CXXFLAGS="$autodetect_compiler_cmake_Specific_CXXFLAGS $DKML_COMPILE_CM_CMAKE_CXX_OSX_DEPLOYMENT_TARGET_FLAG$DKML_COMPILE_CM_CMAKE_OSX_DEPLOYMENT_TARGET"
            fi
        fi
    fi

    # == Windows ==

    if [ "$DKML_COMPILE_CM_CMAKE_SYSTEM_NAME" = "Windows" ] && cmake_flag_on "${DKML_COMPILE_CM_MSVC:-}"; then
        # OCAML_HOST_TRIPLET
        case "$autodetect_compiler_PLATFORM_ARCH,${DKML_COMPILE_CM_CMAKE_SIZEOF_VOID_P:-}" in
            windows_x86_64,*)   OCAML_HOST_TRIPLET=x86_64-pc-windows ;;
            windows_x86,*)      OCAML_HOST_TRIPLET=i686-pc-windows ;;
            windows_arm64,*)    OCAML_HOST_TRIPLET=aarch64-pc-windows ;;
            windows_arm32,*)    OCAML_HOST_TRIPLET=armv7-pc-windows ;;
            *,8)                OCAML_HOST_TRIPLET=x86_64-pc-windows ;;
            *,4)                OCAML_HOST_TRIPLET=i686-pc-windows ;;
            *)                  OCAML_HOST_TRIPLET=i686-pc-windows ;;
        esac

        # autodetect_compiler_PATH_PREFIX.
        #  link.exe needs to be present for flexlink.exe to compile programs
        if [ -n "${DKML_COMPILE_CM_CMAKE_LINKER:-}" ]; then
            autodetect_compiler_cmake_LINKER_DIR=$(dirname "$DKML_COMPILE_CM_CMAKE_LINKER")
            if [ -x /usr/bin/cygpath ]; then
                autodetect_compiler_cmake_LINKER_DIR=$(/usr/bin/cygpath -au "$autodetect_compiler_cmake_LINKER_DIR")
            fi
            autodetect_compiler_PATH_PREFIX="${autodetect_compiler_PATH_PREFIX:+$autodetect_compiler_PATH_PREFIX:}$autodetect_compiler_cmake_LINKER_DIR"
        fi
    fi

    # Set _CMAKE_C_FLAGS_FOR_CONFIG and _CMAKE_ASM_FLAGS_FOR_CONFIG and _CMAKE_ASM_FLAGS to
    # $DKML_COMPILE_CM_CMAKE_C_FLAGS_DEBUG if DKML_COMPILE_CM_CONFIG=Debug, etc.
    autodetect_compiler_cmake_get_config_flags

    # Standardized compiler environment variables
    autodetect_compiler_CC="${DKML_COMPILE_CM_CMAKE_C_COMPILER:-}"
    autodetect_compiler_CXX="${DKML_COMPILE_CM_CMAKE_CXX_COMPILER:-}"
    autodetect_compiler_CFLAGS="$autodetect_compiler_cmake_Specific_CFLAGS ${DKML_COMPILE_CM_CMAKE_C_FLAGS:-} $_CMAKE_C_FLAGS_FOR_CONFIG"
    autodetect_compiler_CXXFLAGS="$autodetect_compiler_cmake_Specific_CXXFLAGS ${DKML_COMPILE_CM_CMAKE_CXX_FLAGS:-} $_CMAKE_CXX_FLAGS_FOR_CONFIG"
    autodetect_compiler_AS="$autodetect_compiler_cmake_THE_AS"
    autodetect_compiler_ASFLAGS="$autodetect_compiler_cmake_Specific_ASFLAGS $_CMAKE_ASM_FLAGS $_CMAKE_ASM_FLAGS_FOR_CONFIG"
    autodetect_compiler_LD="${DKML_COMPILE_CM_CMAKE_LINKER:-}"
    autodetect_compiler_LDFLAGS="$autodetect_compiler_cmake_Specific_LDFLAGS"
    autodetect_compiler_LDLIBS="${DKML_COMPILE_CM_CMAKE_C_STANDARD_LIBRARIES:-}"
    autodetect_compiler_MSVS_NAME="CMake ${DKML_COMPILE_CM_CMAKE_C_COMPILER_ID:-C} compiler${DKML_COMPILE_CM_CMAKE_C_COMPILER:+ at $DKML_COMPILE_CM_CMAKE_C_COMPILER}"
    autodetect_compiler_MSVS_INC="${DKML_COMPILE_CM_CMAKE_C_STANDARD_INCLUDE_DIRECTORIES:-}"
    autodetect_compiler_MSVS_LIB= # CMake has no variables to populate this
    autodetect_compiler_MSVS_PATH=
    autodetect_compiler_add_parent_to_msvs_path() {
        autodetect_compiler_add_parent_to_msvs_path_VAL=$1
        shift
        if [ -n "$autodetect_compiler_add_parent_to_msvs_path_VAL" ]; then
            if [ -x /usr/bin/cygpath ]; then
                autodetect_compiler_add_parent_to_msvs_path_VAL=$(/usr/bin/cygpath -au "$autodetect_compiler_add_parent_to_msvs_path_VAL")
            fi
            case "$autodetect_compiler_add_parent_to_msvs_path_VAL" in
                /*) # absolute Unix path
                    autodetect_compiler_add_parent_to_msvs_path_VAL=$(PATH=/usr/bin:/bin dirname "$autodetect_compiler_add_parent_to_msvs_path_VAL")
                    autodetect_compiler_MSVS_PATH="$autodetect_compiler_add_parent_to_msvs_path_VAL${autodetect_compiler_MSVS_PATH:+:$autodetect_compiler_MSVS_PATH}"
            esac
        fi
    }
    autodetect_compiler_add_parent_to_msvs_path "${DKML_COMPILE_CM_CMAKE_C_COMPILER:-}"
    autodetect_compiler_add_parent_to_msvs_path "${DKML_COMPILE_CM_CMAKE_RC_COMPILER:-}"

    # Transform and write variables
    autodetect_compiler_write_output
}

autodetect_compiler_system() {
    if [ -x /usr/bin/cygpath ]; then
        # https://github.com/microsoft/vswhere
        # %ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe
        autodetect_compiler_system_ProgramFilesX86=$(/usr/bin/cygpath --folder 42)
        autodetect_compiler_system_VSWHERE="$autodetect_compiler_system_ProgramFilesX86/Microsoft Visual Studio/Installer/vswhere.exe"
        if [ -x "$autodetect_compiler_system_VSWHERE" ]; then
            # Check for a compatible Visual Studio with logic similar to dkml-runtime-distribution's Machine.psm1 (which is authoritatize and better!)
            autodetect_compiler_system_COMPATIBLE_INSTALLDIR=$("$autodetect_compiler_system_VSWHERE" -products '*' \
                -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 \
                -requires Microsoft.VisualStudio.Component.VC.14.25.x86.x64 \
                -requires Microsoft.VisualStudio.Component.VC.14.26.x86.x64 \
                -requires Microsoft.VisualStudio.Component.VC.14.29.x86.x64 \
                -requiresAny \
                -property installationPath \
                -latest || true)
            if [ -n "$autodetect_compiler_system_COMPATIBLE_INSTALLDIR" ]; then
                autodetect_compiler_system_COMPATIBLE_INSTALLDIR=$(printf "%s" "$autodetect_compiler_system_COMPATIBLE_INSTALLDIR" | "$DKMLSYS_AWK" 'BEGIN{RS="\r\n"} {print; exit}')
                autodetect_compiler_vsdev "$autodetect_compiler_system_COMPATIBLE_INSTALLDIR"
                return # done. [autodetect_compiler_vsdev] wrote the compiler variables
            fi
        fi
    else
        # Standardized compiler environment variables
        autodetect_compiler_CC=$(command -v gcc || true)
        if [ -n "$autodetect_compiler_CC" ]; then
            case "$autodetect_compiler_PLATFORM_ARCH" in
                *_x86 | *_arm32*)
                    autodetect_compiler_CFLAGS=-m32
                    ;;
            esac
            autodetect_compiler_CXX=$(command -v g++ || true)
            if [ -n "$autodetect_compiler_CXX" ]; then
                case "$autodetect_compiler_PLATFORM_ARCH" in
                    *_x86 | *_arm32*)
                        autodetect_compiler_CXXFLAGS=-m32
                        ;;
                esac
            fi
            autodetect_compiler_AS=$(command -v as || true)
            if [ -n "$autodetect_compiler_AS" ]; then
                case "$autodetect_compiler_PLATFORM_ARCH" in
                    *_x86 | *_arm32*)
                        autodetect_compiler_ASFLAGS=--32
                        ;;
                esac
            fi
            autodetect_compiler_LD=$(command -v ld || true)
            if [ -n "$autodetect_compiler_LD" ]; then
                case "$autodetect_compiler_PLATFORM_ARCH" in
                    linux_x86)    autodetect_compiler_LDFLAGS=-melf_i386 ;;
                    linux_x86_64) autodetect_compiler_LDFLAGS=-melf_x86_64 ;;
                esac
            fi
        fi
    fi

    # Transform and write variables
    autodetect_compiler_write_output
}

# Inputs:
# - env:DKML_COMPILE_DARWIN_OSX_DEPLOYMENT_TARGET - Similar to CMAKE_OSX_DEPLOYMENT_TARGET
autodetect_compiler_darwin() {
    autodetect_compiler_darwin_CLANG_OSXVER_OPT="${DKML_COMPILE_DARWIN_OSX_DEPLOYMENT_TARGET:-}"
    if [ -n "$autodetect_compiler_darwin_CLANG_OSXVER_OPT" ]; then
        autodetect_compiler_darwin_CLANG_OSXVER_OPT=" -mmacosx-version-min=${autodetect_compiler_darwin_CLANG_OSXVER_OPT}"
    fi

    # Standardized compiler environment variables
    #   Hardcode locations of clang and ld since Android NDK, etc. can be in the PATH later
    #   during cross-compilation (which have their own clang/ld).
    autodetect_compiler_CC=$(command -v "clang")
    autodetect_compiler_AS=$autodetect_compiler_CC
    autodetect_compiler_LD=$(command -v "ld")
    if [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_x86_64" ] ; then
        autodetect_compiler_ASFLAGS="-arch x86_64 -c$autodetect_compiler_darwin_CLANG_OSXVER_OPT"
        autodetect_compiler_CFLAGS="-arch x86_64$autodetect_compiler_darwin_CLANG_OSXVER_OPT"
        autodetect_compiler_LDFLAGS="-arch x86_64"
    elif [ "$autodetect_compiler_PLATFORM_ARCH" = "darwin_arm64" ]; then
        autodetect_compiler_ASFLAGS="-arch arm64 -c$autodetect_compiler_darwin_CLANG_OSXVER_OPT"
        autodetect_compiler_CFLAGS="-arch arm64$autodetect_compiler_darwin_CLANG_OSXVER_OPT"
        autodetect_compiler_LDFLAGS="-arch arm64"
    else
        printf "%s\n" "FATAL: check_state autodetect_compiler_darwin + unsupported arch=$autodetect_compiler_PLATFORM_ARCH" >&2
        exit 107
    fi

    # Transform and write variables
    autodetect_compiler_write_output
}

autodetect_compiler_vsdev() {
    # Implementation note: You can use `autodetect_compiler_` as the prefix for your variables,
    # and read the variables created by `autodetect_compiler()`

    autodetect_compiler_vsdev_INSTALLDIR_UNIX=$1
    shift

    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST=$(/usr/bin/cygpath -aw "$autodetect_compiler_vsdev_INSTALLDIR_UNIX")
        autodetect_compiler_vsdev_INSTALLDIR_UNIX=$(/usr/bin/cygpath -au "$autodetect_compiler_vsdev_INSTALLDIR_UNIX")
    else
        autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST="$autodetect_compiler_vsdev_INSTALLDIR_UNIX"
    fi

    # The vsdevcmd.bat is at /c/DiskuvOCaml/BuildTools/Common7/Tools/VsDevCmd.bat.
    if [ -e "$autodetect_compiler_vsdev_INSTALLDIR_UNIX"/Common7/Tools/VsDevCmd.bat ]; then
        autodetect_compiler_vsdev_VSDEVCMD="$autodetect_compiler_vsdev_INSTALLDIR_UNIX/Common7/Tools/VsDevCmd.bat"
    else
        echo "FATAL: No Common7/Tools/VsDevCmd.bat was detected at $autodetect_compiler_vsdev_INSTALLDIR_UNIX" >&2
        exit 107
    fi

    # FIRST, create a file that calls vsdevcmd.bat and then adds a `set` dump.
    # Example:
    #     @call "C:\DiskuvOCaml\BuildTools\Common7\Tools\VsDevCmd.bat" %*
    #     set > "C:\the-WORK-directory\vcvars.txt"
    # to the bottom of it so we can inspect the environment variables.
    # (Less hacky version of https://help.appveyor.com/discussions/questions/18777-how-to-use-vcvars64bat-from-powershell)
    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_VSDEVCMDFILE_WIN=$(/usr/bin/cygpath -aw "$autodetect_compiler_vsdev_VSDEVCMD")
    else
        autodetect_compiler_VSDEVCMDFILE_WIN="$autodetect_compiler_vsdev_VSDEVCMD"
    fi
    {
        printf "@set TEMP=%s\n" "$autodetect_compiler_TEMPDIR_DOS"
        printf "@call %s%s%s %s\n" '"' "$autodetect_compiler_VSDEVCMDFILE_WIN" '"' '%*'
        printf "%s\n" 'if %ERRORLEVEL% neq 0 ('
        printf "%s\n" 'echo.'
        printf "%s\n" 'echo.FATAL: VsDevCmd.bat failed to find a Visual Studio compiler.'
        printf "%s\n" 'echo.'
        printf "%s\n" 'exit /b %ERRORLEVEL%'
        printf "%s\n" ')'
        printf "set > %s%s%s%s\n" '"' "$autodetect_compiler_TEMPDIR_WIN" '\vcvars.txt' '"'
    } > "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat
    #   +x for Cygwin (not needed for MSYS2)
    $DKMLSYS_CHMOD +x "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat
    if [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
        printf "@+: %s/vsdevcmd-and-printenv.bat\n" "$autodetect_compiler_TEMPDIR" >&2
        "$DKMLSYS_SED" 's/^/@+| /' "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat | "$DKMLSYS_AWK" '{print}' >&2
    fi

    # SECOND, construct a function that will call Microsoft's vsdevcmd.bat script.
    # We will use DKML_SYSTEM_PATH for reproducibility.
    if   [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 4 ]; then
        autodetect_compiler_VSCMD_DEBUG=3
    elif [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 3 ]; then
        autodetect_compiler_VSCMD_DEBUG=2
    elif [ "${DKML_BUILD_TRACE:-OFF}" = ON ] && [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ]; then
        autodetect_compiler_VSCMD_DEBUG=1
    else
        autodetect_compiler_VSCMD_DEBUG=
    fi
    if [ -x /usr/bin/cygpath ]; then
        autodetect_compiler_vsdev_SYSTEMPATHUNIX=$(/usr/bin/cygpath --path "$DKML_SYSTEM_PATH")
    else
        autodetect_compiler_vsdev_SYSTEMPATHUNIX="$DKML_SYSTEM_PATH"
    fi
    # https://docs.microsoft.com/en-us/cpp/build/building-on-the-command-line?view=msvc-160#vcvarsall-syntax
    # Notice that for MSVC the build machine is always x86 or x86_64, never ARM or ARM64.
    # And:
    #  * we follow the first triple of Rust naming of aarch64-pc-windows-msvc for the OCAML_HOST_TRIPLET on ARM64
    #  * we use armv7-pc-windows on ARM32 because OCaml's ./configure needs the ARM model (v6, v7, etc.).
    #    WinCE 7.0 and 8.0 support ARMv7, but don't mandate it; WinCE 8.0 extended support from MS is in
    #    2023 so ARMv7 should be fine.
    if [ -n "${VSDEV_VCVARSVER:-}" ] && [ -n "${VSDEV_WINSDKVER}" ]; then
        autodetect_compiler_vsdev_dump_vars_helper() {
            "$DKMLSYS_ENV" PATH="$autodetect_compiler_vsdev_SYSTEMPATHUNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
                "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo -vcvars_ver="$VSDEV_VCVARSVER" -winsdk="$VSDEV_WINSDKVER" \
                "$@" >&2
        }
    else
        autodetect_compiler_vsdev_dump_vars_helper() {
            "$DKMLSYS_ENV" PATH="$autodetect_compiler_vsdev_SYSTEMPATHUNIX" __VSCMD_ARG_NO_LOGO=1 VSCMD_SKIP_SENDTELEMETRY=1 VSCMD_DEBUG="$autodetect_compiler_VSCMD_DEBUG" \
                "$autodetect_compiler_TEMPDIR"/vsdevcmd-and-printenv.bat -no_logo \
                "$@" >&2
        }
    fi
    if [ "$BUILDHOST_ARCH" = windows_x86 ]; then
        # The build host machine is 32-bit ...
        if [ "$autodetect_compiler_PLATFORM_ARCH" = dev ] || [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -arch=x86
            }
            OCAML_HOST_TRIPLET=i686-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="ml.exe"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86_64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x86 -arch=x64
            }
            OCAML_HOST_TRIPLET=x86_64-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="ml64.exe"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm32 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x86 -arch=arm
            }
            OCAML_HOST_TRIPLET=aarch64-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="armasm64.exe"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x86 -arch=arm64
            }
            OCAML_HOST_TRIPLET=armv7-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="armasm.exe"
        else
            printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
            exit 107
        fi
    elif [ "$BUILDHOST_ARCH" = windows_x86_64 ]; then
        # The build host machine is 64-bit ...
        if [ "$autodetect_compiler_PLATFORM_ARCH" = dev ] || [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86_64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -arch=x64
            }
            OCAML_HOST_TRIPLET=x86_64-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="ml64.exe"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_x86 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                if [ "${DKML_PREFER_CROSS_OVER_NATIVE:-OFF}" = ON ]; then
                    autodetect_compiler_vsdev_dump_vars_helper -host_arch=x64 -arch=x86
                else
                    autodetect_compiler_vsdev_dump_vars_helper -arch=x86
                fi
            }
            OCAML_HOST_TRIPLET=i686-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="ml.exe"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm64 ]; then
            # The target machine is 64-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x64 -arch=arm64
            }
            OCAML_HOST_TRIPLET=aarch64-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="armasm64.exe"
        elif [ "$autodetect_compiler_PLATFORM_ARCH" = windows_arm32 ]; then
            # The target machine is 32-bit
            autodetect_compiler_vsdev_dump_vars() {
                autodetect_compiler_vsdev_dump_vars_helper -host_arch=x64 -arch=arm
            }
            OCAML_HOST_TRIPLET=armv7-pc-windows
            autodetect_compiler_vsdev_VALIDATE_ASM="armasm.exe"
        else
            printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
            exit 107
        fi
    else
        printf "%s\n" "FATAL: check_state autodetect_compiler BUILDHOST_ARCH=$BUILDHOST_ARCH autodetect_compiler_PLATFORM_ARCH=$autodetect_compiler_PLATFORM_ARCH" >&2
        exit 107
    fi

    # THIRD, we run the batch file
    autodetect_compiler_vsdev_dump_vars

    # FOURTH, capture everything we will need in the launcher environment except:
    # - PATH (we need to cygpath this, and we need to replace any existing PATH)
    # - MSVS_PREFERENCE (we will add our own)
    # - INCLUDE (we actually add this, but we also add our own vcpkg include path)
    # - LIB (we actually add this, but we also add our own vcpkg library path)
    # - CC,CXX,CFLAGS,CXXFLAGS,AS,ASFLAGS,LD,LDFLAGS,LDLIBS,AR (these are
    #   standardized and will be set and transformed later based on this output)
    # - MSVS_NAME,MSVS_PATH,MSVS_INC,MSVS_LIB,MSVS_ML (also standardized)
    # - _
    # - !ExitCode
    # - TEMP, TMP
    # - PWD
    # - PROMPT
    # - LOGON* (LOGONSERVER)
    # - *APPDATA (LOCALAPPDATA, APPDATA)
    # - ALLUSERSPROFILE
    # - CYGWIN
    # - CYGPATH
    # - CI_* (CI_JOB_JWT, CI_JOB_TOKEN, CI_REGISTRY_PASSWORD) on GitLab CI / GitHub Actions
    # - *_DEPLOY_TOKEN (DKML_PACKAGE_PUBLISH_PRIVATE_DEPLOY_TOKEN)
    # - PG* (PGUSER, PGPASSWORD) on GitHub Actions
    # - OPAM* (OPAMROOT, OPAM_SWITCH)
    # - HOME* (HOME, HOMEDRIVE, HOMEPATH)
    # - USER* (USERNAME, USERPROFILE, USERDOMAIN, USERDOMAIN_ROAMINGPROFILE)
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="}

    $1 != "PATH" &&
    $1 != "MSVS_PREFERENCE" &&
    $1 != "INCLUDE" &&
    $1 != "LIB" &&
    $1 != "CC" &&
    $1 != "CXX" &&
    $1 != "CFLAGS" &&
    $1 != "CXXFLAGS" &&
    $1 != "AS" &&
    $1 != "ASFLAGS" &&
    $1 != "LD" &&
    $1 != "LDFLAGS" &&
    $1 != "LDLIBS" &&
    $1 != "AR" &&
    $1 != "MSVS_NAME" &&
    $1 != "MSVS_PATH" &&
    $1 != "MSVS_INC" &&
    $1 != "MSVS_LIB" &&
    $1 != "MSVS_ML" &&
    $1 !~ /^!ExitCode/ &&
    $1 !~ /^_$/ && $1 != "TEMP" && $1 != "TMP" && $1 != "PWD" &&
    $1 != "PROMPT" && $1 !~ /^LOGON/ && $1 !~ /APPDATA$/ &&
    $1 != "ALLUSERSPROFILE" && $1 != "CYGWIN" && $1 != "CYGPATH" &&
    $1 !~ /^CI_/ && $1 !~ /_DEPLOY_TOKEN$/ && $1 !~ /^PG/ &&
    $1 !~ /^OPAM/ && $1 !~ /^HOME/ &&
    $1 !~ /^USER/ {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}

    $1 == "INCLUDE" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}
    $1 == "LIB" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print name "=" value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/mostvars.eval.sh

    # FIFTH, set autodetect_compiler_COMPILER_PATH to the provided PATH
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="}

    $1 == "PATH" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/winpath.txt
    if [ -x /usr/bin/cygpath ]; then
        # shellcheck disable=SC2086
        /usr/bin/cygpath --path -f - < "$autodetect_compiler_TEMPDIR/winpath.txt" > "$autodetect_compiler_TEMPDIR"/unixpath.txt
    else
        cp "$autodetect_compiler_TEMPDIR/winpath.txt" "$autodetect_compiler_TEMPDIR"/unixpath.txt
    fi
    # shellcheck disable=SC2034
    autodetect_compiler_COMPILER_PATH_UNIX=$("$DKMLSYS_CAT" "$autodetect_compiler_TEMPDIR"/unixpath.txt)
    autodetect_compiler_COMPILER_PATH_WIN=$("$DKMLSYS_CAT" "$autodetect_compiler_TEMPDIR"/winpath.txt)

    # VERIFY: make sure VsDevCmd.bat gave us the correct target assembler (which have unique names per target architecture)
    # shellcheck disable=SC2016
    autodetect_compiler_TGTARCH=$("$DKMLSYS_AWK" '
        BEGIN{FS="="} $1 == "VSCMD_ARG_TGT_ARCH" {name=$1; value=$0; sub(/^[^=]*=/,"",value);                print value}
        ' "$autodetect_compiler_TEMPDIR"/vcvars.txt)
    if ! PATH="$autodetect_compiler_COMPILER_PATH_UNIX" "$autodetect_compiler_vsdev_VALIDATE_ASM" -help >/dev/null 2>/dev/null; then
        echo "FATAL: The Visual Studio installation \"$autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST\" did not place '$autodetect_compiler_vsdev_VALIDATE_ASM' in its PATH." >&2
        echo "       It should be present for the target ABI $autodetect_compiler_PLATFORM_ARCH ($autodetect_compiler_TGTARCH) on a build host $BUILDHOST_ARCH." >&2
        echo "  Fix? Run the Visual Studio Installer and then:" >&2
        if [ -n "${VSDEV_VCVARSVER:-}" ]; then
        echo "       1. Make sure you have the MSVC v${VSDEV_VCVARSVER:-} $autodetect_compiler_TGTARCH Build Tools component." >&2
        else
        echo "       1. Make sure you have the MSVC v142 (or later) $autodetect_compiler_TGTARCH Build Tools component." >&2
        fi
        if [ -n "${VSDEV_WINSDKVER:-}" ]; then
        echo "       2. Also make sure you have the Windows SDK ${VSDEV_WINSDKVER:-} component." >&2
        else
        echo "       2. Also make sure you have the Windows SDK 10.0.18362.0 (or later) component." >&2
        fi
        exit 107
    fi

    # and set the assembler to the full path
    autodetect_compiler_vsdev_MSVS_ML=$(PATH="$autodetect_compiler_COMPILER_PATH_UNIX" command -v "$autodetect_compiler_vsdev_VALIDATE_ASM")

    # SIXTH, set autodetect_compiler_COMPILER_UNIQ_PATH so that it is only the _unique_ entries
    # (the set {autodetect_compiler_COMPILER_UNIQ_PATH} - {DKML_SYSTEM_PATH}) are used. But maintain the order
    # that Microsoft places each path entry.
    printf "%s\n" "$autodetect_compiler_COMPILER_PATH_UNIX" | "$DKMLSYS_AWK" 'BEGIN{RS=":"} {print}' > "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.txt
    "$DKMLSYS_SORT" -u "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.txt > "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.sortuniq.txt
    printf "%s\n" "$DKML_SYSTEM_PATH" | "$DKMLSYS_AWK" 'BEGIN{RS=":"} {print}' | "$DKMLSYS_SORT" -u > "$autodetect_compiler_TEMPDIR"/path.sortuniq.txt
    "$DKMLSYS_COMM" \
        -23 \
        "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.sortuniq.txt \
        "$autodetect_compiler_TEMPDIR"/path.sortuniq.txt \
        > "$autodetect_compiler_TEMPDIR"/vcvars_uniq.txt
    autodetect_compiler_COMPILER_UNIX_UNIQ_PATH=
    while IFS='' read -r autodetect_compiler_line; do
        # if and only if the $autodetect_compiler_line matches one of the lines in vcvars_uniq.txt
        if ! printf "%s\n" "$autodetect_compiler_line" | "$DKMLSYS_COMM" -12 - "$autodetect_compiler_TEMPDIR"/vcvars_uniq.txt | "$DKMLSYS_AWK" 'NF>0{exit 1}'; then
            if [ -z "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH" ]; then
                autodetect_compiler_COMPILER_UNIX_UNIQ_PATH="$autodetect_compiler_line"
            else
                autodetect_compiler_COMPILER_UNIX_UNIQ_PATH="$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH:$autodetect_compiler_line"
            fi
        fi
    done < "$autodetect_compiler_TEMPDIR"/vcvars_entries_unix.txt
    autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH=$(printf "%s\n" "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH" | /usr/bin/cygpath -w --path -f -)

    # SEVENTH, Standardized compiler environment variables
    #   When compiling opam, the opam ./configure cannot handle spaces. Probably
    #   many other programs as well. So use [cygpath -d]
    autodetect_compiler_CC=$(PATH="$autodetect_compiler_COMPILER_PATH_UNIX" command -v cl.exe)
    if [ -x /usr/bin/cygpath ] && [ -e "$autodetect_compiler_CC" ]; then
        autodetect_compiler_CC=$(/usr/bin/cygpath -d "$autodetect_compiler_CC")
    fi
    autodetect_compiler_CXX="$autodetect_compiler_CC"
    autodetect_compiler_CFLAGS=-nologo
    autodetect_compiler_CXXFLAGS=-nologo
    autodetect_compiler_AS="$autodetect_compiler_vsdev_MSVS_ML"
    if [ -x /usr/bin/cygpath ] && [ -e "$autodetect_compiler_AS" ]; then
        autodetect_compiler_AS=$(/usr/bin/cygpath -d "$autodetect_compiler_AS")
    fi
    autodetect_compiler_ASFLAGS=-nologo
    autodetect_compiler_LD=$(PATH="$autodetect_compiler_COMPILER_PATH_UNIX" command -v link.exe)
    if [ -x /usr/bin/cygpath ] && [ -e "$autodetect_compiler_LD" ]; then
        autodetect_compiler_LD=$(/usr/bin/cygpath -d "$autodetect_compiler_LD")
    fi
    autodetect_compiler_LDFLAGS=-nologo
    autodetect_compiler_LDLIBS=
    autodetect_compiler_MSVS_PATH="$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH"

    # === autodetect_compiler_MSVS_NAME
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="} $1 == "VSCMD_VER" {name=$1; value=$0; sub(/^[^=]*=/,"",value);                print "Visual Studio " value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs1.txt
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="}
    $1 == "VCToolsVersion" {name=$1; value=$0; sub(/^[^=]*=/,"",value);                         print "VC Tools " value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs2.txt
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="}
    $1 == "WindowsSDKVersion" {name=$1; value=$0; sub(/^[^=]*=/,"",value); sub(/\\$/,"",value); print "Windows SDK " value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs3.txt
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="} $1 == "VSCMD_ARG_HOST_ARCH" {name=$1; value=$0; sub(/^[^=]*=/,"",value);      print "Host " value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs4.txt
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="} $1 == "VSCMD_ARG_TGT_ARCH" {name=$1; value=$0; sub(/^[^=]*=/,"",value);       print "Target " value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/msvs5.txt
    autodetect_compiler_MSVS1=$($DKMLSYS_CAT "$autodetect_compiler_TEMPDIR"/msvs1.txt)
    autodetect_compiler_MSVS2=$($DKMLSYS_CAT "$autodetect_compiler_TEMPDIR"/msvs2.txt)
    autodetect_compiler_MSVS3=$($DKMLSYS_CAT "$autodetect_compiler_TEMPDIR"/msvs3.txt)
    autodetect_compiler_MSVS4=$($DKMLSYS_CAT "$autodetect_compiler_TEMPDIR"/msvs4.txt)
    autodetect_compiler_MSVS5=$($DKMLSYS_CAT "$autodetect_compiler_TEMPDIR"/msvs5.txt)
    autodetect_compiler_MSVS_NAME="$autodetect_compiler_MSVS1 $autodetect_compiler_MSVS4 $autodetect_compiler_MSVS5 $autodetect_compiler_MSVS2 $autodetect_compiler_MSVS3 $autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST"

    # === autodetect_compiler_MSVS_INC
    # shellcheck disable=SC2016
    autodetect_compiler_MSVS_INC=$("$DKMLSYS_AWK" '
    BEGIN{FS="="} $1 == "INCLUDE" {name=$1; value=$0; sub(/^[^=]*=/,"",value); print value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt)

    # === autodetect_compiler_MSVS_LIB
    # shellcheck disable=SC2016
    autodetect_compiler_MSVS_LIB=$("$DKMLSYS_AWK" '
    BEGIN{FS="="} $1 == "LIB" {name=$1; value=$0; sub(/^[^=]*=/,"",value);     print value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt)

    # === autodetect_compiler_vsdev_VSCMD_VER
    # shellcheck disable=SC2016
    "$DKMLSYS_AWK" '
    BEGIN{FS="="} $1 == "VSCMD_VER" {name=$1; value=$0; sub(/^[^=]*=/,"",value);    print value}
    ' "$autodetect_compiler_TEMPDIR"/vcvars.txt > "$autodetect_compiler_TEMPDIR"/VSCMD_VER.txt

    # EIGHTH, make the launcher script or s-exp
    if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
        autodetect_compiler_escape() {
            autodetect_compiler_escape_sexp "$@"
        }
    elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ] || [ "$autodetect_compiler_OUTPUTMODE" = MSVS_DETECT ]; then
        autodetect_compiler_escape() {
            autodetect_compiler_escape_envarg "$@"
        }
    fi
    autodetect_compiler_supplied_post_transform() {
        # Add all but PATH and MSVS_PREFERENCE, CMAKE_GENERATOR_RECOMMENDED and CMAKE_GENERATOR_INSTANCE_RECOMMENDED to launcher environment
        autodetect_compiler_escape "$autodetect_compiler_TEMPDIR"/mostvars.eval.sh | while IFS='' read -r autodetect_compiler_line; do
            if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
                printf "%s\n" "  (\"$autodetect_compiler_line\")";
            elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
                printf "%s\n" "  '$autodetect_compiler_line' \\";
            fi
        done

        # Add MSVS_PREFERENCE
        autodetect_compiler_vsdev_VSCMD_VER=$(cat "$autodetect_compiler_TEMPDIR"/VSCMD_VER.txt)
        autodetect_compiler_vsdev_MSVS_PREFERENCE=$(vscmd_ver_to_vsstudio_msvspreference "$autodetect_compiler_vsdev_VSCMD_VER")
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            printf "%s\n" "  (\"MSVS_PREFERENCE\" \"$autodetect_compiler_vsdev_MSVS_PREFERENCE\")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "  MSVS_PREFERENCE='$autodetect_compiler_vsdev_MSVS_PREFERENCE' \\"
        fi

        # Add CMAKE_GENERATOR_RECOMMENDED and CMAKE_GENERATOR_INSTANCE_RECOMMENDED
        case "$autodetect_compiler_vsdev_VSCMD_VER" in
            16.*) autodetect_compiler_vsdev_CMAKEGENERATOR="Visual Studio 16 2019" ;;
            17.*) autodetect_compiler_vsdev_CMAKEGENERATOR="Visual Studio 17 2022";;
            *)
                echo "FATAL: The Visual Studio installation \"$autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST\" has a version" >&2
                echo "       $autodetect_compiler_vsdev_VSCMD_VER not supported by DkML." >&2
                echo "  Fix? Use Visual Studio 2019 or Visual Studio 2022." >&2
                exit 107
        esac
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            autodetect_compiler_VSDEV_HOME_BUILDHOST_QUOTED=$(printf "%s" "$autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST" | autodetect_compiler_escape_sexp)
            printf "%s\n" "  (\"CMAKE_GENERATOR_RECOMMENDED\" \"$autodetect_compiler_vsdev_CMAKEGENERATOR\")"
            printf "%s\n" "  (\"CMAKE_GENERATOR_INSTANCE_RECOMMENDED\" \"$autodetect_compiler_VSDEV_HOME_BUILDHOST_QUOTED\")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            printf "%s\n" "  CMAKE_GENERATOR_RECOMMENDED='$autodetect_compiler_vsdev_CMAKEGENERATOR' \\"
            printf "%s\n" "  CMAKE_GENERATOR_INSTANCE_RECOMMENDED='$autodetect_compiler_vsdev_INSTALLDIR_BUILDHOST' \\"
        fi

        # Add PATH
        if [ "$autodetect_compiler_OUTPUTMODE" = SEXP ]; then
            autodetect_compiler_COMPILER_PATH_WIN_QUOTED=$(printf "%s" "$autodetect_compiler_COMPILER_PATH_WIN" | autodetect_compiler_escape_sexp)
            autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH_QUOTED=$(printf "%s" "$autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH" | autodetect_compiler_escape_sexp)
            printf "%s\n" "  (\"PATH\" \"$autodetect_compiler_COMPILER_PATH_WIN_QUOTED\")"
            printf "%s\n" "  (\"PATH_COMPILER\" \"$autodetect_compiler_COMPILER_WINDOWS_UNIQ_PATH_QUOTED\")"
        elif [ "$autodetect_compiler_OUTPUTMODE" = LAUNCHER ]; then
            autodetect_compiler_COMPILER_ESCAPED_UNIX_UNIQ_PATH=$(printf "%s\n" "$autodetect_compiler_COMPILER_UNIX_UNIQ_PATH" | autodetect_compiler_escape_envarg)
            printf "%s\n" "  PATH='$autodetect_compiler_COMPILER_ESCAPED_UNIX_UNIQ_PATH':\"\$PATH\" \\"
        fi
    }
    autodetect_compiler_write_output --has-supplied-post-transform
}

# Set WITHDKMLEXE_BUILDHOST and WITHDKMLEXE_DOS83_OR_BUILDHOST.
#
# The with-dkml binary should have been installed by the DKML or DKSDK installer
# before this function is used. The canonical location is the DKSDK noabi/dkmlexe/bin/
# directory or in the bin/ directory of the DKML home.
#
# Inputs:
# - env:DKSDK_NOABI_DIR - Optional. Set by DKSDK as the noabi/ directory.
# - env:WITHDKMLEXE_BUILDHOST - If already set, will leave it unchanged.
#
# Outputs:
# - env:WITHDKMLEXE_BUILDHOST - The location of the binary 'with-dkml'
# - env:WITHDKMLEXE_DOS83_OR_BUILDHOST - On Windows if on a DOS 8.3 supporting
#   drive then the DOS 8.3 shortname of with-dkml.exe. Otherwise the location
#   of 'with-dkml'
#
# Return Code:
# - 1 if no DKML home and no DKSDK noabi/ directory set
# - 2 if with-dkml not found at canonical location
autodetect_withdkmlexe() {
    if is_unixy_windows_build_machine; then
        autodetect_withdkmlexe_SEP=\\
    else
        autodetect_withdkmlexe_SEP=/
    fi
    if [ -z "${WITHDKMLEXE_BUILDHOST:-}" ]; then
        # Set DKMLHOME_UNIX if available
        autodetect_dkmlvars || true
        if [ -n "${DKSDK_NOABI_DIR:-}" ]; then
            WITHDKMLEXE_BUILDHOST="$DKSDK_NOABI_DIR${autodetect_withdkmlexe_SEP}dkmlexe${autodetect_withdkmlexe_SEP}bin${autodetect_withdkmlexe_SEP}with-dkml"
        elif [ -n "${DKMLHOME_BUILDHOST:-}" ]; then
            WITHDKMLEXE_BUILDHOST="$DKMLHOME_BUILDHOST${autodetect_withdkmlexe_SEP}bin${autodetect_withdkmlexe_SEP}with-dkml"
        else
            return 1
        fi
        if is_unixy_windows_build_machine; then
            WITHDKMLEXE_BUILDHOST="${WITHDKMLEXE_BUILDHOST}.exe"
        fi
    fi
    if [ ! -x "$WITHDKMLEXE_BUILDHOST" ]; then
        return 2
    fi
    if [ -x /usr/bin/cygpath ]; then
        # Note: cygpath -ad will print a warning if the file does not exist.
        #  So we checked above (`return 2`)
        WITHDKMLEXE_DOS83_OR_BUILDHOST=$(/usr/bin/cygpath -ad "$WITHDKMLEXE_BUILDHOST")
    else
        #   shellcheck disable=SC2034
        WITHDKMLEXE_DOS83_OR_BUILDHOST=$WITHDKMLEXE_BUILDHOST
    fi
    return 0
}

# A function that will execute the shell command with error detection enabled and trace
# it on standard error if DKML_BUILD_TRACE=ON (which is default)
#
# Output:
#   - env:DKML_POSIX_SHELL - The path to the POSIX shell. Only set if it wasn't already
#     set.
log_shell() {
    autodetect_system_binaries
    autodetect_posix_shell
    if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then
        printf "%s\n" "@+ $DKML_POSIX_SHELL $*" >&2
        # If trace level > 2 and the first argument is a _non binary_ file then print contents
        if [ "${DKML_BUILD_TRACE_LEVEL:-0}" -ge 2 ] && [ -e "$1" ] && "$DKMLSYS_GREP" -qI . "$1"; then
            log_shell_1="$1"
            shift
            # print args with prefix ... @+:
            escape_args_for_shell "$@" | "$DKMLSYS_SED" 's/^/@+: /' >&2
            printf "\n" >&2
            # print file with prefix ... @+| . Also make sure each line is newline terminated using awk.
            "$DKMLSYS_SED" 's/^/@+| /' "$log_shell_1" | "$DKMLSYS_AWK" '{print}' >&2
            "$DKML_POSIX_SHELL" -eufx "$log_shell_1" "$@"
        else
            "$DKML_POSIX_SHELL" -eufx "$@"
        fi
    else
        "$DKML_POSIX_SHELL" -euf "$@"
    fi
}

# A function that will try to print an ISO8601 timestamp, but will fallback to
# the system default. Always uses UTC timezone.
try_iso8601_timestamp() {
    date -u -Iseconds 2>/dev/null || TZ=UTC date
}

# A function that will print the command and possibly time it (if and only if it uses a full path to
# an executable, so that 'time' does not fail on internal shell functions).
# If --return-error-code is the first argument or LOG_TRACE_RETURN_ERROR_CODE=ON, then instead of exiting the
# function will return the error code.
log_trace() {
    log_trace_RETURN=${LOG_TRACE_RETURN_ERROR_CODE:-OFF}

    log_trace_1="$1"
    if [ "$log_trace_1" = "--return-error-code" ]; then
        shift
        log_trace_RETURN=ON
    fi

    if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then
        printf "[%s] %s\n" "$(try_iso8601_timestamp)" "+ $*" >&2
        if [ -x "$1" ]; then
            time "$@"
        else
            "$@"
        fi
    else
        # use judgement so we essentially have log at an INFO level
        case "$1" in
        rm|cp)
            # debug level. only show when DKML_BUILD_TRACE=ON
            ;;
        git|make|ocaml_configure|ocaml_make|make_host|make_target|*/platform-opam-exec.sh)
            # info level. and can show entire command without polluting the screen
            printf "[%s] %s\n" "$(try_iso8601_timestamp)" "$*" >&2
            ;;
        *)  printf "[%s] %s\n" "$(try_iso8601_timestamp)" "$1" >&2
        esac
        "$@"
    fi
    log_trace_ec="$?"
    if [ "$log_trace_ec" -ne 0 ]; then
        if [ "$log_trace_RETURN" = ON ]; then
            return "$log_trace_ec"
        else
            printf "FATAL: Command failed with exit code %s: %s\n" "$log_trace_ec" "$*"
            exit "$log_trace_ec"
        fi
    fi
}

# [sha256compute FILE] writes the SHA256 checksum (hex encoded) of file FILE to the standard output.
sha256compute() {
    sha256compute_FILE="$1"
    shift
    # For reasons unclear doing the following in MSYS2:
    #   sha256sum 'Z:\source\README.md'
    # will produce a backslash like:
    #   \5518c76ed7234a153941fb7bc94b6e91d9cb8f1c4e22daf169a59b5878c3fc8a *Z:\\source\\README.md
    # So always cygpath the filename if available
    if [ -x /usr/bin/cygpath ]; then
        sha256compute_FILE=$(/usr/bin/cygpath -a "$sha256compute_FILE")
    fi

    autodetect_system_binaries
    if [ -x /usr/bin/shasum ]; then # macOS, OpenBSD, Debian
        # CODESITE #1 (duplicates elsewhere).
        # On Debian shasum is a perl script, and perl needs locale settings or it will complain.
        # Confer: https://www.thomas-krenn.com/en/wiki/Perl_warning_Setting_locale_failed_in_Debian
        # Confer: https://stackoverflow.com/a/52004330/21513816           
        #   shellcheck disable=SC2016
        LANG=C.UTF-8 LC_ALL=C.UTF-8 /usr/bin/shasum -a 256 "$sha256compute_FILE" | "$DKMLSYS_AWK" '{print $1}'
    elif [ -x /usr/bin/sha256sum ]; then # Linux, MSYS2
        #   shellcheck disable=SC2016
        /usr/bin/sha256sum "$sha256compute_FILE" | "$DKMLSYS_AWK" '{print $1}'
    elif [ -x /sbin/sha256 ]; then # FreeBSD
        #   shellcheck disable=SC2016
        /sbin/sha256 -r "$sha256compute_FILE" | "$DKMLSYS_AWK" '{print $1}'
    else
        printf "FATAL: %s\n" "No sha256 checksum utility found" >&2
        exit 107
    fi
}

# [sha256check FILE SUM] checks that the file FILE has a SHA256 checksum (hex encoded) of SUM.
# The function will return nonzero (and exit with failure if `set -e` is enabled) if the checksum does not match.
sha256check() {
    sha256check_FILE="$1"
    shift
    sha256check_SUM="$1"
    shift

    if [ -x /usr/bin/shasum ]; then # macOS, OpenBSD, Debian
        # CODESITE #1 (duplicates elsewhere).
        # On Debian shasum is a perl script, and perl needs locale settings or it will complain.
        # Confer: https://www.thomas-krenn.com/en/wiki/Perl_warning_Setting_locale_failed_in_Debian
        # Confer: https://stackoverflow.com/a/52004330/21513816           
        #   shellcheck disable=SC2016        
        printf "%s  %s" "$sha256check_SUM" "$sha256check_FILE" | LANG=C.UTF-8 LC_ALL=C.UTF-8 /usr/bin/shasum -a 256 -c >&2
    elif [ -x /usr/bin/sha256sum ]; then # Linux, MSYS2
        printf "%s  %s" "$sha256check_SUM" "$sha256check_FILE" | /usr/bin/sha256sum -c >&2
    elif [ -x /sbin/sha256 ]; then # FreeBSD
        /sbin/sha256 -c "$sha256check_SUM" "$sha256check_FILE" >&2
    else
        printf "FATAL: %s\n" "No sha256 checksum utility found" >&2

        # REMOVEME!
        if [ -d /sbin ]; then printf "/sbin:\n" >&2; ls /sbin >&2; fi
        if [ -d /usr/sbin ]; then printf "/usr/sbin:\n" >&2; ls /usr/sbin >&2; fi
        if [ -d /bin ]; then printf "/bin:\n" >&2; ls /bin >&2; fi
        if [ -d /usr/bin ]; then printf "/usr/bin:\n" >&2; ls /usr/bin >&2; fi

        exit 107
    fi
}

# Make a checksum suitable as a cache key, where the cache key will be part of
# a filename stored on disk. We don't want it too big or it will blow away
# Windows 260 char maxpath limit.
#
# Set to 10 characters ... currently only hex characters ... so a cache
# collision every 4^10 = 2^20 values (~1 million). If you need better or a
# cache key that will not change when DKML is upgraded, use sha256compute()
# instead.
cachekey_for_filename() {
    cachekey_for_filename_FILE=$1
    shift
    sha256compute "$cachekey_for_filename_FILE" | cut -c 1-10
}

# [downloadfile URL FILE SUM] downloads from URL into FILE and verifies the SHA256 checksum of SUM.
# If the FILE already exists with the correct checksum it is not redownloaded.
# The function will exit with failure if the checksum does not match.
downloadfile() {
    downloadfile_URL="$1"
    shift
    downloadfile_FILE="$1"
    shift
    downloadfile_SUM="$1"
    shift

    # Set DKMLSYS_*
    autodetect_system_binaries

    if [ -e "$downloadfile_FILE" ]; then
        if sha256check "$downloadfile_FILE" "$downloadfile_SUM"; then
            return 0
        else
            $DKMLSYS_RM -f "$downloadfile_FILE"
        fi
    fi
    if [ "${CI:-}" = true ]; then
        if [ -n "$DKMLSYS_CURL" ]; then
            log_trace "$DKMLSYS_CURL" -L -s "$downloadfile_URL" -o "$downloadfile_FILE".tmp
        elif [ -n "$DKMLSYS_WGET" ]; then
            log_trace "$DKMLSYS_WGET" -q -O "$downloadfile_FILE".tmp "$downloadfile_URL"
        else
            echo "No curl or wget available on the system paths" >&2
            exit 107
        fi
    else
        if [ -n "$DKMLSYS_CURL" ]; then
            log_trace "$DKMLSYS_CURL" -L "$downloadfile_URL" -o "$downloadfile_FILE".tmp
        elif [ -n "$DKMLSYS_WGET" ]; then
            log_trace "$DKMLSYS_WGET" -O "$downloadfile_FILE".tmp "$downloadfile_URL"
        else
            echo "No curl or wget available on the system paths" >&2
            exit 107
        fi
    fi
    if ! sha256check "$downloadfile_FILE".tmp "$downloadfile_SUM"; then
        printf "%s\n" "FATAL: Encountered a corrupted or compromised download from $downloadfile_URL" >&2
        exit 1
    fi
    $DKMLSYS_MV "$downloadfile_FILE".tmp "$downloadfile_FILE"
}

# DEPRECATED
#
# [escape_string_for_shell STR] takes the string STR and escapes it for use in a shell.
# For example,
#  in Bash: STR="hello singlequote=' doublequote=\" world" --> 'hello singlequote='\'' doublequote=" world'
#  in Dash: STR="hello singlequote=' doublequote=\" world" --> 'hello singlequote='"'"' doublequote=" world'
#
# (deprecated) Use escape_args_for_shell() instead
escape_string_for_shell() {
    # shellcheck disable=SC2034
    escape_string_for_shell_STR="$1"
    shift
    # We'll use the bash or dash builtin `set` which escapes spaces and quotes correctly.
    set | grep ^escape_string_for_shell_STR= | sed 's/[^=]*=//'
}

# escape_args_for_shell ARG1 ARG2 ...
#
# If `escape_args_for_shell asd sdfs 'hello there'` then prints `asd sdfs hello\ there`
#
# Prereq: autodetect_system_binaries
escape_args_for_shell() {
    # Confer %q in https://www.gnu.org/software/bash/manual/bash.html#Shell-Builtin-Commands
    bash -c 'printf "%q " "$@"' -- "$@" | $DKMLSYS_SED 's/ $//'
}

# Make the standard input embeddable in single quotes
# (ex. <stdin>=hi ' there ==> <stdout>=hi '"'"' there).
# That is, replace single quotes (') with ('"'"').
#
# It is your responsibility to place outer single quotes around the stdout.
#
# Prereq: autodetect_system_binaries
escape_stdin_for_single_quote() {
    "$DKMLSYS_SED" "s#'#'\"'\"'#g"
}

# Make the standard input work as an OCaml string.
#
# This currently only escapes backslashes and double quotes.
#
# Prereq: autodetect_system_binaries
escape_arg_as_ocaml_string() {
    escape_arg_as_ocaml_string_ARG=$1
    shift
    printf "%s" "$escape_arg_as_ocaml_string_ARG" | "$DKMLSYS_SED" 's#\\#\\\\#g; s#"#\\"#g;'
}

# Convert a path into an absolute path appropriate for the build host machine. That is, Windows
# paths for a Windows host machine and Unix paths for Unix host machines.
#
# Output:
#  env:buildhost_pathize_RETVAL - The absolute path
buildhost_pathize() {
    buildhost_pathize_PATH="$1"
    shift
    if [ -x /usr/bin/cygpath ]; then
        # Trim any trailing backslash because `cygpath -aw .` gives us trailing slash
        buildhost_pathize_RETVAL=$(/usr/bin/cygpath -aw "$buildhost_pathize_PATH" | sed 's#\\$##')
    else
        case "$buildhost_pathize_PATH" in
            /*)
                buildhost_pathize_RETVAL="$buildhost_pathize_PATH" ;;
            ?:*)
                # ex. C:\Windows
                buildhost_pathize_RETVAL="$buildhost_pathize_PATH" ;;
            *)
                # shellcheck disable=SC2034
                buildhost_pathize_RETVAL="$PWD/$buildhost_pathize_PATH" ;;
        esac
    fi
}

# [system_tar ARGS] runs the `tar` command with a system PATH and logging
system_tar() {
    # Set DKML_SYSTEM_PATH
    autodetect_system_path

    PATH=$DKML_SYSTEM_PATH log_trace tar "$@"
}

# [autodetect_system_powershell]
# Outputs:
# - env:DKML_SYSTEM_POWERSHELL
# Return Code: 0 if found, 1 if not found
autodetect_system_powershell() {
    # Set DKML_SYSTEM_PATH (which will include legacy `powershell.exe` if it exists)
    autodetect_system_path

    # Try pwsh first
    system_powershell_PWSH=$(PATH="$DKML_SYSTEM_PATH" command -v pwsh || true)
    if [ -n "$system_powershell_PWSH" ]; then
        DKML_SYSTEM_POWERSHELL="$system_powershell_PWSH"
        return 0
    fi

    # Then powershell first
    system_powershell_POWERSHELL=$(PATH="$DKML_SYSTEM_PATH" command -v powershell || true)
    if [ -n "$system_powershell_POWERSHELL" ]; then
        # shellcheck disable=SC2034
        DKML_SYSTEM_POWERSHELL="$system_powershell_POWERSHELL"
        return 0
    fi

    return 1
}

# [system_powershell ARGS] runs `pwsh` or `powershell` with a system PATH and logging
system_powershell() {
    # Set DKML_SYSTEM_PATH (which will include legacy `powershell.exe` if it exists)
    autodetect_system_path

    # Set DKML_SYSTEM_POWERSHELL
    if ! autodetect_system_powershell; then
        printf "FATAL: No pwsh or powershell available in the system PATH %s\n" "$DKML_SYSTEM_PATH" >&2
        exit 107
    fi

    PATH="$DKML_SYSTEM_PATH" log_trace "$DKML_SYSTEM_POWERSHELL" "$@"
}

# Always prefers bin/ocaml (install-time native code binaries)
# over usr/bin/ocaml (precompiled "global-compile" shims). That way
# native code tools like ocamlopt and ocamlmklib are available
# in opam switches; with [ocaml-system] the directory containing the
# ocamlc executable is added to the PATH with a PATH+= construct.
validate_and_explore_ocamlhome() {
    validate_and_explore_ocamlhome_HOME=$1
    shift
    # Set DKML_OCAMLHOME_BINDIR_UNIX. Validate
    if [ -x "$validate_and_explore_ocamlhome_HOME/bin/ocaml" ] || [ -x "$validate_and_explore_ocamlhome_HOME/bin/ocaml.exe" ]; then
        # shellcheck disable=SC2034
        DKML_OCAMLHOME_BINDIR_UNIX=bin
    elif [ -x "$validate_and_explore_ocamlhome_HOME/usr/bin/ocaml" ] || [ -x "$validate_and_explore_ocamlhome_HOME/usr/bin/ocaml.exe" ]; then
        DKML_OCAMLHOME_BINDIR_UNIX=usr/bin
    else
        unset DKML_OCAMLHOME_BINDIR_UNIX
        printf "FATAL: The OCAMLHOME='%s' does not have a bin/ocaml, usr/bin/ocaml, bin/ocaml.exe or usr/bin/ocaml.exe\n" "$validate_and_explore_ocamlhome_HOME" >&2
        exit 107
    fi
    # Set DKML_OCAMLHOME_UNIX and DKML_OCAMLHOME_ABSBINDIR_BUILDHOST
    if [ -x /usr/bin/cygpath ]; then
        DKML_OCAMLHOME_UNIX=$(/usr/bin/cygpath -au "$validate_and_explore_ocamlhome_HOME")
        DKML_OCAMLHOME_ABSBINDIR_BUILDHOST=$(/usr/bin/cygpath -aw "$DKML_OCAMLHOME_UNIX/$DKML_OCAMLHOME_BINDIR_UNIX")
        DKML_OCAMLHOME_ABSBINDIR_MIXED=$(/usr/bin/cygpath -am "$DKML_OCAMLHOME_UNIX/$DKML_OCAMLHOME_BINDIR_UNIX")
        DKML_OCAMLHOME_ABSBINDIR_UNIX=$(/usr/bin/cygpath -au "$DKML_OCAMLHOME_UNIX/$DKML_OCAMLHOME_BINDIR_UNIX")
    else
        # shellcheck disable=SC2034
        DKML_OCAMLHOME_UNIX="$validate_and_explore_ocamlhome_HOME"
        # shellcheck disable=SC2034
        DKML_OCAMLHOME_ABSBINDIR_BUILDHOST="$validate_and_explore_ocamlhome_HOME/$DKML_OCAMLHOME_BINDIR_UNIX"
        # shellcheck disable=SC2034
        DKML_OCAMLHOME_ABSBINDIR_MIXED="$validate_and_explore_ocamlhome_HOME/$DKML_OCAMLHOME_BINDIR_UNIX"
        # shellcheck disable=SC2034
        DKML_OCAMLHOME_ABSBINDIR_UNIX="$validate_and_explore_ocamlhome_HOME/$DKML_OCAMLHOME_BINDIR_UNIX"
    fi
}

# [has_rsync] checks if the machine has rsync.
has_rsync() {
    if command -v rsync >/dev/null 2>&1; then
        return 0
    fi
    return 1
}

# [spawn_rsync ARGS] runs an rsync with options selected for human readability or for CI.
# You do not need to specify the options:
# * --info=progress2
# * --human-readable
spawn_rsync() {
    spawn_rsync_TERMINAL=OFF
    # check if stdout is a terminal
    if [ -t 1 ]; then
        spawn_rsync_TERMINAL=ON
    fi
    if [ "$spawn_rsync_TERMINAL" = OFF ] || [ "${CI:-}" = true ]; then
        rsync "$@"
    else
        # test whether --info=progress2 works
        spawn_rsync_D1=$(mktemp -d "$WORK"/tmp.XXXXXXXXXX)
        spawn_rsync_D2=$(mktemp -d "$WORK"/tmp.XXXXXXXXXX)
        spawn_rsync_IP2=ON
        rsync -ap --info=progress2 "$spawn_rsync_D1"/ "$spawn_rsync_D2" 2>/dev/null >/dev/null || spawn_rsync_IP2=OFF
        rm -rf "$spawn_rsync_D2"
        rm -rf "$spawn_rsync_D1"

        if [ "$spawn_rsync_IP2" = ON ]; then
            rsync --info=progress2 --human-readable "$@"
        else
            rsync --human-readable "$@"
        fi
    fi
}

# Make a work directory. It is your responsibility to setup a trap as in:
#   trap 'PATH=/usr/bin:/bin rm -rf "$WORK"' EXIT
# Inputs:
#   env:DKML_TMP_PARENTDIR : Optional. If set then it will be used as the
#   parent directory of the work directory.
# Outputs:
#   env:WORK : The work directory
create_workdir() {
    # Our use of mktemp needs to be portable; docs at:
    # * BSD: https://www.freebsd.org/cgi/man.cgi?query=mktemp&sektion=1
    # * GNU: https://www.gnu.org/software/autogen/mktemp.html
    if [ -n "${_CS_DARWIN_USER_TEMP_DIR:-}" ]; then # macOS (see `man mktemp`)
        make_workdir_DEFAULT="$_CS_DARWIN_USER_TEMP_DIR"
    elif [ -n "${TMPDIR:-}" ]; then # macOS (see `man mktemp`)
        make_workdir_DEFAULT=$(printf "%s" "$TMPDIR" | PATH=/usr/bin:/bin sed 's#/$##') # remove trailing slash on macOS
    elif [ -n "${TMP:-}" ]; then # MSYS2 (Windows), Linux
        make_workdir_DEFAULT="$TMP"
    else
        make_workdir_DEFAULT="/tmp"
    fi
    DKML_TMP_PARENTDIR="${DKML_TMP_PARENTDIR:-$make_workdir_DEFAULT}"
    [ ! -e "$DKML_TMP_PARENTDIR" ] && install -d "$DKML_TMP_PARENTDIR"
    WORK=$(PATH=/usr/bin:/bin mktemp -d "$DKML_TMP_PARENTDIR"/dkmlw.XXXXX)
    install -d "$WORK"
}

# When executing an `ocamlc -pp` preprocessor command like
# https://github.com/ocaml/ocaml/blob/77b164c65e7bc8625d0bd79542781952afdd2373/stdlib/Compflags#L18-L20
# (invoked by https://github.com/ocaml/ocaml/blob/77b164c65e7bc8625d0bd79542781952afdd2373/stdlib/Makefile#L201),
# `ocamlc` will use a temporary directory TMPDIR to hold
# the preprocessor output. However for MSYS2 you can get
# a TMPDIR with a space that OCaml 4.12.1 will choke on:
# * `C:\Users\person 1\AppData\Local\Programs\DiskuvOCaml\tools\MSYS2\tmp\ocamlpp87171a`
# * https://gitlab.com/diskuv/diskuv-ocaml/-/issues/13#note_987989664
#
# Root cause:
# https://github.com/ocaml/ocaml/blob/cce52acc7c7903e92078e9fe40745e11a1b944f0/driver/pparse.ml#L27-L29
#
# Mitigation:
# > Filename.get_temp_dir_name (https://v2.ocaml.org/api/Filename.html#VALget_temp_dir_name) uses
# > TMPDIR on Unix and TEMP on Windows
# * Make OCaml's temporary directory be the WORK directory
# * Set it to a DOS 8.3 short path like
#  `C:\Users\PERSON~1\AppData\Local\Programs\DISKUV~1\...\tmp` on Windows.
export_safe_tmpdir() {
  TMPDIR=$WORK
  TEMP=$WORK
  if [ -x /usr/bin/cygpath ]; then
      TMPDIR=$(/usr/bin/cygpath -ad "$TMPDIR")
      TEMP=$(/usr/bin/cygpath -ad "$TEMP")
  fi
  export TMPDIR
  export TEMP
}
