# Agent status interface, version 1

tls shows any coding agent that reports its state with `tls report`. The agent runs it,
or a hook, notify command or wrapper script of the agent does:

```sh
tls report id=ID [key=value ...]
printf '%s' '{"id": "ID", "state": "busy"}' | tls report     # the same fields, as one JSON object
```

`tls report` reads stdin only when it has no arguments, or when one of them is `-`. It
prints nothing on success. A bad report (unknown field, bad `id`, unknown `state`) exits
with status 2 and the reason on stderr.

Run it in the agent's environment, best as a child of the agent's process. tls finds the
agent's tmux pane through `$TMUX` and `$TMUX_PANE`, and the agent's process through `pid`
or the process tree.

## Fields

Only `id` is required. A report sets the fields it carries and leaves the others as they
were.

| Field | Value |
| --- | --- |
| `id` | the session's id, unique across all agents: up to 120 letters, digits and `_.:-`, starting with a letter or a digit |
| `agent` | the kind of agent, such as `claude`; tls also looks for a process of this name above the reporter |
| `state` | see [States](#states) |
| `summary` | one line for the summary column: the question, the blocker, the result |
| `message` | the agent's last message; `state=finished` reads it |
| `prompt` | the user's last prompt, shown while the agent is busy or idle |
| `name` | the name the user gave the session |
| `title` | a title for the conversation, shown when there's no name |
| `pid` | the agent's process. Default: the nearest ancestor process named like `agent`, else the process the session already has, else the reporter's parent |
| `cwd` | the agent's working directory. Default: the reporter's |
| `resume` | a shell command that resumes the session in a new shell, such as `myagent --resume ID`. Without one, a dead session can't come back |
| `transcript` | a file that resuming needs; once it's gone, tls drops the dead session |
| `start` | `true`: the session has a new process. tls also sees a new `pid` by itself |
| `end` | `deliberate`: the user quit, so tls drops the session. Any other value, such as `killed`: the session ended and stays resumable |
| `event` | a label for the report, kept in the record for debugging |

## States

| State | Meaning | Dot |
| --- | --- | --- |
| `busy` | working on a turn | blue ◐ |
| `waiting` | waiting for the user: a question, a plan, a permission | yellow ● |
| `blocked` | stuck on something the user must do, such as touching a security key, or a failed turn | red ● |
| `done` | the turn is over and the user hasn't looked yet; tls makes it `idle` when the user looks | green ● |
| `idle` | nothing to do | grey ○ |
| `background` | the turn is over, background work goes on | blue ◌ |
| `finished` | the turn is over: tls reads `message` and picks `waiting` (a closing question that isn't just an offer of more work), `blocked` (a security key or login request) or `done` | |

A report with a new state and no `summary` clears the old summary.

## Lifecycle

1. The first report of an `id` creates the session.
2. Report when the state changes. Repeating a state is harmless but not needed.
3. If the agent's process dies without an `end`, tls finds out (by process id, process
   start time and boot id) and lists the session as dead. If it has a `resume` command,
   ttop can bring it back in its old pane, window and session.
4. `end=deliberate` drops the session at once.

## Examples

From an agent's hook, when a turn ends:

```sh
tls report id="$SESSION_ID" agent=myagent state=finished message="$LAST_MESSAGE"
```

From an agent's hook, when it asks for permission:

```sh
tls report id="$SESSION_ID" state=waiting summary="permission: run make install"
```

A wrapper, for an agent that can't run commands on its events. It only knows when the
agent starts and stops:

```sh
#!/bin/sh
id="myagent-$$"
tls report id="$id" agent=myagent pid=$$ state=busy resume="myagent --continue"
myagent "$@"
tls report id="$id" end=deliberate
```

## Claude Code

`tls hook` is the Claude Code adapter. `tls setup` adds it to `~/.claude/settings.json`
for nine hook events, and it turns each event into a report:

| Claude Code event | Report |
| --- | --- |
| SessionStart | `start`, `state=idle` (no state change after a compaction) |
| UserPromptSubmit | `state=busy`, `prompt` |
| PreToolUse for AskUserQuestion or ExitPlanMode, PermissionRequest, Notification for a permission prompt | `state=waiting`, `summary`: the question, or the tool call that needs permission |
| PostToolUse | `state=busy`, if the session wasn't busy |
| Notification for an idle prompt | `state=idle`, after Esc stopped a turn |
| Stop | `state=finished` with the last message, or `state=background` while background tasks run |
| StopFailure | `state=blocked`, when a turn failed |
| SessionEnd | `end=deliberate` for exit, `/clear` and logout; else `end` with Claude's reason |

The adapter also reads the session's name (from `/rename`) and Claude's title for the
conversation from the end of the transcript. Claude sessions resume with
`claude --resume ID`.
