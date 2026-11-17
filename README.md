# tmux-agents

A dashboard for the AI agents in your tmux sessions. It shows which agent needs you, takes
you to it with one key, and brings your agents back after a reboot.

```
ttop · myhost · 11:22:25

 1 api*
           ◐ busy    fix-auth      1m  > Run the integration tests again
           ● waiting docs-update  12m  Should I open the PR?
 2 scratch
 3 infra   ● done    myagent       2h  Plan applied: 3 resources changed.

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
  blocker or its result.
- **One key to go there.** Press the key of a row, or select the row and press Enter. Inside
  tmux, ttop switches your terminal to that session. Outside tmux, ttop attaches to it.
  Detach to come back to ttop.
- **Restore after a reboot.** ttop lists the agents that died. Press R, and each agent comes
  back in its old session, window and pane, and continues its conversation.
- **Session control.** `n` opens a new session with a free name. Del deletes a session or an
  agent, after you confirm.
- **Shell helpers for bash.** `t`, `trm` and `tmv` open, kill and rename sessions. They match
  session names exactly. Plain tmux takes `-t foo` to mean `foobar` when there is no `foo`.
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

**Do it yourself.** You need Linux, tmux 3.0 or newer, bash, and Python 3.7 or newer at
`/usr/bin/python3`.

```sh
git clone <repo URL> ~/tmux-agents
cd ~/tmux-agents
./install.sh                                          # installs into ~/.local/bin
echo '. ~/.local/bin/tmux-agents.bash' >> ~/.bashrc
```

The installer copies `tls`, `ttop`, `tls-test` and `tmux-agents.bash` into `~/.local/bin`.
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

| ttop key | Action |
| --- | --- |
| ↑ ↓ Home End PgUp PgDn | Select a row. |
| Enter | Open the selected session or agent, or bring back a dead agent. |
| 1-9, then a-z without d, n, q and r | Do the same for the row with that key. A session opens at its most urgent agent. |
| n | Open a new session in the current directory, with a free adjective-noun name. |
| Del or Backspace | Delete the selected session (kill-session), agent (kill-pane) or dead agent (forget it). Enter confirms. |
| R | Bring back all dead agents. |
| d | Forget a dead agent: the selected one, or press its key. |
| q | Quit. |

`tls` prints the same list once, as `ps` does. `tls -h` shows all commands.

| Shell helper | Action |
| --- | --- |
| `t [NAME]` | Go to session NAME: switch to it inside tmux, attach to it outside. If there is no session NAME, make it. With no NAME, make a session with a free name. |
| `trm NAME...` | Kill sessions. |
| `tmv [OLD] NEW` | Rename session OLD, or the current session, to NEW. |
| `tt` | Run `ttop`. |
| `tmux-doctor` | Show the versions of the tmux client and the tmux server. Use it when tmux fails after an upgrade. |
| `tmux-cache-clean` | Delete the copies of old tmux clients that no server needs. |
| `tmux_autostart [NAME]` | On an interactive terminal outside tmux, attach to session NAME (default `main`). Exit the shell when tmux detaches. |

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

| Variable | Default | Effect |
| --- | --- | --- |
| `TLS_STATE_DIR` | `~/.local/state/agent-tls` | The directory for the records. |
| `TLS_CLAUDE` | `claude` | The command that resumes a Claude Code session. |
| `TLS_AGENT_COMMANDS` | `claude codex gemini` | Panes that run these commands show as agents before they report. |
| `TMUX_CLIENT_CACHE` | `~/.local/share/tmux-clients` | The directory for the copies of old tmux clients. |

## Files

| Path | Content |
| --- | --- |
| `bin/tls` | The dashboard and the agent interface, in one Python file. |
| `bin/ttop` | A short script that runs `tls top`. |
| `bin/tls-test` | The self-test. |
| `shell/tmux-agents.bash` | The bash helpers. |
| `config/tmux.conf` | The tmux config of the author (optional). |
| `docs/interface.md` | The agent status interface. |
| `install.sh` | The installer. |
| `AGENTS.md` | The install steps for AI agents. |

## Tests

```sh
bin/tls-test     # about 90 checks on throwaway tmux servers
```

The test does not touch your tmux server, your settings or your state directory. Each tmux
command in the test names its own socket.

## Uninstall

See [Uninstall in AGENTS.md](AGENTS.md#uninstall).
