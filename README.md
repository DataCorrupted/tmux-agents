# tmux-agents

A dashboard for the AI agents in your tmux sessions. It shows which agent needs you, takes
you to it with one key, and brings your agents back after a reboot.

```
ttop · myhost · 11:22:25

 1 api*
           ◐ busy    fix-auth      1m  > Run the integration tests again
▌          ● waiting docs-update  12m  Should I open the PR?
 2 infra   ● done    myagent       2h  Plan applied: 3 resources changed.
 3 scratch

↑↓ select · enter or 1-9 open/resume · n new session · del delete · R resume all dead · q quit · * attached
```

## Why

You give each task its own tmux session, with an agent such as Claude Code in it. Soon you
have many sessions. One agent asks a question, one finished an hour ago, and one waits for
your security key. From the outside, all sessions look the same, so you open them one at a
time.

A reboot is worse. tmux loses all sessions, and you must build each one again: its windows,
its splits, and the agent in its pane.

tmux-agents fixes both problems.

## What you get

- **A live list.** `ttop` (or `tt`) shows your tmux sessions and their agents, as `top`
  shows processes. Each agent has a state, a name, an age and a summary: its question, its
  blocker or its result. In a narrow or tall window, ttop shows the list vertically. With
  `-f`, ttop sizes its tmux pane to the list.
- **One key to go there.** Press the key of a row, or select the row and press Enter. Inside
  tmux, ttop switches your terminal to that session. Outside tmux, ttop attaches to it.
  Detach to come back to ttop.
- **Restore after a reboot.** ttop lists the agents that died. Press R, and each agent comes
  back in its old session, window and pane, and continues its conversation.
- **Session control.** `n` opens a new session with a free name. Del deletes a session or an
  agent, after you confirm.
- **Resize in proportion.** When a window changes size, for example on a different monitor,
  its panes keep their proportions, and a ttop bar keeps its width. tmux alone takes the
  same number of columns from each pane, so narrow panes almost go away.
- **Window presets.** `t -p` opens a new session that is already split for work: two panes
  side by side, and a bar with ttop, on the right of a wide window or at the bottom. `ttv`
  and `tth` add a ttop bar on the right or at the bottom of the window you are in, whatever
  its panes are.
- **Shell helpers for bash.** `t`, `trm` and `tmv` open, kill and rename sessions. They match
  session names exactly. Plain tmux takes `-t foo` to mean `foobar` when there is no `foo`.
  `t` and `tmv` refuse names that tmux can misread, such as `-p` or `foo.bar`.
- **Any agent.** Claude Code works out of the box. Other agents report their state with one
  command, `tls report` ([docs/interface.md](docs/interface.md)).

## States

| Dot | State | Meaning |
| --- | --- | --- |
| red ● | blocked | The agent cannot continue until you act, for example touch a security key or log in again. A failed turn is also blocked. |
| yellow ● | waiting | The agent asks you something: a question, a plan or a permission. |
| green ● | done | The agent finished its turn, and you did not look at it yet. The dot becomes grey when you look. |
| blue ◐ | busy | The agent works on your prompt. |
| blue ◌ | bg | The turn is over, but background tasks continue. |
| grey ○ | idle | The agent has nothing to do. |
| grey ? | ? | The pane runs an agent that did not report yet. |
| grey ✕ | was … | The agent is dead: its pane closed, or the machine rebooted. ttop lists it under "dead", with its last state. |

## Install

**Ask your agent.** Tell it: "Install tmux-agents from <repo URL>, and follow its
AGENTS.md." [AGENTS.md](AGENTS.md) gives the steps and the checks. It also tells the agent
which changes need your OK.

**Do it yourself.** You need Linux or macOS, tmux 3.0 or newer, bash, and Python 3.7 or
newer at `/usr/bin/python3`. On macOS, Homebrew has tmux (`brew install tmux`), and the
Xcode Command Line Tools have `/usr/bin/python3` (`xcode-select --install`).

```sh
git clone <repo URL> ~/tmux-agents
cd ~/tmux-agents
./install.sh                                          # installs into ~/.local/bin
echo '. ~/.local/bin/tmux-agents.bash' >> ~/.bashrc
```

