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
# - This file is licensed differently than the rest of the Diskuv OCaml distribution.
#   Keep the Apache License in this file since this file is part of the reproducible
#   build files.
#
#################################################
# _common_tool.sh
#
# Inputs:
#   DKMLDIR: The DkML vendored directory containing '.dkmlroot'.
#
#################################################

# Inputs:
# - env:PLATFORM
# Returns 0 (success) if the PLATFORM is `dev`
is_dev_platform() {
    if [ "$PLATFORM" = "dev" ]; then
        return 0
    fi
    return 1
}

# Checks whether the platform should be running in a reproducible Docker container.
#
# As of Oct 13, 2021 only Linux build hosts can run in Docker containers.
#
# Inputs:
# - env:PLATFORM
# Returns 0 (success) if the PLATFORM is not `dev` and is a Linux based platform.
is_reproducible_platform() {
    if [ "$PLATFORM" = "dev" ]; then
        return 1
    fi
    is_arg_linux_based_platform "$PLATFORM"
}

if [ ! -e "$DKMLDIR/.dkmlroot" ]; then echo "FATAL: Not launched within a directory tree containing a .dkmlroot file" >&2 ; exit 1; fi

# set $dkml_root_version
# shellcheck disable=SC1091
. "$DKMLDIR"/.dkmlroot
dkml_root_version=$(printf "%s" "$dkml_root_version" | PATH=/usr/bin:/bin tr -d '\r')

if [ -x /usr/bin/cygpath ]; then
    OS_DIR_SEP="\\"
else
    # shellcheck disable=SC2034
    OS_DIR_SEP=/
fi

# Set OPAM_CACHE_SUBDIR and cache keys like WRAP_COMMANDS_KEY
# shellcheck disable=SC2034
OPAM_CACHE_SUBDIR=.dkml/opam-cache
# shellcheck disable=SC2034
WRAP_COMMANDS_CACHE_KEY=wrap-commands."$dkml_root_version"

# shellcheck disable=SC1091
. "$DKMLDIR/vendor/drc/unix/crossplatform-functions.sh"

# Work directory $WORK
create_workdir
trap 'PATH=/usr/bin:/bin rm -rf "$WORK"' EXIT

