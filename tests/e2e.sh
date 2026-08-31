#!/bin/bash
P="$(cd "$(dirname "$0")/.." && pwd)/worklog.30m.sh"
C="${STATE_DIR:-$HOME/.local/state/worklog-nudge}/cache.json"
fail=0
ok(){ echo "PASS $1"; }; no(){ echo "FAIL $1: $2"; fail=1; }

# 3. every menu row's bash= target exists and is executable
bash "$P" | grep -o 'bash=[^ ]*' | cut -d= -f2 | sort -u | while read -r b; do
  [ -x "$b" ] || echo "FAIL target-exists: $b"
done

# 4. cold start renders instantly
mv "$C" /tmp/cache.bak
s=$(date +%s); bash "$P" >/tmp/cold.out; e=$(date +%s)
[ $((e-s)) -le 2 ] && ok cold-fast || no cold-fast "$((e-s))s"
head -1 /tmp/cold.out | grep -q '⏱ …' && ok cold-placeholder || no cold-placeholder "$(head -1 /tmp/cold.out)"
sleep 75
[ -s "$C" ] && ok background-refresh || no background-refresh "cache not written"

# 5. warm run fast and well-formed
s=$(date +%s); bash "$P" >/tmp/warm.out; e=$(date +%s)
[ $((e-s)) -le 2 ] && ok warm-fast || no warm-fast "$((e-s))s"
grep -qE '^[A-Z]+-[0-9]+  .+ \| bash=' /tmp/warm.out && ok warm-rows || no warm-rows "no ticket rows"
awk 'NR==2 && $0!="---"{exit 1}' /tmp/warm.out && ok swiftbar-separator || no swiftbar-separator "line 2 not ---"

exit $fail
