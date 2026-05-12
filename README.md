# Realistic Reload

CS:GO SourceMod plugin that brings CS2-style magazine discard behavior back to CS:GO.

<p align="center">
  <a href="#中文">中文</a> · <a href="#english">English</a>
</p>

<details open>
<summary id="中文"><strong>中文</strong></summary>

## 这是什么

Realistic Reload 是一个小型 CS:GO SourceMod 插件。它把 CS2 更新后的写实换弹手感带回 CS:GO：提前换弹时，旧弹匣里剩下的子弹会被视为随弹匣丢弃，而不是自动回到备弹。

原版 CS:GO：

```text
AK-47 25/90 -> 换弹 -> 30/85
```

启用本插件：

```text
AK-47 25/90 -> 换弹 -> 30/60
```

这会让提前换弹从一个几乎无成本的习惯动作，变成一个需要判断时机和资源的选择。玩家仍然获得原版动画、原版换弹时长和熟悉的武器操作，但弹药经济更接近 CS2 的写实弹匣逻辑。

## 核心规则

提前换弹开始时，插件记录当前弹匣和备弹。游戏完成正常换弹后，插件观察引擎实际给出的新弹匣数量，再按下面的规则写回弹药：

```text
最终弹匣 = min(游戏完成换弹后的弹匣数量, 换弹开始时的备弹)
最终备弹 = max(换弹开始时的备弹 - 最终弹匣, 0)
```

旧弹匣剩余子弹不会返还备弹。

更多行为说明见 [`docs/BEHAVIOR.md`](docs/BEHAVIOR.md)。

## 特性

- 支持玩家和 bot。
- 保留 CS:GO 原版换弹动画、时序和武器操作，只调整弹药结果。
- 同一次换弹只应用一次，避免重复扣弹。
- 切枪、取消或其他未完成的假换弹不会扣除备弹。
- 根据游戏运行时实际完成换弹后的弹匣结果计算，不依赖硬编码弹匣表。
- 支持最后一匣非满弹匣，例如 `AK-47 25/10 -> 10/0`。
- 支持社区服自定义弹匣或备弹，不要求备弹刚好是满弹匣的整数倍。
- 新回合开始或玩家出生时清理未完成跟踪，避免跨回合换弹覆盖新回合备弹恢复。
- 默认排除逐发装填霰弹枪；MAG-7 按弹匣武器处理。
- 提供可选 debug 日志，用于排查特殊服务器上的换弹时序。

## 安装

1. 确认服务器已安装 SourceMod。
2. 将仓库中的已编译插件复制到服务器：

```text
addons/sourcemod/plugins/realistic_reload.smx
```

目标位置：

```text
csgo/addons/sourcemod/plugins/realistic_reload.smx
```

3. 重启服务器、换图，或在服务器控制台执行：

```text
sm plugins load realistic_reload
```

首次运行后，SourceMod 会生成配置文件：

```text
csgo/cfg/sourcemod/realistic_reload.cfg
```

## 配置

