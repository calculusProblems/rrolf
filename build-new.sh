#!/usr/bin/env bash
# MAKES BOTH THE NORMAL AND PVP SERVERS, AND INSTALLS MASTER SERVER DEPENDENCIES
# I used ai for dis cause idk much bash for debian.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"

debug=0; clean=0
for arg in "$@"; do
    case "$arg" in
        --debug) debug=1 ;;
        --clean) clean=1 ;;
        -h|--help)
            echo "usage: $0 [--debug] [--clean]"
            exit 0
            ;;
        *)
            echo "unknown option $arg" >&2
            exit 1
            ;;
    esac
done

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: '$1' not found, run: sudo apt install $2" >&2; exit 1; }; }
need cmake cmake
need clang clang
need make make
need node nodejs
need npm npm

# build_server <name> <pvp 0|1>
build_server()
{
    local name="$1" pvp="$2"
    local dir="$BUILD_DIR/$name"
    [ "$clean" = 1 ] && rm -rf "$dir"

    echo "==> configuring $name (pvp=$pvp debug=$debug)"
    cmake -S "$ROOT/Server" -B "$dir" -DPVP=$pvp -DDEBUG_BUILD=$debug >/dev/null

    echo "==> building $name"
    cmake --build "$dir" -j "$(nproc)"

    [ -x "$dir/rrolf-server" ] || { echo "error: build finished but $dir/rrolf-server is missing" >&2; exit 1; }
    echo "==> $name built: $dir/rrolf-server"
}

echo "==> installing master server dependencies"
cd "$ROOT/MasterServer"
if [ -f package-lock.json ]; then
    npm ci --no-audit --no-fund
else
    npm install --no-audit --no-fund
fi
[ -f .env ] || echo "warning: MasterServer/.env is missing, it'll run but logins won't work (needs PASSWORD_SALT, CLIENT_SECRET, BOT_TOKEN)"

build_server server 0
build_server server-pvp 1

echo "==> everything built"
