# Agent Notes (zsh-opencode-tab)

This repo contains an Oh-My-Zsh plugin that turns a natural-language request into a shell command when the user presses TAB, while showing a ZLE-safe "Knight Rider" spinner animation.

## Behavior

- Trigger: only activates when the current ZLE buffer begins with a comment request (`# ...`).
- If it matches: strip leading whitespace and leading `#`, send the request to the opencode worker, then replace the entire `BUFFER` with the generated command(s).
- If it does not match: fall back to the original TAB completion widget.
- No worker output is printed to the terminal during ZLE.

## ZLE Rendering / Spinner

- ZLE-safe rendering: never print to `/dev/tty` while ZLE is active.
- Spinner overlay is rendered by updating the editor line (`BUFFER`) + `region_highlight` (colors), not by terminal output.
- Colors: ported opencode's `spinner.ts` "Knight Rider" trail algorithm.
  - Terminals lack alpha, so alpha is simulated by blending against a configured background hex.
- Timing: uses `EPOCHREALTIME`; one knob controls frame interval.

## Configuration Model

- All user-facing config is resolved once at plugin load time in `zsh-opencode-tab.plugin.zsh` into:
  - `typeset -gA _zsh_opencode_tab`
- Controller/spinner read from `_zsh_opencode_tab[...]`.
- Spinner writes only runtime state under `spinner.state.*` keys (palette, inactive fg, base/bg rgb floats).

## Opencode Integration

- Uses `opencode run --format json` (NDJSON events) so we can parse a `sessionID`.
- Default backend attaches to `http://localhost:4096` to avoid cold start.
- Configurable: `agent` (default `shell_cmd_generator`), optional `variant`, `title` (default `zsh shell assistant`), log level mapping.
- Disposable sessions: optional `DELETE /session/<id>` after collecting output.

- `OPENCODE_CONFIG_DIR` is set for the opencode subprocess (default: `${plugin_dir}/opencode`).
- Default agent is `shell_cmd_generator` (loaded from `OPENCODE_CONFIG_DIR/agents/shell_cmd_generator.md`).

### Worker -> Zsh Output Protocol

- Implemented in `src/opencode_generate_command.py`, parsed in `src/controller.zsh`.
- Format: `session_id + US + text + "\n"`
  - `US` is ASCII Unit Separator (0x1f).
  - `session_id` may be empty; today Zsh does not use it, but we keep it for future features and as a cheap integrity signal.

### User Prompt Format (Worker -> Opencode)

```text
<user>
<config>
OSTYPE=...
GNU=...
</config>
<request>
...
</request>
</user>
```

## Key Files

- Plugin entry/binding: `zsh-opencode-tab.plugin.zsh`
- TAB interception + fallback: `src/zsh-opencode-tab.zsh`
- Controller (process lifecycle + spinner loop): `src/controller.zsh`
- Spinner renderer (render-only): `src/spinner.zsh`
- Opencode worker: `src/opencode_generate_command.py`
- Opencode agent definition: `opencode/agents/shell_cmd_generator.md`
- Legacy/old: `long_command.sh` still exists; intended to be replaced/removed later
- Legacy docs: `docs/KnightRiderBar.zsh` (intentionally ignored for now)

## Notable Implementation Decisions

- Dot-based function naming is used (zsh supports dots) for module grouping.
- Underscore wrappers exist for backward compatibility; planned removal later.
- Spinner module stays render-only; controller owns worker lifecycle, pacing, Ctrl-C handling.

## What To Verify Next

1) Remove/replace `long_command.sh` after confirming it's unused.
2) End-to-end ZLE test:
   - Start opencode server (`http://localhost:4096`).
   - In interactive zsh, type `# list all files larger than 100MB` then press TAB.
   - Confirm spinner runs and `BUFFER` is replaced with generated command.
   - Confirm normal TAB completion still works for non-`#` lines.
3) Cleanup (later): remove underscore wrappers; improve error surfacing via `zle -M` or `# ERROR: ...` insertion.

## Constraints / Preferences

- Prefer simple, readable code; keep config commentary near definitions in `zsh-opencode-tab.plugin.zsh`.
- Configuration should be immutable at runtime (resolved once at plugin load).
- Avoid "safeguards" unless truly needed.
