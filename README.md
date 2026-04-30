# Realistic Reload

<p align="center">
  <a href="#中文">中文</a> · <a href="#english">English</a>
</p>

<details open>
<summary id="中文"><strong>中文</strong></summary>

## 简介

Realistic Reload 是一个用于 CS:GO 的 SourceMod 插件，让提前换弹更接近真实的“丢弃旧弹匣”。

在原版 CS:GO 中，AK-47 从 `25/90` 换弹会变成 `30/85`。启用本插件后，它会变成 `30/60`：旧弹匣剩下的 25 发会被视为丢弃。

这个机制会让玩家认真权衡什么时候换弹，而不是无脑把每个弹匣补满。

## 功能

- 同时支持人类玩家和 bot。
- 通过扣除后备弹药实现，尽量保留游戏原本的换弹动画和时序。
- 同一次换弹只会扣一次，避免重复扣弹。
- 默认让后备弹遵循武器自身的备弹节奏，例如 FAMAS `90 -> 65 -> 40 -> 15 -> 0`。
- 最后一匣非满弹匣会直接显示为正确结果，例如 Galil `1/20 -> 20/0`，AWP `4/5 -> 5/0`。
- 默认排除逐发装填的霰弹枪。
- 对 USP-S、M4A1-S、CZ75-Auto、R8 等 classname 可能有歧义的武器使用 item definition index 判定。

## 控制台变量

插件首次运行后会生成配置文件：

```text
cfg/sourcemod/realistic_reload.cfg
```

可用 ConVar：

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
```

## 安装

1. 下载或复制 `addons/sourcemod/plugins/realistic_reload.smx`。
2. 将它放到服务器的 `addons/sourcemod/plugins/`。
3. 重启服务器、换图，或执行 `sm plugins load realistic_reload`。

## 编译

如果你本地有 SourceMod 的 `scripting` 目录，可以直接指定路径：

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

也可以设置环境变量：

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

## 注意事项

- 本插件面向 CS:GO。
- CS2 并不以相同方式支持 SourceMod。
- 霰弹枪默认排除，因为它们是逐发装填，不是整弹匣替换。
- 如果服务器魔改了武器弹匣容量或后备弹数量，插件会尽量使用当前武器状态，但极端自定义配置可能需要额外适配。

## 许可证

MIT

</details>

<details>
<summary id="english"><strong>English</strong></summary>

## Overview

Realistic Reload is a SourceMod plugin for CS:GO that makes early reloads behave more like discarded magazines.

In vanilla CS:GO, an AK-47 reload from `25/90` becomes `30/85`. With this plugin, it becomes `30/60`: the 25 rounds left in the old magazine are treated as discarded.

This makes reload timing a real ammo-management decision instead of a free habit.

## Features

- Supports both human players and bots.
- Deducts reserve ammo while preserving the game's normal reload animation and timing as much as possible.
- Applies the deduction only once per reload.
- Preserves each weapon's default reserve cadence, such as FAMAS `90 -> 65 -> 40 -> 15 -> 0`.
- Handles final partial magazines directly, such as Galil `1/20 -> 20/0` and AWP `4/5 -> 5/0`.
- Excludes shell-by-shell shotguns by default.
- Uses item definition indexes for ambiguous classname weapons such as USP-S, M4A1-S, CZ75-Auto, and R8 Revolver.

## ConVars

The plugin generates its config file after first run:

```text
cfg/sourcemod/realistic_reload.cfg
```

Available ConVars:

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
```

## Installation

1. Download or copy `addons/sourcemod/plugins/realistic_reload.smx`.
2. Put it in the server's `addons/sourcemod/plugins/`.
3. Restart the server, change map, or run `sm plugins load realistic_reload`.

## Build

If you have a local SourceMod `scripting` directory, pass it explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

Or set an environment variable:

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

## Notes

- This plugin targets CS:GO.
- CS2 is not supported by SourceMod in the same way.
- Shotguns are excluded by default because they reload shell by shell instead of replacing a full magazine.
- If your server modifies weapon clip sizes or reserve ammo heavily, the plugin will use the current weapon state where possible, but extreme custom weapon configs may need extra compatibility work.

## License

MIT

</details>