# Execute a command either for the dev environment or for the
# reproducible sandbox corresponding to `$PLATFORM`
# which must be defined.
#
# Usage: [options] DKML_PLATFORM
#   DKML_PLATFORM         - which platform to run in (not "dev")
#
# Options:
#   -c                    - Optional. If enabled then compilation environment variables
#                           like CC will be added to the environment. This may be
#                           time-consuming, especially on Windows which needs to call
#                           VsDevCmd.bat
# Inputs:
#   env:PLATFORM_EXEC_PRE_SINGLE - optional. acts as hook.
#                           the specified bash statements, if any, are 'eval'-d _before_ the
#                           command line arguments are executed.
#   env:PLATFORM_EXEC_PRE_DOUBLE - optional. acts as hook.
#                           the specified bash statements, if any, are executed
#                           and their standard output captured. that standard
#                           output is 'dos2unix'-d and 'eval'-d _before_ the
#                           command line arguments are executed.
#                           You can think of it behaving like:
#                             eval "$PLATFORM_EXEC_PRE_DOUBLE" | dos2unix > /tmp/eval.sh
#                             eval /tmp/eval.sh
#   $@                    - the command line arguments that will be executed
exec_in_platform() {
    # option parsing
    if [ "$1" = "-c" ]; then
        _exec_dev_or_arch_helper_COMPILATION=ON
        shift
    else
        _exec_dev_or_arch_helper_COMPILATION=OFF
    fi
    _exec_dev_or_arch_helper_DKMLPLATFORM="$1"
    shift
    if [ "$_exec_dev_or_arch_helper_DKMLPLATFORM" = dev ]; then
        printf "FATAL: exec_in_platform() must not have DKMLABI=dev\n" >&2
        exit 107
    fi

    _exec_dev_or_arch_helper_CMDFILE="$WORK"/_exec_dev_or_arch_helper-cmdfile.sh
    _exec_dev_or_arch_helper_CMDARGS="$WORK"/_exec_dev_or_arch_helper-cmdfile.args
    true > "$_exec_dev_or_arch_helper_CMDARGS"
    if [ "${_exec_dev_or_arch_helper_COMPILATION:-}" = ON ]; then
        printf "  -c" >> "$_exec_dev_or_arch_helper_CMDARGS"
    fi

    for _exec_dev_or_arch_helper_ARG in "$@"; do
        printf "%s\n  '%s'" " \\" "$_exec_dev_or_arch_helper_ARG" >> "$_exec_dev_or_arch_helper_CMDARGS"
    done
    if [ -n "${PLATFORM_EXEC_PRE_SINGLE:-}" ]; then
        ACTUAL_PRE_HOOK_SINGLE="$PLATFORM_EXEC_PRE_SINGLE"
    fi
    if [ -n "${PLATFORM_EXEC_PRE_DOUBLE:-}" ]; then
        ACTUAL_PRE_HOOK_DOUBLE="$PLATFORM_EXEC_PRE_DOUBLE"
    fi
    printf "%s\n" "exec '$DKMLDIR'/vendor/drc/unix/_within_dev.sh -p '$_exec_dev_or_arch_helper_DKMLPLATFORM' -0 '${ACTUAL_PRE_HOOK_SINGLE:-}' -1 '${ACTUAL_PRE_HOOK_DOUBLE:-}' \\" > "$_exec_dev_or_arch_helper_CMDFILE"

    cat "$_exec_dev_or_arch_helper_CMDARGS" >> "$_exec_dev_or_arch_helper_CMDFILE"

    log_shell "$_exec_dev_or_arch_helper_CMDFILE"
}

# Outputs:
# - env:DKSDKCACHEDIR_BUILDHOST - The dksdk cache directory
set_dksdkcachedir() {
    if is_unixy_windows_build_machine; then
        DKSDKCACHEDIR_BUILDHOST="${LOCALAPPDATA}\\dksdk\\cache"
    else
        # shellcheck disable=SC2034
        DKSDKCACHEDIR_BUILDHOST="${XDG_CACHE_HOME:-$HOME/.cache}/dksdk"
    fi
}

