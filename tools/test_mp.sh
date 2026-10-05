#!/bin/bash
# Local 2-client multiplayer integration test (server + host + guest as separate Godot processes)
cd "$(dirname "$0")/../godot"
GD=${1:-${GODOT:-/opt/godot/Godot_v4.4.1-stable_linux.x86_64}}
PORT=${PORT:-8090}
rm -f /tmp/mp_code.txt /tmp/mp_*.log
$GD --headless --path . res://src/net/server.tscn -- --port $PORT > /tmp/mp_server.log 2>&1 &
SP=$!
sleep 6
$GD --headless --path . -s tests/mp_client.gd -- host $PORT 100 > /tmp/mp_host.log 2>&1 &
HP=$!
sleep 1
timeout 120 $GD --headless --path . -s tests/mp_client.gd -- join $PORT 200 > /tmp/mp_join.log 2>&1
wait $HP 2>/dev/null
kill $SP 2>/dev/null
echo "== host"; grep -E "^\[|SCRIPT|ERROR" /tmp/mp_host.log | grep -v ALSA
echo "== join"; grep -E "^\[|SCRIPT|ERROR" /tmp/mp_join.log | grep -v ALSA
# pass criteria: both clients reached turn 5 with identical mirrored checksums
H=$(grep "turn=5" /tmp/mp_host.log | sed 's/.*checksum=\([0-9]*\).*/\1/'); J=$(grep "turn=5" /tmp/mp_join.log | sed 's/.*checksum=\([0-9]*\).*/\1/')
if [ -n "$H" ] && [ "$H" == "$J" ]; then echo "MP OK (checksum $H)"; exit 0; else echo "MP FAIL host=$H join=$J"; exit 1; fi
