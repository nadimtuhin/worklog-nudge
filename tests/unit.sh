#!/bin/bash
S="$(dirname "$0")/../worklog.30m.sh"
fail=0
ok(){ echo "PASS $1"; }
no(){ echo "FAIL $1: $2"; fail=1; }

# unit: source funcs without running main
tmp=/tmp/funcs.sh; sed -n '1,/^if \[ "\${1:-}" = "--refresh" \]/p' "$S" | sed '$d' > $tmp; . $tmp; set +o pipefail

[ "$(hhmm 7920)" = "2h12" ] && ok hhmm || no hhmm "got $(hhmm 7920)"
[ "$(hhmm 0)" = "0h00" ] && ok hhmm-zero || no hhmm-zero "got $(hhmm 0)"
[ "$(short 3600)" = "1h" ] && [ "$(short 5400)" = "1h30" ] && ok short || no short "got $(short 3600)/$(short 5400)"
[ "$(echo '[FE] Do the thing [2h]' | tidy)" = "Do the thing" ] && ok tidy || no tidy "got $(echo '[FE] Do the thing [2h]' | tidy)"
[ "$(epoch_of 2026-08-28T15:44:00+0600)" = 1787910240 ] && ok epoch_of || no epoch_of "got $(epoch_of 2026-08-28T15:44:00+0600)"
[ -z "$(epoch_of 'garbage')" ] && ok epoch_of-bad || no epoch_of-bad "not empty"

# render: gated when logged >= 5h
out=$(render $(( $(date +%s) - 99999 )) 18000 $'BX-1\tx')
[ "$(echo "$out" | head -1)" = "⏱ | color=#808080" ] && echo "$out" | grep -q 'param1=[^ ]*BX-1' && ok gate-hours || no gate-hours "$out"

# render: gated when elapsed < 2h
render $(( $(date +%s) - 7000 )) 0 $'BX-1\tx' | head -1 | grep -q '^⏱ | color' && ok gate-elapsed || no gate-elapsed "title not dim"

# render: nudge at >= 2h
o=$(render $(( $(date +%s) - 7260 )) 0 $'BX-1\tsummary here\t0\t0\nBX-2\tanother\t5400\t7200')
big=""; for i in 1 2 3 4 5 6 7; do big+="BX-$i"$'\t'"s$i"$'\t0\t0\n'; done
sub=$(render $(( $(date +%s) - 7260 )) 0 "$big")
[ "$(echo "$sub" | grep -c '^--BX-')" = 2 ] && ok submenu-overflow || no submenu-overflow "$(echo "$sub"|grep -c '^--BX-') nested"
echo "$sub" | grep -q '^More tickets$' && ok submenu-header || no submenu-header "no header"
[ "$(echo "$sub" | grep -c '^BX-')" = 5 ] && ok submenu-top5 || no submenu-top5 "$(echo "$sub"|grep -c '^BX-') top-level"
echo "$o" | head -1 | grep -q '^⏱ 2h01$' && ok nudge-title || no nudge-title "$(echo "$o"|head -1)"
echo "$o" | grep -q 'BX-1  summary here — 0h of 0h | bash=.*param1=.*BX-1' && ok row-format || no row-format "$o"
echo "$o" | grep -q '^Sprint 1h30 of 2h estimated$' && ok sprint-totals || no sprint-totals "$(echo "$o"|grep Sprint)"
echo "$o" | grep -q 'Refresh | refresh=true' && ok refresh-row || no refresh-row ""
echo "$o" | grep -q 'Quit SwiftBar' && ok quit-row || no quit-row ""

y=$(date -v-1d +%Y-%m-%d); t=$(date +%Y-%m-%d)
ds=$(printf '%s\t3600\n' "$y")
o2=$(day_submenu "Last 2" "$y" "$ds")
[ "$(echo "$o2" | head -1)" = "Last 2 — 1h over 2 days" ] && ok daysub-header || no daysub-header "$(echo "$o2"|head -1)"
[ "$(echo "$o2" | grep -c '^--')" = 2 ] && ok daysub-fills-gaps || no daysub-fills-gaps "$(echo "$o2"|grep -c '^--')"
echo "$o2" | tail -1 | grep -q '· 0h$' && ok daysub-zero-day || no daysub-zero-day "$(echo "$o2"|tail -1)"

# no unquoted param with spaces (the iTerm bug)
echo "$o" | grep -E '^BX-1 ' | grep -qE 'param1=[^ ]+ terminal=false$' && ok param-no-split || no param-split "ticket row has split param"



export STATE_DIR=/tmp/wn-test-state
rm -rf "$STATE_DIR"; mkdir -p "$STATE_DIR"
ALERTS="$STATE_DIR/alerts-$(date +%Y-%m-%d)"
ALERT_AFTER_SECONDS=10800; ALERT_MAX_PER_DAY=3; ALERT_LAST_HOUR=23; DAILY_TARGET_SECONDS=18000

should_alert 7200 0 && no alert-under-threshold "fired below 3h" || ok alert-under-threshold
should_alert 20000 18000 && no alert-target-met "fired after target reached" || ok alert-target-met
should_alert 20000 0 && ok alert-first || no alert-first "did not fire"
should_alert 20000 0 && no alert-throttled "fired twice in a row" || ok alert-throttled
printf '1 0\n' > "$ALERTS"; should_alert 20000 0 && ok alert-second || no alert-second "blocked"
printf '3 0\n' > "$ALERTS"; should_alert 20000 0 && no alert-daily-cap "exceeded 3/day" || ok alert-daily-cap
printf '0 0\n' > "$ALERTS"; ALERT_LAST_HOUR=0; should_alert 20000 0 && no alert-after-hours "fired past cutoff" || ok alert-after-hours
rm -rf "$STATE_DIR"

exit $fail
