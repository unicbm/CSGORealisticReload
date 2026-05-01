# AGENTS.md

Guidance for Codex and other LLM agents working on this repository.

## Project

This is a small SourceMod plugin for CS:GO. The main source file is:

- `addons/sourcemod/scripting/realistic_reload.sp`

The compiled plugin checked into the repo is:

- `addons/sourcemod/plugins/realistic_reload.smx`

The plugin makes early reloads discard the old magazine by reducing reserve ammo. It targets CS:GO and tries to bring CS2's updated realistic reload feel back to CS:GO.

## Change Rules

- Keep changes small and focused.
- Preserve SourcePawn style already used in `realistic_reload.sp`.
- Do not reformat unrelated code.
- Treat shell-by-shell shotguns differently from magazine-fed weapons. MAG-7 is magazine-fed and should use the realistic reload path.
- If weapon names are ambiguous, prefer item definition indexes where practical.
- Update `PLUGIN_VERSION` and `CHANGELOG.md` for user-visible behavior changes.
- Update `README.md` when behavior, install steps, or ConVars change.
- Do not commit generated or temporary files.

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
- If the compiler is unavailable, inspect array sizes and enum indexes carefully and state that compile validation was skipped.
- For behavior changes, describe manual in-game checks with starting clip/reserve and expected final clip/reserve.

## Release Notes

Keep changelog entries concise and bilingual when practical. Mention player-visible changes first, then implementation details.