默认配置：

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
sm_realistic_reload_debug "0"
```

| ConVar | 默认值 | 说明 |
| --- | --- | --- |
| `sm_realistic_reload_enable` | `1` | 总开关。 |
| `sm_realistic_reload_humans` | `1` | 是否作用于真人玩家。 |
| `sm_realistic_reload_bots` | `1` | 是否作用于 bot。 |
| `sm_realistic_reload_align_reserve` | `1` | 旧配置兼容项；当前运行时算法忽略它的值。 |
| `sm_realistic_reload_exclude_shotguns` | `1` | 是否保留逐发装填霰弹枪的原版行为。 |
| `sm_realistic_reload_debug` | `0` | 是否输出换弹时序诊断日志。 |

修改配置后可以换图，或按服务器习惯重新执行配置。排查问题时可临时打开 debug：

```text
sm_cvar sm_realistic_reload_debug 1
```

日志会包含 `state`、`track_start`、`complete_observed`、`track_cancel` 和 `apply_complete`。测试结束后建议关闭：

```text
sm_cvar sm_realistic_reload_debug 0
```

## 行为例子

| 场景 | 原版倾向 | 插件结果 |
| --- | --- | --- |
| AK-47 `25/90` 完成换弹 | `30/85` | `30/60` |
| AK-47 `25/10` 完成换弹 | 可能补到非写实状态 | `10/0` |
| Galil `1/20` 完成换弹 | 容易出现最后一匣边界问题 | `20/0` |
| AK-47 `25/90` 换弹中途切枪 | 不应消耗新弹匣 | 不扣除插件备弹 |
| 跨回合未完成换弹 | 可能污染新回合状态 | 新回合/出生时清理跟踪 |

## 编译

如果你只想安装插件，可以直接使用仓库里的：

```text
addons/sourcemod/plugins/realistic_reload.smx
```

如果修改了源码，需要有 SourceMod scripting 目录，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

也可以先设置环境变量：

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

编译成功后会更新：

```text
addons/sourcemod/plugins/realistic_reload.smx
```

## 兼容性

- 本插件面向 CS:GO。
- CS2 不以相同方式支持 SourceMod。
- 当前算法通过运行时观测换弹结果来提高兼容性，但如果服务器完全替换了武器换弹实现，仍可能需要额外适配。
- 默认霰弹枪排除适用于 Nova、Sawed-Off 和 XM1014；MAG-7 继续按弹匣武器处理。

## 排查建议

如果你发现某把武器结果不符合预期：

1. 打开 `sm_realistic_reload_debug`。
2. 记录换弹前的弹匣/备弹，例如 `25/90`。
3. 完成一次普通换弹，不切枪、不死亡、不跨回合。
4. 查看日志中的 `track_start`、`complete_observed` 和 `apply_complete`。
5. 如果只出现 `track_cancel`，说明换弹在插件观察到完成前被取消或切走。

</details>

<details>
<summary id="english"><strong>English</strong></summary>

## What It Does

Realistic Reload is a small CS:GO SourceMod plugin. It brings CS2-style magazine discard behavior back to CS:GO: when a player reloads early, rounds left in the old magazine are discarded instead of returning to reserve ammo.

Vanilla CS:GO:

```text
AK-47 25/90 -> reload -> 30/85
```

With this plugin:

```text
AK-47 25/90 -> reload -> 30/60
```

Early reloads become a tactical choice with a real ammo cost while keeping CS:GO's original reload animation, timing, and weapon feel.

## Core Rule

When an early reload starts, the plugin records the current clip and reserve ammo. After the game completes its normal reload, the plugin observes the engine's actual post-reload clip and writes back the realistic result:

```text
final_clip = min(engine_clip_after_reload, reserve_at_reload_start)
final_reserve = max(reserve_at_reload_start - final_clip, 0)
```

Rounds left in the old magazine are not returned to reserve.

See [`docs/BEHAVIOR.md`](docs/BEHAVIOR.md) for detailed behavior notes.

## Features

- Supports players and bots.
- Keeps the game's reload animation and timing; only the ammo result changes.
- Applies once per reload.
- Does not deduct reserve ammo for interrupted or fake reloads.
- Uses the game's runtime post-reload clip result instead of hard-coded weapon tables.
- Handles final partial magazines, such as `AK-47 25/10 -> 10/0`.
- Supports custom server clip and reserve counts without requiring reserve to be a full-magazine multiple.
- Clears pending tracking on round start and player spawn to preserve new-round ammo restoration.
- Excludes shell-by-shell shotguns by default; MAG-7 is treated as magazine-fed.
- Includes optional debug logs for reload timing diagnostics.

## Install

1. Make sure your server has SourceMod installed.
2. Copy the checked-in compiled plugin:

```text
addons/sourcemod/plugins/realistic_reload.smx
```

to:

```text
csgo/addons/sourcemod/plugins/realistic_reload.smx
```

3. Restart the server, change map, or run:

```text
sm plugins load realistic_reload
```

The plugin creates this config after first run:

```text
csgo/cfg/sourcemod/realistic_reload.cfg
```

## Config

Defaults:

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
sm_realistic_reload_debug "0"
```

| ConVar | Default | Description |
| --- | --- | --- |
| `sm_realistic_reload_enable` | `1` | Master enable switch. |
| `sm_realistic_reload_humans` | `1` | Apply to human players. |
| `sm_realistic_reload_bots` | `1` | Apply to bots. |
| `sm_realistic_reload_align_reserve` | `1` | Deprecated compatibility ConVar; ignored by the current runtime algorithm. |
| `sm_realistic_reload_exclude_shotguns` | `1` | Preserve vanilla shell-by-shell shotgun behavior. |
| `sm_realistic_reload_debug` | `0` | Emit reload timing diagnostics. |

Enable debug temporarily when diagnosing behavior:

```text
sm_cvar sm_realistic_reload_debug 1
```

Logs include `state`, `track_start`, `complete_observed`, `track_cancel`, and `apply_complete`. Disable it after testing:

```text
sm_cvar sm_realistic_reload_debug 0
```

## Behavior Examples

| Scenario | Vanilla tendency | Plugin result |
| --- | --- | --- |
| AK-47 `25/90` completed reload | `30/85` | `30/60` |
| AK-47 `25/10` completed reload | Can produce non-realistic end states | `10/0` |
| Galil `1/20` completed reload | Final partial edge cases are easy to mishandle | `20/0` |
| AK-47 `25/90`, switch weapon during reload | Should not spend a new magazine | No plugin reserve deduction |
| Reload crosses round boundary | Can pollute new-round state if tracked too long | Pending state is cleared on round start/spawn |

## Build

If you only want to install the plugin, use:

```text
addons/sourcemod/plugins/realistic_reload.smx
```

If you change the source, compile with a SourceMod scripting directory:

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

Or set:

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

Successful builds write:

```text
addons/sourcemod/plugins/realistic_reload.smx
```

## Compatibility

- This plugin targets CS:GO.
- CS2 does not support SourceMod in the same way.
- The runtime-observed algorithm improves compatibility with custom ammo setups, but servers that fully replace weapon reload behavior may still need extra adaptation.
- Default shotgun exclusion covers Nova, Sawed-Off, and XM1014; MAG-7 remains on the magazine-fed realistic path.

## Troubleshooting

If a weapon result looks wrong:

1. Enable `sm_realistic_reload_debug`.
2. Record the starting clip/reserve, such as `25/90`.
3. Complete one normal reload without switching weapons, dying, or crossing a round boundary.
4. Check `track_start`, `complete_observed`, and `apply_complete`.
5. If you only see `track_cancel`, the reload was interrupted before the plugin observed completion.

</details>

## License

MIT