On macOS, Terminal and tmux start bash as a login shell. A login shell reads
`~/.bash_profile`, not `~/.bashrc`. If your `~/.bash_profile` does not load `~/.bashrc`,
add the line `. ~/.bashrc` to it.

The installer copies `tls`, `ttop`, `ttv`, `tth`, `tls-test` and `tmux-agents.bash` into
`~/.local/bin`, and the settings file `tls.conf` into `~/.config/tmux-agents/` (only if you
do not have one there).
Use `--bin DIR` for a different directory. Then the installer runs `tls setup`:

- Setup adds the Claude Code hooks to `~/.claude/settings.json`, with a backup.
- It comments out an old `alias tls=...` in your shell startup files, with a backup.
- It registers the tmux hooks on the tmux server.

Use `--no-setup` to skip setup.

After the install, open a new shell and run `ttop`. Restart the Claude Code sessions that
already run, so that they load the new hooks.

Two options are not in the default install:

- `./install.sh --tmux-conf` also installs `config/tmux.conf` as `~/.tmux.conf`, with a
  backup. It is the tmux config of the author, and tls does not need it.
- `tmux_autostart main` in `~/.bashrc`, after the line for `tmux-agents.bash`, starts each
  interactive terminal in the tmux session `main`.

## Use

### ttop

| ttop key | Action |
| --- | --- |
| ↑ ↓ Home End PgUp PgDn | Select a row. ↓ on the last row goes round to the first row, and ↑ on the first row to the last. |
| Enter | Open the selected session or agent, or bring back a dead agent. |
| 1-9, then a-z without d, n, q and r | Do the same for the row with that key. A session opens at its most urgent agent. |
| n | Open a new session in the current directory, with a free adjective-noun name. With `ttop -p`, give it the preset layout. |
| Del or Backspace | Delete the selected session (kill-session), agent (kill-pane) or dead agent (forget it). Enter confirms. |
| R | Bring back all dead agents. |
| d | Forget a dead agent: the selected one, or press its key. |
| q | Quit. |

In ttop inside tmux, bold text shows where you are: the name of the session that the ttop is
in, and the name of the agent whose pane is active there. When you go into the ttop pane,
the agent that you came from stays bold. The grey bar is only the selection for Enter and
the other keys. `*` after a name means that a terminal shows that session.

`tls` prints the same list once, as `ps` does. `tls -h` shows all commands.

### Vertical layout

ttop picks its layout by itself: vertical in a window under 60 columns or taller than wide
(in pixels), and horizontal in other windows. It picks again when the window changes size.
`ttop -v` (or `tt -v`) always shows the list vertically, and `ttop -h` always
horizontally. `tls -v` prints the vertical list once. For a ttop pane at the left side of
a window, run `tmux split-window -hb -l 20 'ttop -f'`.

Each session has a line with its key and its name. Under it, each agent has a line with
its dot, status, name and age, and then its summary in a lighter color. The summaries wrap
onto more lines while the whole list fits in the window. When it does not fit, they get
fewer lines, down to one line each. If the window is too narrow for an agent line, the
status words go first, because the dot shows the state too. Then the names get shorter,
and then the age goes. The samples have 28, 20 and 16 columns, and 20 lines:

```
ttop · myhost · 11:22:25    │ ttop · 11:22:25     │ ttop · 11:22:25
                            │                     │
 1 api*                     │  1 api*             │  1 api*
  ◐ busy    fix-auth     1m │   ◐ fix-auth     1m │   ◐ fix-au…  1m
  > Run the integration     │   > Run the         │   > Run the
    tests again             │     integration     │     integration
▌ ● waiting docs-update 12m │     tests again     │     tests again
▌ Should I open the PR?     │ ▌ ● docs-update 12m │ ▌ ● docs-u… 12m
 2 infra                    │ ▌ Should I open the │ ▌ Should I open
  ● done    myagent      2h │ ▌ PR?               │ ▌ the PR?
  Plan applied: 3 resources │  2 infra            │  2 infra
  changed.                  │   ● myagent      2h │   ● myagent  2h
 3 scratch                  │   Plan applied: 3   │   Plan applied:
                            │   resources         │   3 resources
↑↓ enter n del R q          │   changed.          │   changed.
                            │  3 scratch          │  3 scratch
                            │                     │
                            │ ↑↓ enter n del R q  │ ↑↓ enter n del
                            │                     │ R q
```

