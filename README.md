# tmux-agents

A tmux dashboard for running several coding agents at once, plus bash helpers for tmux
sessions. Claude Code works out of the box; any other agent can report through a small
public interface, [`tls report`](docs/interface.md).

- `tls` prints your tmux sessions and the state of each agent in them: blocked, waiting
  on you, done (and not looked at yet), busy, idle, or dead.
- `ttop` (alias `tt`) shows the same list live, like `top`. Jump to an agent, open a new
  session, delete a session or an agent, or bring dead agents back.
- After a reboot, a dead agent comes back where it was: the same session, windows and
  splits, with its resume command typed into its own pane.
- `tmux-agents.bash` adds `t`, `trm`, `tmv`, `tmux-doctor` and a tmux auto-start to bash.

```
ttop · myhost · 11:22:25

 1 api*
           ◐ busy    fix-auth      1m  > Run the integration tests again
           ● waiting docs-update  12m  Should I open the PR?
 2 scratch
 3 infra   ● done    myagent       2h  Plan applied: 3 resources changed.

↑↓ select · enter or 1-9 open/resume · n new session · del delete · R resume all dead · q quit · * attached
```

The columns are: session, state, agent name, age, and what the agent last said or asked.
A session with one agent is one row. A session with no agent or several has a row of its
own, and each agent gets a row under it. In a narrow window the names and the summary
shrink to fit; session names lose their middle, so names that share a start stay apart.

## Requirements

- Linux (tls reads `/proc`), tmux 3.0 or newer, Python 3.7 or newer, bash.
- For agent states: Claude Code, or any agent that reports with `tls report`. Without
  agents you still get the session list and the shell helpers.

## Install

```sh
git clone <this repo> tmux-agents && cd tmux-agents
./install.sh                    # into ~/.local/bin; --bin DIR picks another directory
echo '. ~/.local/bin/tmux-agents.bash' >> ~/.bashrc
```

`install.sh` copies the files and runs `tls setup`. Setup adds the Claude Code adapter
(`tls hook`, for nine hook events) to `~/.claude/settings.json`, with a backup, and
registers the tmux hooks. Add `--tmux-conf` to also install `config/tmux.conf` as
`~/.tmux.conf`. For tmux on every interactive terminal, add `tmux_autostart main` after
the line that sources `tmux-agents.bash`.

## Other agents

An agent shows up in ttop once it, or a hook or wrapper of it, runs `tls report`:

```sh
tls report id=abc123 agent=myagent state=busy prompt="port the parser" resume="myagent --resume abc123"
tls report id=abc123 state=waiting summary="Push to main?"
tls report id=abc123 state=finished message="$LAST_MESSAGE"   # tls tells done, waiting and blocked apart
tls report id=abc123 end=deliberate                            # the user quit
```

[docs/interface.md](docs/interface.md) defines the fields, the states and the lifecycle.
Claude Code goes through the same interface: `tls hook` turns each Claude hook event into
a report.

## ttop keys

| Key | Action |
| --- | --- |
| ↑ ↓ Home End PgUp PgDn | select a row |
| Enter | open the selected session or agent (switch inside tmux, attach outside; detach to come back), or bring back a dead agent |
| 1-9, a-z | the same for the row with that key: a session opens at its most urgent agent |
| n | new session with a free adjective-noun name, in the current directory |
| Del or Backspace | delete the selected session (kill-session), agent (kill-pane) or dead agent (forget it); Enter confirms |
| R | bring back all dead agents |
| d | forget a dead agent: the selected one, or press its key |
| q | quit |

## Shell helpers

| Command | Action |
| --- | --- |
| `t [NAME]` | switch to (inside tmux) or attach to session NAME, creating it if needed; no NAME: a new session with a free name |
| `trm NAME...` | kill sessions |
| `tmv [OLD] NEW` | rename a session, the current one if OLD is left out |
| `tt` | `ttop` |
| `tmux-doctor` | client and server versions, when tmux misbehaves after an upgrade |
| `tmux-cache-clean` | drop cached tmux clients that no server needs any more |
| `tmux_autostart [NAME]` | on an interactive terminal outside tmux, attach to session NAME (default `main`) |

Session names match exactly. On its own, tmux resolves `-t foo` to a session `foobar`
when there's no `foo`.

## How it works

Every agent session has a JSON record in `~/.local/state/agent-tls/`, which reports
update. tls mirrors the state into the agent's tmux pane options, and tmux hooks turn a
green agent grey when you select its pane. A report with `state=finished` hands over the
agent's last message, and tls picks waiting, blocked or done from it. A
`tmux-agent-classify` file next to `tls`, if present, decides instead: it must define
`classify(text)` that returns `(verdict, rule, sentence)`.

Reports and ttop also save the layout of every session that has an agent, in
`layouts.json`, keyed by tmux server, so a reboot can't overwrite it. To bring a dead
agent back, tls types its resume command into its old pane if that pane is at a shell
prompt. If the session is gone, tls rebuilds it (all windows, each pane in its old
directory, the saved layout) and resumes each agent in its own pane. If only the pane is
gone, tls splits it back into its window.

`tls -h` lists every command; the comments at the top of `bin/tls` explain the rest.

## Tests

```sh
bin/tls-test     # about 90 checks on throwaway tmux servers, with a temporary state dir
```

The tests never touch your tmux server, your settings or your state directory: every
tmux command in them names its own socket.

## Uninstall

Delete the `tls hook` entries from `~/.claude/settings.json`, the installed files, and the
`tmux-agents.bash` line in `~/.bashrc`. tmux drops its hooks when its server restarts.
