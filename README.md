# Realistic Reload

CS:GO SourceMod plugin that brings CS2-style realistic reload ammo loss back to CS:GO.

<p align="center">
  <a href="#中文">中文</a> · <a href="#english">English</a>
</p>

<details open>
<summary id="中文"><strong>中文</strong></summary>

## 这是什么

Realistic Reload 会把 CS2 更新后的写实换弹风格尝试迁移到 CS:GO：提前换弹时，旧弹匣里剩下的子弹会被视为丢弃。

例子：AK-47 从 `25/90` 换弹，原版 CS:GO 会变成 `30/85`；启用本插件后会变成 `30/60`。

规则：提前换弹开始时，旧弹匣被丢弃，新弹匣只从当时的备弹填入。如果备弹少于游戏实际换弹后的目标弹匣数量，结果会变成最后一匣非满弹匣，例如 AK-47 `25/10 -> 10/0`。

## 特性

- 支持玩家和 bot。
- 保留原版换弹动画与时序，只调整后备弹药。
- 同一次换弹只扣一次。
- 中断的假换弹不会扣除备弹。
- 根据游戏实际换弹后的弹匣结果计算，不依赖内置武器弹匣或备弹表。
- 支持最后一匣非满弹匣，例如 Galil `1/20 -> 20/0`。
- 支持社区服修改弹匣或备弹，不要求备弹是满弹匣的整数倍。
- 默认排除逐发装填霰弹枪；MAG-7 按弹匣武器处理。

## 安装

1. 将 `addons/sourcemod/plugins/realistic_reload.smx` 放到服务器的 `addons/sourcemod/plugins/`。
2. 重启服务器、换图，或执行：

```text
sm plugins load realistic_reload
```

首次运行会生成配置：

```text
cfg/sourcemod/realistic_reload.cfg
```

## 配置

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
sm_realistic_reload_debug "0"
```

`sm_realistic_reload_align_reserve` 仅为兼容旧配置保留；当前运行时算法会忽略它。

临时排查换弹时序时，可将 `sm_realistic_reload_debug` 设为 `1`，日志会记录 `state`、`track_start`、`complete_observed`、`track_cancel` 和 `apply_complete`。

## 编译

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

也可以先设置：

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

## 备注

- 本插件面向 CS:GO。
- CS2 不以相同方式支持 SourceMod。
- 当前运行时算法旨在支持社区服修改弹匣或备弹；如果服务器改写了换弹实现，可能仍需要额外适配。

</details>

<details>
<summary id="english"><strong>English</strong></summary>

## What It Does

Realistic Reload tries to bring CS2's updated realistic reload style back to CS:GO: when you reload early, rounds left in the old magazine are treated as discarded.

Example: in vanilla CS:GO, an AK-47 reload from `25/90` becomes `30/85`; with this plugin, it becomes `30/60`.

Rule: when an early reload starts, the old magazine is discarded and the new magazine is filled only from the reserve ammo available at that moment. If reserve ammo is lower than the game's observed post-reload target clip, the result is a final partial magazine, such as AK-47 `25/10 -> 10/0`.

## Features

- Supports players and bots.
- Keeps the game's reload animation and timing, only adjusting reserve ammo.
- Applies once per reload.
- Does not deduct reserve ammo for interrupted fake reloads.
- Derives behavior from the game's actual post-reload clip result instead of built-in weapon clip or reserve tables.
- Handles final partial magazines, such as Galil `1/20 -> 20/0`.
- Supports custom server clip or reserve counts without requiring reserve ammo to be a full-magazine multiple.
- Excludes shell-by-shell shotguns by default; MAG-7 is treated as a magazine-fed weapon.

## Install

1. Put `addons/sourcemod/plugins/realistic_reload.smx` into your server's `addons/sourcemod/plugins/`.
2. Restart the server, change map, or run:

```text
sm plugins load realistic_reload
```

The plugin creates this config after first run:

```text
cfg/sourcemod/realistic_reload.cfg
```

## Config

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
sm_realistic_reload_debug "0"
```

`sm_realistic_reload_align_reserve` is kept only for old config compatibility; the current runtime algorithm ignores it.

Set `sm_realistic_reload_debug` to `1` temporarily to inspect reload timing. Logs include `state`, `track_start`, `complete_observed`, `track_cancel`, and `apply_complete`.

## Build

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

Or set:

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

## Notes

- This plugin targets CS:GO.
- CS2 does not support SourceMod in the same way.
- The runtime-observed algorithm is intended to support custom clip or reserve counts; servers that replace reload behavior may still need extra compatibility work.

</details>

## License

MIT
