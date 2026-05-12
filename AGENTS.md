# AGENTS.md

Guidance for Codex and other LLM agents working on this repository.

## Project

This repository contains a small CS:GO SourceMod plugin:

- Source: `addons/sourcemod/scripting/realistic_reload.sp`
- Checked-in build artifact: `addons/sourcemod/plugins/realistic_reload.smx`
- Build helper: `tools/compile.ps1`
- User documentation: `README.md` and `docs/BEHAVIOR.md`
- Release notes: `CHANGELOG.md`

The plugin brings CS2-style magazine discard behavior back to CS:GO. When a player starts an early reload, the old magazine is treated as discarded. The implementation waits for the engine to finish the reload, observes the actual post-reload clip size, then rewrites clip and reserve ammo to the realistic result.

## Working Principles

- Keep changes small, scoped, and easy to audit.
- Preserve the SourcePawn style already used in `realistic_reload.sp`.
- Do not reformat unrelated code or churn generated files.
- Do not commit temporary analysis, compiler scratch files, logs, or local test output.
- Prefer runtime-observed behavior over hard-coded weapon tables when practical.
- Make player-visible behavior explicit in docs and changelog.
- If a request mentions stale worktrees, inspect them first and report status before deleting anything.

## SourcePawn Rules

- Treat shell-by-shell shotguns differently from magazine-fed weapons.
- MAG-7 is magazine-fed and should use the realistic reload path.
- If weapon classnames are ambiguous, prefer item definition indexes where practical.
- Be careful with `EntIndexToEntRef` and stale entity handles; clear pending state when clients disconnect, die, spawn, or cross round boundaries.
- Keep ConVars backward-compatible unless a breaking change is intentional and documented.
- `sm_realistic_reload_align_reserve` is deprecated compatibility surface; the current runtime algorithm ignores its value.

## Documentation Rules

- Update `README.md` when behavior, install steps, build steps, supported cases, or ConVars change.
- Update `docs/BEHAVIOR.md` when the algorithm, examples, troubleshooting flow, or manual validation cases change.
- Update `CHANGELOG.md` and `PLUGIN_VERSION` for user-visible behavior changes.
- Keep changelog entries concise and bilingual when practical. Mention player-visible changes first, then implementation details.
- For docs-only edits, do not bump `PLUGIN_VERSION` unless the published package behavior changes.

## Build

Use the provided PowerShell helper when a SourceMod scripting directory is available:

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

Or set:

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

The helper writes `addons/sourcemod/plugins/realistic_reload.smx`.

## Validation

- Prefer compiling with `tools/compile.ps1` after SourcePawn changes.
- If the compiler is unavailable, inspect array sizes, enum indexes, ConVar names, and entity property usage carefully, then state that compile validation was skipped.
- For behavior changes, describe manual in-game checks with starting clip/reserve and expected final clip/reserve.
- For docs-only changes, run a narrow status/diff review and ensure temporary files are not staged.

## Manual Behavior Checks

Useful examples when behavior changes:

- AK-47 early reload: `25/90 -> 30/60`
- AK-47 final partial magazine: `25/10 -> 10/0`
- Galil final partial magazine: `1/20 -> 20/0`
- Interrupted reload by weapon switch: reserve should not change because completion was not observed.
- Round boundary while reloading: new-round reserve restoration should not be overwritten.
- MAG-7 reload: should follow the realistic magazine path.
- Nova/Sawed-Off/XM1014 with shotgun exclusion enabled: shell-by-shell behavior should remain unchanged.

## Git

- Keep a clean, reviewable diff.
- Commit only the files that belong to the requested unit of work.
- Do not commit `tmp/` notes or other local-only analysis unless the user explicitly asks for them.
- Before push, confirm `git status --short` so unrelated user work is not staged accidentally.