# Sets the location of the opam executable.
# Prefers ~/opt/opam/bin/opam[-real]{.exe}; otherwise looks in the PATH. The
# [-real] suffix is preferred the most.
# Does nothing if OPAMEXE already set.
#
# Inputs:
# - env:OPAMHOME - If specified, use <OPAMHOME>/bin/opam or <OPAMHOME>/bin/opam.exe
# - env:OPAMEXE - Optional. The location of opam-real or opam. If set this
#   function does nothing
# - env:OPAMEXE_OR_HOME - Optional. If a directory, can be used instead of OPAMHOME above.
#   If an executable, can be used instead of OPAMEXE above.
# Outputs:
# - env:OPAMEXE - The location of opam or opam.exe
# Exits with non-zero exit code on error
set_opamexe() {
    if [ -n "${OPAMEXE:-}" ]; then
        return
    fi
    if [ -n "${OPAMEXE_OR_HOME:-}" ]; then
        if [ -d "${OPAMEXE_OR_HOME:-}" ]; then
            # shellcheck disable=SC2034
            OPAMHOME=$OPAMEXE_OR_HOME
        elif [ -x "${OPAMEXE_OR_HOME:-}" ]; then
            OPAMEXE=$OPAMEXE_OR_HOME
            return
        fi
    fi
    if [ -n "${OPAMHOME:-}" ]; then
        if [ -e "$OPAMHOME/bin/opam-real.exe" ]; then
            OPAMEXE="$OPAMHOME/bin/opam-real.exe"
            return
        elif [ -e "$OPAMHOME/bin/opam-real" ]; then
            OPAMEXE="$OPAMHOME/bin/opam-real"
            return
        elif [ -e "$OPAMHOME/bin/opam.exe" ]; then
            OPAMEXE="$OPAMHOME/bin/opam.exe"
            return
        elif [ -e "$OPAMHOME/bin/opam" ]; then
            OPAMEXE="$OPAMHOME/bin/opam"
            return
        else
            printf "FATAL: OPAMHOME is %s yet %s/bin/opam[-real]{.exe} does not exist\n" "$OPAMHOME" "$OPAMHOME"
            exit 107
        fi
    fi
    if [ -e "$HOME/opt/opam/bin/opam-real.exe" ]; then
        OPAMEXE="$HOME/opt/opam/bin/opam-real.exe"
        return
    elif [ -e "$HOME/opt/opam/bin/opam-real" ]; then
        OPAMEXE="$HOME/opt/opam/bin/opam-real"
        return
    elif [ -e "$HOME/opt/opam/bin/opam.exe" ]; then
        OPAMEXE="$HOME/opt/opam/bin/opam.exe"
        return
    elif [ -e "$HOME/opt/opam/bin/opam" ]; then
        OPAMEXE="$HOME/opt/opam/bin/opam"
        return
    fi
    set_opamexe_EXE=$(command -v opam-real 2>/dev/null || true)
    if [ -n "$set_opamexe_EXE" ]; then
        # shellcheck disable=SC2034
        OPAMEXE="$set_opamexe_EXE"
        return
    fi
    set_opamexe_EXE=$(command -v opam 2>/dev/null || true)
    if [ -n "$set_opamexe_EXE" ]; then
        # shellcheck disable=SC2034
        OPAMEXE="$set_opamexe_EXE"
        return
    fi
    # Not found
    printf "FATAL: Opam was not found. Please follow https://opam.ocaml.org/doc/Install.html\n"
    exit 107
}

# Finds the Opam root.
#
# A side-effect of this call is that `opam init` may be called.
#
# Inputs:
# - env:DKML_OPAM_ROOT - If specified, uses <DKML_OPAM_ROOT> as the Opam root
# - env:STATEDIR - If specified, uses <STATEDIR>/opam as the Opam root
# - env:OPAMHOME - If specified, use <OPAMHOME>/bin/opam or <OPAMHOME>/bin/opam.exe
# Outputs:
# - env:OPAMROOTDIR_BUILDHOST - The path to the Opam root directory that is usable only on the
#     build machine (not from within a container)
# - env:OPAMROOTDIR_EXPAND - Use this output for `opam --root OPAMROOTDIR_EXPAND`.
#     For known versions of Opam this is equivalent to OPAMROOTDIR_BUILDHOST.
set_opamrootdir() {
    set_opamexe
    if [ -n "${DKML_OPAM_ROOT:-}" ]; then
        OPAMROOTDIR_BUILDHOST="$DKML_OPAM_ROOT"
        if [ -x /usr/bin/cygpath ]; then OPAMROOTDIR_BUILDHOST=$(/usr/bin/cygpath -aw "$OPAMROOTDIR_BUILDHOST"); fi
    elif [ -n "${STATEDIR:-}" ]; then
        OPAMROOTDIR_BUILDHOST="$STATEDIR/opam"
        if [ -x /usr/bin/cygpath ]; then OPAMROOTDIR_BUILDHOST=$(/usr/bin/cygpath -aw "$OPAMROOTDIR_BUILDHOST"); fi
    elif is_unixy_windows_build_machine; then
        if [ -n "${OPAMROOT:-}" ]; then
            # If the developer sets OPAMROOT with an environment variable, then we will respect that
            # just like `opam` would do.
            OPAMROOTDIR_BUILDHOST="$OPAMROOT"
        else
            # Conform to https://github.com/ocaml/opam/pull/4815#issuecomment-910137754
            OPAMROOTDIR_BUILDHOST="${LOCALAPPDATA}\\opam"
        fi
    else
        if [ -n "${OPAMROOT:-}" ]; then
            OPAMROOTDIR_BUILDHOST="$OPAMROOT"
        elif [ -z "${OPAMROOTDIR_BUILDHOST:-}" ]; then
            # Use existing Opam to know where the Opam root is
            OPAMROOTDIR_BUILDHOST=$($OPAMEXE var --global root 2>/dev/null || true)
            if [ -z "$OPAMROOTDIR_BUILDHOST" ]; then
                # Opam is not initialized. We probably got:
                #   [ERROR] Opam has not been initialised, please run `opam init'
                # So conform to https://github.com/ocaml/opam/issues/3766 with an
                # opam root change intended for opam 2.3.
                # CHANGE NOTICE: Also change dkml-runtime-apps's [opam_context.ml]
                set_opamrootdir_VER=$($OPAMEXE --version)
                case "$set_opamrootdir_VER" in
                    1*)
                        printf "FATAL: You will need to upgrade %s to Opam 2.0+\n" "$OPAMEXE"
                        exit 107
                        ;;
                    2.0.*|2.1.*|2.2.*)
                        OPAMROOTDIR_BUILDHOST="$HOME/.opam"
                        ;;
                    *)
                        OPAMROOTDIR_BUILDHOST="${XDG_CONFIG_HOME:-$HOME/.config}/opam"
                        ;;
                esac
            fi
        fi
    fi
    # shellcheck disable=SC2034
    OPAMROOTDIR_EXPAND="$OPAMROOTDIR_BUILDHOST"
}

