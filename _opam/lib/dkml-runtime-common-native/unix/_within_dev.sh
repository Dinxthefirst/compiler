#!/bin/bash
# --------------------------
# within-dev.sh
# --------------------------
set -euf

# ------------------
# BEGIN Command line processing

usage() {
    printf "%s\n" "Usage:" >&2
    printf "%s\n" "    within-dev.sh -h           Display this help message." >&2
    printf "%s\n" "    within-dev.sh command ...  Run the command and any arguments." >&2
    printf "%s\n" "Advanced Options:" >&2
    printf "%s\n" "   -p DKMLABI: Optional. The DKML ABI. Defaults to an auto-detected host ABI" >&2
    printf "%s\n" "   -c: If specified, compilation flags like CC are added to the environment." >&2
    printf "%s\n" "         This can take several seconds on Windows since vcdevcmd.bat needs to run" >&2
    printf "%s\n" "   -0 PREHOOK_SINGLE: If specified, the script will be 'eval'-d upon" >&2
    printf "%s\n" "         entering the Build Sandbox _before_ any the opam command is run." >&2
    printf "%s\n" "   -1 PREHOOK_DOUBLE: If specified, the Bash statements will be 'eval'-d, 'dos2unix'-d and 'eval'-d" >&2
    printf "%s\n" "         upon entering the Build Sandbox _before_ any other commands are run but" >&2
    printf "%s\n" "         _after_ the PATH has been established." >&2
    printf "%s\n" "         It behaves similar to:" >&2
    printf "%s\n" '           eval "the PREHOOK_DOUBLE you gave" > /tmp/eval.sh' >&2
    printf "%s\n" '           eval /tmp/eval.sh' >&2
    printf "%s\n" '         Useful for setting environment variables (possibly from a script).' >&2
}

DKMLABI=
PREHOOK_SINGLE=
PREHOOK_DOUBLE=
COMPILATION=OFF
while getopts ":hp:0:1:c" opt; do
    case ${opt} in
        h )
            usage
            exit 0
        ;;
        p )
            DKMLABI=$OPTARG
            if [ "$DKMLABI" = dev ]; then
                usage
                exit 0
            fi
        ;;
        0 )
            PREHOOK_SINGLE=$OPTARG
        ;;
        1 )
            PREHOOK_DOUBLE=$OPTARG
        ;;
        c )
            COMPILATION=ON
        ;;
        \? )
            printf "%s\n" "This is not an option: -$OPTARG" >&2
            usage
            exit 1
        ;;
    esac
done
shift $((OPTIND -1))

if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# END Command line processing
# ------------------

DKMLDIR=$(dirname "$0")
DKMLDIR=$(cd "$DKMLDIR"/../../.. && pwd)

# shellcheck disable=SC1091
. "$DKMLDIR"/vendor/drc/unix/_common_tool.sh

# Essential environment values.
LAUNCHER_ARGS=()

# On Windows always disable the Automatic Unix ⟶ Windows Path Conversion
# described at https://www.msys2.org/docs/filesystem-paths/
disambiguate_filesystem_paths

# Autodetect DKMLSYS_*
autodetect_system_binaries

# Reset PATH to the system PATH.
#
# Alternative: Normalize the PATH. But for reproducibility just use the system PATH.
#
# Note: If we end up with any double quotes in the Windows PATH passed to
# vsdevcmd.bat then we will get '\Microsoft was unexpected at this time'
# (https://social.msdn.microsoft.com/Forums/vstudio/en-US/21821c4a-b415-4b55-8779-1d22694a8f82/microsoft-was-unexpected-at-this-time?forum=vssetup).
# That will happen if we have trailing slashes in our PATH (which Opam.exe internally cygpaths
# and escapes).
autodetect_system_path # Autodetect DKML_SYSTEM_PATH
PATH="$DKML_SYSTEM_PATH"

