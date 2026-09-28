#!/usr/bin/env bash
# MAKES BOTH THE NORMAL AND PVP SERVERS, AND INSTALLS MASTER SERVER DEPENDENCIES
# I used ai for dis cause idk much bash for debian.
#   --no-pvp   don't start the pvp server
# if u run like ./run-new.sh --no-pvp it doesnt build and run the pvp server sooo edit this i guess to have all properly setup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$ROOT/build"
RUN_DIR="$BUILD_DIR/run"
MASTER_PORT=55554
GAME_PORT=1234
PVP_PORT=1235

pvp=1
for arg in "$@"; do
    case "$arg" in
        --no-pvp) pvp=0 ;;
        -h|--help)
            echo "usage: $0 [--no-pvp]"
            exit 0
            ;;
        *)
            echo "unknown option $arg" >&2
            exit 1
            ;;
    esac
done

port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
wait_for_port() # <port> <seconds>
{
    local i
    for ((i = 0; i < $2 * 5; i++)); do
        port_in_use "$1" && return 0
        sleep 0.2
    done
    return 1
}

[ -d "$ROOT/MasterServer/node_modules" ] || { echo "error: master server deps missing, run ./build-new.sh first" >&2; exit 1; }
[ -x "$BUILD_DIR/server/rrolf-server" ] || { echo "error: normal server not built, run ./build-new.sh first" >&2; exit 1; }
[ "$pvp" = 1 ] && { [ -x "$BUILD_DIR/server-pvp/rrolf-server" ] || { echo "error: pvp server not built, run ./build-new.sh first" >&2; exit 1; }; }

ports=($MASTER_PORT $GAME_PORT); [ "$pvp" = 1 ] && ports+=($PVP_PORT)
for port in "${ports[@]}"; do
    port_in_use "$port" && { echo "error: port $port is already in use, is an earlier run still going?" >&2; exit 1; }
done

mkdir -p "$RUN_DIR"

pids=()
stop()
{
    trap - INT TERM EXIT
    echo
    echo "==> stopping"
    for pid in ${pids[@]+"${pids[@]}"}; do
        kill "$pid" 2>/dev/null || true
    done
    wait 2>/dev/null || true
}
trap stop INT TERM EXIT

echo "==> master server on port $MASTER_PORT (log: $RUN_DIR/master.log)"
(cd "$ROOT/MasterServer" && exec node main.js) >"$RUN_DIR/master.log" 2>&1 &
pids+=($!)
wait_for_port $MASTER_PORT 20 || { echo "error: master server didn't come up, check $RUN_DIR/master.log" >&2; exit 1; }

echo "==> hell creek server on port $GAME_PORT (log: $RUN_DIR/server.log)"
(cd "$RUN_DIR" && exec "$BUILD_DIR/server/rrolf-server") >"$RUN_DIR/server.log" 2>&1 &
pids+=($!)
wait_for_port $GAME_PORT 20 || { echo "error: hell creek server didn't come up, check $RUN_DIR/server.log" >&2; exit 1; }

if [ "$pvp" = 1 ]; then
    echo "==> pvp server on port $PVP_PORT (log: $RUN_DIR/server-pvp.log)"
    (cd "$RUN_DIR" && exec "$BUILD_DIR/server-pvp/rrolf-server") >"$RUN_DIR/server-pvp.log" 2>&1 &
    pids+=($!)
    wait_for_port $PVP_PORT 20 || { echo "error: pvp server didn't come up, check $RUN_DIR/server-pvp.log" >&2; exit 1; }
fi

echo "==> up: master on $MASTER_PORT, hell creek on $GAME_PORT$([ "$pvp" = 1 ] && echo ", pvp on $PVP_PORT") (ctrl+c to stop)"
wait