# [set_opamswitchdir_of_system DKMLABI]
#
# Select the [dkml] switch.
#
# The default [dkml] switch is the 'dkml' global switch.
#
# In highest precedence order:
# 1. If the environment variable DKSDK_INVOCATION is set to ON,
#    the [dkml] switch will be the 'dksdk-<DKML_HOST_ABI>' global switch.
# 2. If there is a Diskuv OCaml installation, as decided by autodetect_dkmlvars,
#    then the [dkml] switch is the local <DiskuvOCamlHome>/dkml switch.
#
# These rules allow for the DKML OCaml system compiler to be distinct from
# any DKSDK OCaml system compiler.
#
# Inputs:
# - env:DKSDK_INVOCATION - Optional. If ON the name of the switch will end in dksdk-${DKML_HOST_ABI}
#   rather than dkml. The DKSDK system switch uses a system compiler (not a base compiler), so
#   the DKML and DKSDK switches must be segregated.
# - env:DKML_OPAM_ROOT - If specified, uses <DKML_OPAM_ROOT> as the Opam root
# - env:STATEDIR
# Outputs:
# - env:OPAMSWITCHFINALDIR_BUILDHOST - Either:
#     The path to the switch that represents the build directory that is usable only on the
#     build machine (not from within a container). For an external (aka local) switch the returned path will be
#     a `.../_opam`` folder which is where the final contents of the switch live. Use OPAMSWITCHNAME_EXPAND
#     if you want an XXX argument for `opam --switch XXX` rather than this path which is not compatible.
# - env:OPAMSWITCHNAME_EXPAND - Either
#     The path to the switch **not including any _opam subfolder** that works as an argument to `exec_in_platform` -OR-
#     The name of a global switch that represents the build directory.
#     OPAMSWITCHNAME_EXPAND works inside or outside of a container.
set_opamswitchdir_of_system() {
    set_opamswitchdir_of_system_PLATFORM=$1
    shift

    # !!!!!!!!!!!!!
    # CHANGE NOTICE
    # !!!!!!!!!!!!!
    #
    # Do not change the behavior of this function without also
    # changing diskuv-sdk > 140-opam-switch-dkml > CMakeLists.txt.

    # Name the switch. Since there may be a zillion switches in the user's default
    # OPAMROOT (ie. no state dir), we have an unambiguous switch name that identifies
    # that the switch is for Diskuv (either through "dksdk-*" or "diskuv-*" or
    # a local switch that is part of DiskuvOCamlHome).
    if [ "${DKSDK_INVOCATION:-OFF}" = ON ]; then
        set_opamswitchdir_of_system_SWITCHBASE="dksdk-$set_opamswitchdir_of_system_PLATFORM"
        set_opamswitchdir_of_system_SWITCHBASE_UNAMBIGUOUS="$set_opamswitchdir_of_system_SWITCHBASE"
    else
        set_opamswitchdir_of_system_SWITCHBASE="dkml"
        set_opamswitchdir_of_system_SWITCHBASE_UNAMBIGUOUS="dkml"
    fi

    # Set OPAMROOTDIR_BUILDHOST (uses DKML_OPAM_ROOT and/or STATEDIR when set)
    set_opamrootdir
    # Set DKMLHOME_UNIX if available
    autodetect_dkmlvars || true
    # Set OPAMSWITCHFINALDIR_BUILDHOST and OPAMSWITCHNAME_EXPAND
    if [ -n "${DKML_OPAM_ROOT:-}" ] || [ -n "${STATEDIR:-}" ]; then
        OPAMSWITCHNAME_EXPAND="${set_opamswitchdir_of_system_SWITCHBASE}"
        OPAMSWITCHFINALDIR_BUILDHOST="$OPAMROOTDIR_BUILDHOST${OS_DIR_SEP}${set_opamswitchdir_of_system_SWITCHBASE}"
    elif [ -n "${DKMLHOME_BUILDHOST:-}" ]; then
        OPAMSWITCHNAME_EXPAND="$DKMLHOME_BUILDHOST${OS_DIR_SEP}${set_opamswitchdir_of_system_SWITCHBASE}"
        OPAMSWITCHFINALDIR_BUILDHOST="$OPAMSWITCHNAME_EXPAND${OS_DIR_SEP}_opam"
    else
        OPAMSWITCHNAME_EXPAND="${set_opamswitchdir_of_system_SWITCHBASE_UNAMBIGUOUS}"
        # shellcheck disable=SC2034
        OPAMSWITCHFINALDIR_BUILDHOST="$OPAMROOTDIR_BUILDHOST${OS_DIR_SEP}${set_opamswitchdir_of_system_SWITCHBASE_UNAMBIGUOUS}"
    fi
}