To always get one layout, add `alias tt='ttop -v'` (or `ttop -h`) to `~/.bashrc`, after
the line for `tmux-agents.bash`.

### Fit

`ttop -f` (or `tt -f`) sizes its own tmux pane to the list, with no space left over. It
does this again each time the list or the pane changes: a new agent, a session that goes,
or a drag of the pane's edge.

- A vertical ttop gets as wide as its lines with whole names and status words: 16 to 40
  columns, and a third of the window at most. It keeps room for the longest status word,
  so a change of state does not resize it.
- A horizontal ttop gets as high as the list and its title: 2 lines to a third of the
  window.

Outside tmux, `-f` does nothing. The preset bars use it.

### Presets

`t -p NAME` (or `t --preset NAME`) makes a new session that is ready for work: two panes
side by side, and a bar with ttop. Plain `t` does not change. The layout depends on the
shape of the window:

```
wide window (21:9)                      other windows (16:9, 16:10)
┌────────────┬────────────┬─────────┐   ┌─────────────┬─────────────┐
│            │            │ ttop -v │   │             │             │
│   shell    │   shell    │         │   │    shell    │    shell    │
│            │            │ fits    │   │             │             │
│            │            │ the list│   ├─────────────┴─────────────┤
└────────────┴────────────┴─────────┘   │ ttop -h, fits the list    │
                                        └───────────────────────────┘
```

A window is wide when its width is 2.25 times its height or more, in pixels. It must also
have room for two 80-column panes next to the bar. If tmux does not know the pixel size of
a cell, tls takes a cell as twice as high as wide. To choose the layout yourself, set
`TLS_PRESET=right` or `TLS_PRESET=bottom`.

