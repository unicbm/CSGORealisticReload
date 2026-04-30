# Realistic Reload / 拟真换弹

**English:** Realistic Reload is a small SourceMod plugin for CS:GO that makes partial reloads behave like discarded magazines. When a player reloads before the magazine is empty, the remaining rounds in that magazine are removed from reserve ammo.

**中文：** Realistic Reload 是一个用于 CS:GO 的轻量 SourceMod 插件，让“没打空就换弹”更像真实丢弃弹匣：玩家提前换弹时，当前弹匣里剩下的子弹会从后备弹药中扣除。

## Example / 示例

**English:** AK-47 normally goes from `25/90` to `30/85` after reloading. With this plugin, it becomes `30/60`: the 25 rounds left in the old magazine are treated as discarded.

**中文：** AK-47 默认从 `25/90` 换弹后会变成 `30/85`。启用本插件后会变成 `30/60`：旧弹匣剩下的 25 发会被视为丢弃。

## Features / 功能

- **English:** Applies to human players and bots.
- **中文：** 可同时作用于人类玩家和 bot。
- **English:** Deducts reserve ammo instead of directly changing the current clip, so the game’s normal reload animation and timing remain intact.
- **中文：** 通过扣除后备弹药实现，不直接改当前弹匣，因此保留游戏原本的换弹动画和时序。
- **English:** Prevents repeated deductions during the same reload.
- **中文：** 同一次换弹只扣一次，避免重复扣弹。
- **English:** Keeps reserve ammo aligned to full-magazine multiples by default.
- **中文：** 默认让后备弹保持整弹匣倍数，避免出现 `30/15` 这类不自然状态。
- **English:** Excludes shell-by-shell shotguns by default.
- **中文：** 默认排除逐发装填的霰弹枪。

## ConVars / 控制台变量

```cfg
sm_realistic_reload_enable "1"
sm_realistic_reload_humans "1"
sm_realistic_reload_bots "1"
sm_realistic_reload_align_reserve "1"
sm_realistic_reload_exclude_shotguns "1"
```

**English:** A config file is generated at `cfg/sourcemod/realistic_reload.cfg` after the plugin first runs.

**中文：** 插件首次运行后会生成配置文件：`cfg/sourcemod/realistic_reload.cfg`。

## Installation / 安装

**English:**

1. Compile `addons/sourcemod/scripting/realistic_reload.sp`.
2. Copy `realistic_reload.smx` to `addons/sourcemod/plugins/`.
3. Restart the server, change map, or run `sm plugins load realistic_reload`.

**中文：**

1. 编译 `addons/sourcemod/scripting/realistic_reload.sp`。
2. 将 `realistic_reload.smx` 放入 `addons/sourcemod/plugins/`。
3. 重启服务器、换图，或执行 `sm plugins load realistic_reload`。

## Build / 编译

**English:** If you have a local SourceMod scripting directory, you can compile with:

**中文：** 如果你本地有 SourceMod 的 `scripting` 目录，可以用以下命令编译：

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

Or set:

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

## Notes / 注意事项

- **English:** Designed for CS:GO. CS2 is not supported by SourceMod in the same way.
- **中文：** 本插件面向 CS:GO。CS2 并不以相同方式支持 SourceMod。
- **English:** Shotguns are excluded by default because they reload shell by shell, not by replacing a full magazine.
- **中文：** 霰弹枪默认排除，因为它们是逐发装填，不是整弹匣替换。

## License / 许可证

MIT