# [set_opamrootandswitchdir TARGETLOCAL_OPAMSWITCH TARGETGLOBAL_OPAMSWITCH]
#
# Either the local TARGETLOCAL_OPAMSWITCH switch or the global
# TARGETGLOBAL_OPAMSWITCH switch must be specified (not both).
#
# Outputs:
# - env:OPAMROOTDIR_BUILDHOST - [As per set_opamrootdir] The path to the Opam root directory that is usable only on the
#     build machine (not from within a container)
# - env:OPAMROOTDIR_EXPAND - [As per set_opamrootdir] The path to the Opam root directory switch that works as an
#     argument to `exec_in_platform`
# - env:OPAMSWITCHFINALDIR_BUILDHOST - Either:
#     The path to the switch that represents the build directory that is usable only on the
#     build machine (not from within a container). For an external (aka local) switch the returned path will be
#     a `.../_opam`` folder which is where the final contents of the switch live. Use OPAMSWITCHNAME_EXPAND
#     if you want an XXX argument for `opam --switch XXX` rather than this path which is not compatible.
# - env:OPAMSWITCHNAME_BUILDHOST - The name of the switch seen on the build host from `opam switch list --short`
# - env:OPAMSWITCHISGLOBAL - Either ON (switch is global) or OFF (switch is external; aka local)
# - env:OPAMSWITCHNAME_EXPAND - Use this output for `opam --switch OPAMSWITCHNAME_EXPAND`.
#     For known versions of Opam this is equivalent to OPAMSWITCHNAME_BUILDHOST.
set_opamrootandswitchdir() {
    set_opamrootandswitchdir_TARGETLOCAL=$1
    shift
    set_opamrootandswitchdir_TARGETGLOBAL=$1
    shift

    if [ -z "$set_opamrootandswitchdir_TARGETLOCAL" ] && [ -z "$set_opamrootandswitchdir_TARGETGLOBAL" ]; then
        echo "FATAL: Only one of TARGETLOCAL_OPAMSWITCH TARGETGLOBAL_OPAMSWITCH may be specified" >&2
        echo "FATAL: Got: '$set_opamrootandswitchdir_TARGETLOCAL' and '$set_opamrootandswitchdir_TARGETGLOBAL'" >&2
        exit 71
    fi
    if [ -n "$set_opamrootandswitchdir_TARGETLOCAL" ] && [ -n "$set_opamrootandswitchdir_TARGETGLOBAL" ]; then
        echo "FATAL: Only one of TARGETLOCAL_OPAMSWITCH TARGETGLOBAL_OPAMSWITCH may be specified" >&2
        echo "FATAL: Got: '$set_opamrootandswitchdir_TARGETLOCAL' and '$set_opamrootandswitchdir_TARGETGLOBAL'" >&2
        exit 71
    fi

    # Set OPAMROOTDIR_BUILDHOST and OPAMROOTDIR_EXPAND
    set_opamrootdir

    if [ -n "$set_opamrootandswitchdir_TARGETLOCAL" ]; then
        OPAMSWITCHISGLOBAL=OFF

        if [ -x /usr/bin/cygpath ]; then
            set_opamrootandswitchdir_BUILDHOST=$(/usr/bin/cygpath -aw "$set_opamrootandswitchdir_TARGETLOCAL")
        else
            set_opamrootandswitchdir_BUILDHOST="$set_opamrootandswitchdir_TARGETLOCAL"
        fi
        OPAMSWITCHFINALDIR_BUILDHOST="$set_opamrootandswitchdir_BUILDHOST${OS_DIR_SEP}_opam"
        OPAMSWITCHNAME_EXPAND="$set_opamrootandswitchdir_BUILDHOST"
        OPAMSWITCHNAME_BUILDHOST="$set_opamrootandswitchdir_BUILDHOST"
    else
        # shellcheck disable=SC2034
        OPAMSWITCHISGLOBAL=ON

        set_opamrootandswitchdir_BUILDHOST="$OPAMROOTDIR_BUILDHOST${OS_DIR_SEP}$set_opamrootandswitchdir_TARGETGLOBAL"
        if [ -x /usr/bin/cygpath ]; then
            set_opamrootandswitchdir_BUILDHOST=$(/usr/bin/cygpath -aw "$set_opamrootandswitchdir_BUILDHOST")
        fi
        # shellcheck disable=SC2034
        OPAMSWITCHFINALDIR_BUILDHOST="$set_opamrootandswitchdir_BUILDHOST"
        # shellcheck disable=SC2034
        OPAMSWITCHNAME_EXPAND="$set_opamrootandswitchdir_TARGETGLOBAL"
        # shellcheck disable=SC2034
        OPAMSWITCHNAME_BUILDHOST="$set_opamrootandswitchdir_TARGETGLOBAL"
    fi
}