The bar starts at 25 columns, or at 5 to 10 lines. Then its ttop fits it to the list (see
[Fit](#fit)), and the two panes share each change of the bar's size. The bar runs
`ttop -p`, so its `n` key also makes sessions in the preset layout. Start ttop with `-p`
(`tt -p`, `tt -v -p`) to get this `n` in other places too. `tls preset`
gives the preset layout to a window with one pane, for example a new window in a session.
When tls rebuilds a session after a reboot, ttop starts again in its bar. In a window of
less than 12 lines, such as the bottom bar, ttop has no blank lines, and its key hint is
on the title line.

To use the presets each time, add `alias t='t -p'` and `alias tt='ttop -p'` to
`~/.bashrc`, after the line for `tmux-agents.bash`.

### A bar in any window (ttv, tth)

`ttv` adds a bar with `ttop -v` to the tmux window that you are in. The bar is 25 columns
wide and as high as the window, on the right. The numbers in this section are defaults:
the `[ttv]` and `[tth]` sections of the [settings file](#settings) change them. The window
can have any panes. Each pane keeps its height, and gives up width in proportion to its
width. For example, in a window
of 101 columns, two panes of 50 columns become two panes of 37 columns. The bar and its
border take the other 26 columns. The cursor stays in your pane.

`q` in the bar quits ttop and closes the bar. Then the panes get the 26 columns back in
equal parts, because tmux does it that way: panes of 50 and 50 columns come back as 50 and
50, but panes of 30 and 70 columns come back as 35 and 65.

`tth` does the same at the bottom of the window, for a screen that is taller than wide. Its
bar has `ttop -h`, is 10 lines high and as wide as the window, and each pane gives up
height in proportion to its height.

```
ttv                                     tth
┌─────────────┬─────────────┬───────┐   ┌─────────────┬─────────────┐
│             │             │ ttop  │   │             │             │
│    shell    │    shell    │ -v    │   │    shell    │    shell    │
│             │             │       │   │             │             │
│             │             │ 25    │   ├─────────────┴─────────────┤
│             │             │ cols  │   │ ttop -h, 10 lines         │
└─────────────┴─────────────┴───────┘   └───────────────────────────┘
```

ttv does nothing in a window of 80 columns or less, and tth in a window of 29 lines or
less. In a window that already has its bar, ttv sets the bar back to 25 columns, and tth to
10 lines, for example after a drag. A bar on the other side moves: after you turn a screen,
run tth in a window with a ttv bar, and the bar goes to the bottom. They do nothing in a
window with a ttop pane that is not a bar. `ttv WINDOW` and `tth WINDOW` work on a
different window, for example `ttv =main:1`. ttv and tth work in all shells.

### Window resize

When a window changes size, for example when you go from a 21:9 monitor to a 16:9
monitor, tmux takes the same number of columns from each pane, until a pane has only 1
column. So a narrow pane, such as the ttv bar, almost goes away, and a wide pane keeps most
of its width. tls changes this. After each resize, each split keeps its proportions, and a
ttop bar keeps its size. A bar from ttv changes with the window too, but it stays 25 to 30
columns wide, and a bar from tth 10 to 12 lines high. When you go back to the old size, you get your old layout back exactly.

For example, take panes of 200 and 73 columns and the ttv bar, and make the window go from
300 to 200 columns. tmux alone makes them 162, 35 and 1 columns. With tls, they become 127,
46 and 25 columns.

tls keeps the last layout that you made in each window: after a split, a close or a drag.
It does not keep a layout that tmux made for a new size. tls adds its tmux hooks by itself:
when the state of an agent changes and its tmux server does not have the hooks of this tls
(a new server, an update, or a new setting), and when you run `ttop`, `ttv`, `tth` or
`tls setup`. To use the tmux way again, set `proportional = off` in the `[resize]` section
of the [settings file](#settings).

### Shell helpers

| Shell helper | Action |
| --- | --- |
| `t [-p] [NAME]` | Go to session NAME: switch to it inside tmux, attach to it outside. If there is no session NAME, make it. With no NAME, make a session with a free name. With `-p`, a new session gets the preset layout. |
| `trm NAME...` | Kill sessions. |
| `tmv [OLD] NEW` | Rename session OLD, or the current session, to NEW. |
| `tt` | Run `ttop`, with the same options: `tt -v`, `tt -h`, `tt -f`, `tt -p`. |
| `tmux-doctor` | Show the versions of the tmux client and the tmux server. Use it when tmux fails after an upgrade. |
| `tmux-cache-clean` | Delete the copies of old tmux clients that no server needs. |
| `tmux_autostart [NAME]` | On an interactive terminal outside tmux, attach to session NAME (default `main`). Exit the shell when tmux detaches. |

`t` and `tmv` take only session names of ASCII letters, digits, `_` and `-`, with no `-`
first. A name with `-` first reads as an option: before `t` knew `-p`, `t -p` made a session
`-p`. A tmux target reads `.` and `:` as separators, so `t foo.bar` cannot find its own
session. `trm` takes any name, so it can remove a bad one.

After a tmux upgrade, the new tmux client can fail to attach to the old server. Then `t`
and `tmux_autostart` attach with a copy of the old tmux binary, which they keep in
`~/.local/share/tmux-clients`.

## Other agents

An agent shows up in ttop when it, or a hook or wrapper of it, runs `tls report`:

```sh
tls report id=abc123 agent=myagent state=busy prompt="port the parser" resume="myagent --resume abc123"
tls report id=abc123 state=waiting summary="Push to main?"
tls report id=abc123 state=finished message="$LAST_MESSAGE"   # tls finds done, waiting or blocked
tls report id=abc123 end=deliberate                            # the user quit
```

[docs/interface.md](docs/interface.md) gives the fields, the states and the lifecycle.
Claude Code uses the same interface: `tls hook` changes each Claude Code hook event into a
report.

## How it works

- Each agent session has a JSON record in `~/.local/state/agent-tls/`. Each report updates
  the record.
- tls copies the state into tmux pane options. When you select the pane of a green agent, a
  tmux hook makes the dot grey.
- When you change the layout of a window, a tmux hook keeps it in the window option
  `@tls-base`. When the window changes size, a second hook runs `tls relayout`, which
  scales that layout to the new size.
- A report with `state=finished` gives the last message of the agent. tls reads it, and
  picks `waiting`, `blocked` or `done`. For your own rules, put a Python file
  `tmux-agent-classify` next to `tls`. Its `classify(text)` must return
  `(verdict, rule, sentence)`.
- tls saves the layout of each session that has an agent, in `layouts.json`. A dead agent
  comes back in one of three ways:
  - If its old pane shows a shell prompt, tls types the resume command there.
  - If its session is gone, tls makes the session again: all windows, each pane in its old
    directory, and the saved layout.
  - If only its pane is gone, tls splits the pane back into its window.

The comments at the top of `bin/tls` give more detail.

## Settings

Each setting has a default in tls. The settings file `~/.config/tmux-agents/tls.conf`
changes them. The installer puts the file there with each setting at its default,
commented out, and an explanation above each one. To change a setting, remove the `#` in
front of it and change the value. For example, for a wider ttv bar:

```ini
[ttv]
width = 28
max-width = 34
```

`tls config` shows the value of each setting that tls uses, and where the value comes from.
It also shows the lines of the file that tls ignores, and why: a setting that does not
exist, or a bad value. ttop reads the file when it starts, so start ttop again after a
change. `tls config --defaults` prints the file with the defaults.

| Section | Settings |
| --- | --- |
| `[ttop]` | `layout` (auto, vertical, horizontal: ttop with neither `-v` nor `-h`), `narrow`, `short`, `fit-min-width`, `fit-max-width` |
| `[ttv]` | `width`, `min-width`, `max-width`, `min-window`, `options` (the ttop options of the bar) |
| `[tth]` | `height`, `min-height`, `max-height`, `min-window`, `options` |
| `[preset]` | `layout` (auto, right, bottom), `wide`, `pane-width`, `right-width`, `bottom-min-lines`, `bottom-max-lines` |
| `[resize]` | `proportional` (on, off) |
| `[agents]` | `claude`, `commands`, `keep-dead-days` |

Environment variables win over the file:

| Variable | Default | Effect |
| --- | --- | --- |
| `TLS_CONFIG` | `~/.config/tmux-agents/tls.conf` | The settings file. |
| `TLS_STATE_DIR` | `~/.local/state/agent-tls` | The directory for the records. |
| `TLS_CLAUDE` | `claude` | `[agents] claude`: the command that resumes a Claude Code session. |
| `TLS_AGENT_COMMANDS` | `claude codex gemini` | `[agents] commands`: panes that run these commands show as agents before they report. |
| `TLS_PRESET` | `auto` | `[preset] layout`: `right` or `bottom` for `t -p`, `ttop -p` and `tls preset`. |
| `TMUX_CLIENT_CACHE` | `~/.local/share/tmux-clients` | The directory for the copies of old tmux clients. |

## Files

| Path | Content |
| --- | --- |
| `bin/tls` | The dashboard and the agent interface, in one Python file. |
| `bin/ttop` | A short script that runs `tls top`. |
| `bin/ttv`, `bin/tth` | Short scripts that run `tls bar right` and `tls bar bottom`. |
| `bin/tls-test` | The self-test. |
| `shell/tmux-agents.bash` | The bash helpers. |
| `config/tls.conf` | The settings file, with each setting at its default (`tls config --defaults`). |
| `config/tmux.conf` | The tmux config of the author (optional). |
| `docs/interface.md` | The agent status interface. |
| `install.sh` | The installer. |
| `AGENTS.md` | The install steps for AI agents. |

## Tests

```sh
bin/tls-test     # about 160 checks on throwaway tmux servers
```

The test does not touch your tmux server, your settings or your state directory. Each tmux
command in the test names its own socket.

## Uninstall

See [Uninstall in AGENTS.md](AGENTS.md#uninstall).