# Make a script to run any prehooks
{
    printf "#!/bin/sh\n\n"

    # [sanitize_path]
    # At this point the prehook may have set the PATH to be a Windows style path (ex. `opam env`).
    # So subsequent commands like `env`, `bash` and `rm` will need the PATH converted back to UNIX.
    # Especially ensure /usr/bin:/bin is present in PATH even if redundant so
    # `trap 'rm -rf "$WORK"' EXIT` handler can find 'rm'.
    # We use a missing /usr/bin to trigger the PATH mutation since:
    # - MSYS2 mounts /usr/bin as /bin (so /bin is automatically converted to /usr/bin in MSYS2 PATH)
    cat <<EOF
sanitize_path() {
    if [ -x /usr/bin/cygpath ]; then PATH=\$(/usr/bin/cygpath --path "\$PATH"); fi
    case "\$PATH" in
        /usr/bin) ;;
        *:/usr/bin) ;;
        /usr/bin:*) ;;
        *:/usr/bin:*) ;;
        *)
            PATH=/usr/bin:/bin:"\$PATH"
    esac
}

EOF

    if [ -n "$PREHOOK_SINGLE" ]; then
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then
            printf '%s\n' 'printf "+ [eval] ...\n" >&2'
            printf '%s\n' "'$DKMLSYS_SED' 's/^/+| /' '$PREHOOK_SINGLE' >&2"
        fi
        printf '%s\n' ". '$PREHOOK_SINGLE'"
        printf '%s\n\n' 'sanitize_path'
    fi

    if [ -n "$PREHOOK_DOUBLE" ]; then
        PREHOOK_DOUBLE_SQ=$(printf '%s' "$PREHOOK_DOUBLE" | escape_stdin_for_single_quote)
        if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then
            printf "printf %s '%s' >&2\n" \
                '"%s\n"' \
                "+ [eval] $PREHOOK_DOUBLE_SQ"
        fi
        # the `awk ...` is dos2unix equivalent
        cat <<EOF
if ! eval '$PREHOOK_DOUBLE_SQ' > '$WORK'/prehook.eval; then
    printf "FATAL: The following prehook failed:\n>>>\n%s\n<<<\n" '$PREHOOK_DOUBLE_SQ' >&2
    exit 107
fi
awk '{ sub(/\r$/,""); print }' '$WORK'/prehook.eval > '$WORK'/prehook.dos2unix.eval
rm -f '$WORK'/prehook.eval
. '$WORK'/prehook.dos2unix.eval
sanitize_path
rm -f '$WORK'/prehook.dos2unix.eval

EOF
    fi

    printf 'exec env "$@"\n'
} > "$WORK"/launch-prehooks.sh
"$DKMLSYS_CHMOD" +x "$WORK"/launch-prehooks.sh

# Autodetect compiler like Visual Studio on Windows.
# Whether or not compilation is needed, make a launcher that uses the system PATH plus optionally
# any compiler PATH and optionally any other compiler environment variables.
LAUNCHER="$WORK"/launch-dev-compiler.sh
if [ "$COMPILATION" = ON ]; then
    # If we have an Opam switch with a Opam command wrapper, we don't need to waste a few seconds detecting the compiler.
    # shellcheck disable=SC2154
    if [ -z "${OPAM_SWITCH_PREFIX:-}" ] || [ ! -e "$OPAM_SWITCH_PREFIX/$OPAM_CACHE_SUBDIR/$WRAP_COMMANDS_CACHE_KEY" ]; then
        set +e
        DKML_TARGET_ABI=$DKMLABI autodetect_compiler "$LAUNCHER"
        EXITCODE=$?
        set -e
        if [ $EXITCODE -ne 0 ]; then
            printf "%s\n" "FATAL: Your system is missing a compiler, which should be installed if you have completed the Diskuv OCaml installation"
            exit 1
        fi
    fi
fi
if [ ! -e "$LAUNCHER" ]; then
    create_system_launcher "$LAUNCHER"
fi

# print PATH for troubleshooting
if [ "${DKML_BUILD_TRACE:-OFF}" = ON ]; then printf "%s\n" "+ [PATH] $PATH" >&2; fi

# run the requested command (cannot `exec` since the launcher script is a temporary file
# that needs to be cleaned up after execution)
set +u # allow empty LAUNCHER_ARGS
log_shell "$LAUNCHER" "$WORK"/launch-prehooks.sh "${LAUNCHER_ARGS[@]}" "$@"