# is_empty_opam_switch_present SWITCHDIR
#
# SWITCHDIR - Must be the `_opam/` subfolder if the switch is an external (aka local)
#    switch. Otherwise the switch is a global switch and must be the subfolder of
#    the Opam root directory (ex. ~/.opam) that has the same name as the global switch.
#
# Returns: True (0) if and only if the switch exists and is at least an `opam switch create --empty` switch.
#          False (1) otherwise.
is_empty_opam_switch_present() {
    is_empty_opam_switch_present_switchdir_buildhost=$1
    shift
    if [ -s "$is_empty_opam_switch_present_switchdir_buildhost/.opam-switch/switch-config" ]
    then
        return 0
    else
        return 1
    fi
}

# is_minimal_opam_switch_present SWITCHDIR
#
# SWITCHDIR - Must be the `_opam/` subfolder if the switch is an external (aka local)
#    switch. Otherwise the switch is a global switch and must be the subfolder of
#    the Opam root directory (ex. ~/.opam) that has the same name as the global switch.
#
# Returns: True (0) if and only if the switch exists and has either an OCaml base compiler
#          or evidence of an OCaml system compiler.
#          False (1) otherwise.
is_minimal_opam_switch_present() {
    is_minimal_opam_switch_present_switchdir_buildhost=$1
    shift
    if
    [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/.opam-switch/switch-config" ] ||
    [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/.opam-switch/switch-state" ] ||
    # gen_ocaml_config.ml is evidence that a system compiler was configured;
    # see https://github.com/ocaml/opam-repository/blob/master/packages/ocaml-system/ocaml-system.4.12.1/files/gen_ocaml_config.ml.in
    [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/share/ocaml-config/gen_ocaml_config.ml" ] ||
    [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/bin/ocamlc" ] ||
    [ -e "$is_minimal_opam_switch_present_switchdir_buildhost/bin/ocamlc.exe" ]
    then
        return 0
    else
        return 1
    fi
}

# is_minimal_opam_root_present ROOTDIR
#
# ROOTDIR - The Opam root directory.
#
# Returns: True (0) if and only if the root exists and has an Opam configuration file.
#          False (1) otherwise.
is_minimal_opam_root_present() {
    is_minimal_opam_root_present_rootdir_buildhost=$1
    shift
    if [ -e "$is_minimal_opam_root_present_rootdir_buildhost/config" ]
    then
        return 0
    else
        return 1
    fi
}

# get_opam_switch_state_toplevelsection SWITCHDIR TOPLEVEL_SECTION_NAME
#
# Speedy way to grab sections from Opam. Opam is pretty speedy but
# `opam install utop` for example requires that `vcvars64.bat` is loaded
# on Windows which can take seconds.
#
# Inputs:
#
# SWITCHDIR - Must be the `_opam/` subfolder if the switch is an external (aka local)
#    switch. Otherwise the switch is a global switch and must be the subfolder of
#    the Opam root directory (ex. ~/.opam) that has the same name as the global switch.
# TOPLEVEL_SECTION_NAME - The name of the section. See Examples.
#
# Output: [stdout] The toplevel section of `switch-state` that
#   has the name TOPLEVEL_SECTION_NAME
#
# Examples:
#   If `~/_opam/.opam-switch/switch-state` contained:
#        compiler: ["ocaml-variants.4.12.0+msvc64+msys2"]
#        roots: [
#          "bigstringaf.0.8.0"
#          "digestif.1.0.1"
#          "dune-configurator.2.9.0"
#          "ocaml-lsp-server.1.8.2"
#          "ocaml-variants.4.12.0+msvc64+msys2"
#          "ocamlformat.0.18.0"
#          "ppx_expect.v0.14.1"
#          "utop.2.8.0"
#        ]
#   Then `get_opam_switch_state_toplevelsection ~/_opam compiler` would give:
#        compiler: ["ocaml-variants.4.12.0+msvc64+msys2"]
#   and `get_opam_switch_state_toplevelsection ~/_opam roots` would give:
#        roots: [
#          "bigstringaf.0.8.0"
#          "digestif.1.0.1"
#          "dune-configurator.2.9.0"
#          "ocaml-lsp-server.1.8.2"
#          "ocaml-variants.4.12.0+msvc64+msys2"
#          "ocamlformat.0.18.0"
#          "ppx_expect.v0.14.1"
#          "utop.2.8.0"
#        ]
get_opam_switch_state_toplevelsection() {
    get_opam_switch_state_toplevelsection_switchdir_buildhost=$1
    shift
    get_opam_switch_state_toplevelsection_toplevel_section_name=$1
    shift
    if [ ! -e "${get_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state" ]; then
        echo "FATAL: There is no Opam switch at ${get_opam_switch_state_toplevelsection_switchdir_buildhost}" >&2
        exit 71
    fi
    awk -v section="$get_opam_switch_state_toplevelsection_toplevel_section_name" \
        '$1 ~ ":" {state=0} $1==(section ":") {state=1} state==1{print}' \
        "${get_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state"
}

# delete_opam_switch_state_toplevelsection SWITCHDIR TOPLEVEL_SECTION_NAME
#
# Prints out the switch state with the specified toplevel section name removed.
# See get_opam_switch_state_toplevelsection for more details.
delete_opam_switch_state_toplevelsection() {
    delete_opam_switch_state_toplevelsection_switchdir_buildhost=$1
    shift
    delete_opam_switch_state_toplevelsection_toplevel_section_name=$1
    shift
    if [ ! -e "${delete_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state" ]; then
        echo "FATAL: There is no Opam switch at ${delete_opam_switch_state_toplevelsection_switchdir_buildhost}" >&2
        exit 71
    fi
    awk -v section="$delete_opam_switch_state_toplevelsection_toplevel_section_name" \
        '$1 ~ ":" {state=0} $1==(section ":") {state=1} state==0{print}' \
        "${delete_opam_switch_state_toplevelsection_switchdir_buildhost}/.opam-switch/switch-state"
}

# [print_opam_logs_on_error CMD [ARGS...]] will execute `CMD [ARGS...]`. If the CMD fails _and_
# the environment variable `DKML_BUILD_PRINT_LOGS_ON_ERROR` is `ON` then print out Opam log files
# to the standard error.
print_opam_logs_on_error() {
    # save `set` state
    print_opam_logs_on_error_OLDSTATE=$(set +o)
    set +e # allow the next command to possibly fail
    "$@"
    print_opam_logs_on_error_EC=$?
    if [ "$print_opam_logs_on_error_EC" -ne 0 ]; then
        if [ "${DKML_BUILD_PRINT_LOGS_ON_ERROR:-}" = ON ]; then
            printf "\n\n========= [START OF TROUBLESHOOTING] ===========\n\n" >&2

            if find . -maxdepth 0 -mmin -240 2>/dev/null >/dev/null; then
                FINDARGS="-mmin -240" # is -mmin supported? BSD (incl. macOS), MSYS2, GNU
            else
                FINDARGS="-mtime -1" # use 1 day instead. Solaris
            fi

            # print _one_ of the environment
            # shellcheck disable=SC2030 disable=SC2086
            find "$OPAMROOTDIR_BUILDHOST"/log -mindepth 1 -maxdepth 1 $FINDARGS -name "*.env" ! -name "log-*.env" ! -name "ocaml-variants-*.env" | head -n1 | while read -r dump_on_error_LOG; do
                # shellcheck disable=SC2031
                dump_on_error_BLOG=$(basename "$dump_on_error_LOG")
                printf "\n\n========= [TROUBLESHOOTING] %s ===========\n# To save space, this is only one of the many similar Opam environment files that have been printed.\n\n" "$dump_on_error_BLOG" >&2
                cat "$dump_on_error_LOG" >&2
            done

            # print all output files (except ocaml-variants)
            # shellcheck disable=SC2086
            find "$OPAMROOTDIR_BUILDHOST"/log -mindepth 1 -maxdepth 1 $FINDARGS -name "*.out" ! -name "log-*.out" ! -name "ocaml-variants-*.out" | while read -r dump_on_error_LOG; do
                dump_on_error_BLOG=$(basename "$dump_on_error_LOG")
                printf "\n\n========= [TROUBLESHOOTING] %s ===========\n\n" "$dump_on_error_BLOG" >&2
                cat "$dump_on_error_LOG" >&2
            done

            # TODO: we could add other logs files from the switch, like
            # `$env:LOCALAPPDATA\Programs\DiskuvOCaml\0\system\_opam\.opam-switch\build\ocamlfind.1.9.1\ocargs.log`

            printf "The command %s failed with exit code $print_opam_logs_on_error_EC. Scroll up to see the [TROUBLESHOOTING] logs that begin at the [START OF TROUBLESHOOTING] line\n" "$*" >&2
        fi

        exit $print_opam_logs_on_error_EC
    fi
    # restore old state
    eval "$print_opam_logs_on_error_OLDSTATE"
}
