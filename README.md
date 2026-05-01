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

## 特性

- 支持玩家和 bot。
- 保留原版换弹动画与时序，只调整后备弹药。
- 同一次换弹只扣一次。
- 保留武器自身备弹节奏，例如 FAMAS `90 -> 65 -> 40 -> 15 -> 0`。
- 支持最后一匣非满弹匣，例如 Galil `1/20 -> 20/0`。
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
```

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
- 如果服务器大幅修改武器弹匣或备弹，可能需要额外适配。

</details>

<details>
<summary id="english"><strong>English</strong></summary>

## What It Does

Realistic Reload tries to bring CS2's updated realistic reload style back to CS:GO: when you reload early, rounds left in the old magazine are treated as discarded.

Example: in vanilla CS:GO, an AK-47 reload from `25/90` becomes `30/85`; with this plugin, it becomes `30/60`.

## Features

- Supports players and bots.
- Keeps the game's reload animation and timing, only adjusting reserve ammo.
- Applies once per reload.
- Preserves each weapon's reserve cadence, such as FAMAS `90 -> 65 -> 40 -> 15 -> 0`.
- Handles final partial magazines, such as Galil `1/20 -> 20/0`.
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
```

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
- Servers with heavily customized clip or reserve ammo may need extra compatibility work.

</details>

## License

MIT
