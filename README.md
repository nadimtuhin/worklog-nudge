# jira-worklog-nudge

A macOS menu bar item that tells you how long it has been since you last logged
time in Jira, and lets you jump straight to the ticket you should log it against.

Worklogs written from memory three days later are wrong worklogs. This makes the
gap visible while you can still remember what you did.

```
⏱ 2h12
─────────────────────────────────────────────
Logged today 3h10 · unlogged since 13:36
Sprint 8h45 of 56h30 estimated
─────────────────────────────────────────────
PROJ-142  Retry + toast on network timeout — 0h of 1h
PROJ-141  Empty vs error states — 0h of 1h
PROJ-140  Partial-load handling in list view — 0h of 2h
More tickets                                     ▸
─────────────────────────────────────────────
Last 7 days — 15h45 over 7 days                  ▸
This sprint since 2026-08-27 — 8h45 over 5 days  ▸
```

The title is the whole point: it is always visible, and it grows. Under the nudge
threshold it collapses to a plain grey `⏱` and gets out of your way.

## What it does

- **Elapsed time since your last worklog**, measured from `started + timeSpentSeconds`
  of your most recent slice — not from when that slice began. Clamped to
  `WORKDAY_START`, so a morning with nothing logged reads `4h12`, not `19h` of
  mostly sleep.
- **Your sprint tickets**, each with logged vs. estimated hours. Click one to open it.
- **Per-day breakdown** for the last 7 days and for the current sprint so far,
  including the days you logged nothing.
- **Notifications** when you have gone too long with nothing logged (see below).
- Goes quiet once you have hit your daily target.

## Requirements

- macOS
- [SwiftBar](https://github.com/swiftbar/SwiftBar) — `brew install --cask swiftbar`
- [`acli`](https://developer.atlassian.com/cloud/acli/) — Atlassian's CLI, already
  logged in (`acli jira auth login`)
- `jq` — `brew install jq`

Everything is read-only against Jira. The plugin never writes a worklog itself.

## Install

One command — installs Homebrew, `jq`, `acli` and SwiftBar if they are missing, logs
you in to Jira if you are not already, writes the config from your `acli` account and
starts the app:

```bash
git clone https://github.com/nadimtuhin/jira-worklog-nudge.git
cd jira-worklog-nudge
./install.sh
```

It is safe to re-run: anything already installed is skipped, and an existing
config is left alone.

### Manual install

```bash
git clone https://github.com/nadimtuhin/jira-worklog-nudge.git
cd jira-worklog-nudge

mkdir -p ~/.config/jira-worklog-nudge
cp config.env.example ~/.config/jira-worklog-nudge/config.env
$EDITOR ~/.config/jira-worklog-nudge/config.env      # set JIRA_SITE and JIRA_EMAIL

mkdir -p ~/.swiftbar-plugins
cp worklog.30m.sh ~/.swiftbar-plugins/
```

Point SwiftBar at `~/.swiftbar-plugins` the first time it launches, then open it.
Within one refresh the `⏱` appears.

**Only put the plugin in that folder.** SwiftBar executes *every* executable file
there, so a stray test script or helper becomes a second menu bar item.

The `30m` in the filename is the refresh interval — rename to `worklog.15m.sh` for
a tighter loop. The interval is the only scheduler; there is no cron or launchd.

## Configuration

`~/.config/jira-worklog-nudge/config.env`:

| Variable | Default | Meaning |
|---|---|---|
| `JIRA_SITE` | — | e.g. `yourcompany.atlassian.net` (required) |
| `JIRA_EMAIL` | — | your Atlassian account email (required) |
| `DAILY_TARGET_HOURS` | `5` | at or above this, the title goes quiet for the day |
| `NUDGE_AFTER_HOURS` | `2` | show the elapsed count in the title after this gap |
| `ALERT_AFTER_HOURS` | `3` | notify after this much unlogged time |
| `ALERT_MAX_PER_DAY` | `3` | how many notifications a day, at most |
| `ALERT_LAST_HOUR` | `20` | no notifications after this hour |
| `MAX_ROWS` | `5` | tickets shown inline; the rest go in a submenu |
| `WORKDAY_START` | `09:00` | elapsed never counts back past this time today |
| `LOG_COMMAND` | — | see *Custom logging* |

`JIRA_EMAIL` matters more than it looks: a ticket's worklog array holds *every*
author's entries, so without it you would count a teammate's time as your own.

## Notifications

With the defaults you get at most three a day, at least three hours apart, none
after 20:00 — so a typical under-logged day nudges you around 14:00, 17:00 and
20:00. They stop entirely once you have logged `DAILY_TARGET_HOURS`.

State lives in `~/.local/state/jira-worklog-nudge/alerts-YYYY-MM-DD`, one file per day,
holding the count and the last alert time. Delete it to reset the day.

macOS will ask SwiftBar for notification permission the first time one fires.

## Custom logging

By default, clicking a ticket opens `https://$JIRA_SITE/browse/KEY` in your browser
and you log the time in Jira's own dialog.

Set `LOG_COMMAND` to any executable and it is called with the ticket key as its
single argument instead:

```bash
LOG_COMMAND=$HOME/bin/log-worklog
```

```bash
#!/bin/sh
# $1 is the ticket key, e.g. PROJ-140
exec /usr/bin/open "jira://browse/$1"
```

That hook is how you wire it to an interactive prompt, a script that posts through
the Jira REST API, or an AI agent — the plugin stays read-only either way.

## How it stays fast

The Jira fan-out takes 30–60 seconds. It never runs on the render path: each run
prints the cached menu in about 25ms and refreshes the cache in the background, so
the menu bar never blocks. A cold start with no cache shows `⏱ …` immediately.

Per-key `view` calls run eight at a time via `xargs -P 8`.

## Notes on Jira's API, learned the hard way

- `workitem search` **rejects time-tracking fields** (`timespent`,
  `timeoriginalestimate`) and `customfield_10001`. Get keys from `search`, then the
  fields per key from `view --json`.
- `view` without `--json` hides time fields entirely, even with `--fields "*all"`.
- A ticket's `worklog.worklogs` array is capped at 20 entries and holds every
  author's slices. Check `worklog.total > 20` before trusting a sum.
- `fields.timespent` is a ticket's **lifetime** total, not this sprint's.
- Sprint dates come from `customfield_10020` — but sprints are per team, so read it
  from a ticket you know belongs to the sprint you mean.

## Tests

```bash
tests/unit.sh    # pure functions and menu rendering, no network
tests/e2e.sh     # real Jira, real cache, real timings
```

## Kill switch

Quit SwiftBar, or `mv ~/.swiftbar-plugins/worklog.30m.sh{,.off}`.

## Licence

MIT
