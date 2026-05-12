# Realistic Reload Behavior Guide

This document explains the plugin behavior, the runtime algorithm, and practical validation cases for server owners and future maintainers.

## Short Version

Realistic Reload changes early reloads from "top up the current magazine" to "discard the old magazine and insert a new one."

Vanilla CS:GO example:

```text
AK-47 25/90 -> reload -> 30/85
```

Realistic Reload example:

```text
AK-47 25/90 -> reload -> 30/60
```

The five rounds left in the old magazine are not moved back into reserve. They are discarded with the old magazine.

## Core Rule

When a reload begins with a non-empty clip and positive reserve ammo:

1. The plugin records the starting clip and reserve ammo.
2. The game performs its normal reload animation and timing.
3. The plugin waits until the engine has actually increased the weapon clip.
4. The plugin treats the starting reserve as the only ammo available for the new magazine.
5. The final clip becomes the smaller of:
   - the engine-observed post-reload clip, or
   - the reserve ammo available when the reload started.
6. The final reserve becomes the starting reserve minus the final clip.

In formula form:

```text
final_clip = min(engine_clip_after_reload, reserve_at_reload_start)
final_reserve = max(reserve_at_reload_start - final_clip, 0)
```

The starting clip is intentionally not added back to reserve.

## Why Runtime Observation Matters

Older implementations of this idea often depend on static clip-size and reserve-size tables. That works for stock weapons, but it breaks easily on community servers that alter weapon ammo values.

This plugin instead observes the engine result at runtime. That makes the behavior more compatible with:

- custom clip sizes,
- custom reserve sizes,
- weapons whose reserve does not divide cleanly into full magazines,
- final partial magazines,
- server-side plugins that adjust ammo before or during reload.

The plugin still needs SourceMod-visible ammo properties to exist, but it does not need to know every weapon's official max clip or official reserve cadence.

## Examples

### Full Reserve

```text
AK-47 25/90 -> 30/60
```

The engine fills the clip to 30. The plugin deducts a full new magazine from the starting reserve, so reserve becomes 60.

### Final Partial Magazine

```text
AK-47 25/10 -> 10/0
```

Only ten reserve rounds were available when the reload started. The new magazine receives those ten rounds and reserve reaches zero.

### Galil Partial End

```text
Galil 1/20 -> 20/0
```

The plugin applies the last partial magazine directly instead of preserving the old clip.

### Interrupted Reload

```text
AK-47 25/90 -> start reload -> switch weapon before completion -> 25/90
```

If the reload is interrupted before the engine increases the clip, the plugin cancels the pending reload record and does not deduct reserve ammo.

### Round Boundary

If a player starts a reload near the end of a round, the plugin clears pending reload tracking on round start and player spawn. This prevents a late reload completion from overwriting the restored ammo for the new round.

## Shotgun Handling

Shell-by-shell shotguns do not behave like normal magazine-fed weapons. By default, `sm_realistic_reload_exclude_shotguns` keeps those weapons unchanged.

Current default exclusions:

- Nova
- Sawed-Off
- XM1014

MAG-7 is magazine-fed and should keep using the realistic reload path.

## ConVars

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
sm_realistic_reload_debug "0"
```

`sm_realistic_reload_align_reserve` is a deprecated compatibility ConVar. It remains present so old configs do not break, but the current runtime algorithm ignores its value.

## Debugging

Temporarily enable diagnostics:

```text
sm_cvar sm_realistic_reload_debug 1
```

Then reproduce one reload. Logs include:

- `state`: active weapon, clip, reserve, reload state, pending ref, applied ref.
- `track_start`: the plugin started tracking a reload.
- `complete_observed`: the engine increased the clip, so completion was observed.
- `track_cancel`: the pending reload was canceled before completion.
- `apply_complete`: final realistic clip/reserve values were applied.

Turn diagnostics off after testing:

```text
sm_cvar sm_realistic_reload_debug 0
```

## Manual Validation Matrix

Use a local CS:GO SourceMod server when compiler or unit-test style validation is not enough.

```text
AK-47 25/90
Expected after completed reload: 30/60
```

```text
AK-47 25/10
Expected after completed reload: 10/0
```

```text
Galil 1/20
Expected after completed reload: 20/0
```

```text
AK-47 25/90, switch weapon before reload completes
Expected after cancel: 25/90 or the engine's normal interrupted state, with no reserve deduction from the plugin.
```

```text
Reload during round end, then spawn next round
Expected: normal new-round ammo restoration is preserved.
```

```text
MAG-7 with shotgun exclusion enabled
Expected: realistic magazine discard behavior still applies.
```

```text
Nova/Sawed-Off/XM1014 with shotgun exclusion enabled
Expected: default shell-by-shell reload behavior remains unchanged.
```

## Maintainer Notes

The plugin runs from `OnPlayerRunCmd` because reload completion is easier to observe reliably from repeated per-client state checks than from a single event. The code stores pending and applied entity references per client so the same reload is applied once and stale weapon entities can be detected.

The most important invariant is: do not deduct reserve until completion is observed. That invariant is what makes interrupted reloads and weapon switches feel correct.
