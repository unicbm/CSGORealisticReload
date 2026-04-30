# CSGO Realistic Reload / CS:GO 拟真换弹

![SourceMod](https://img.shields.io/badge/SourceMod-1.10%2B-blue)
![Game](https://img.shields.io/badge/Game-CS%3AGO-orange)
![License](https://img.shields.io/badge/License-MIT-green)

Make reloads matter. / 让每一次换弹都值得考虑。

CSGO Realistic Reload is a small SourceMod plugin that makes partial reloads behave like discarded magazines. If a player reloads before emptying the magazine, the remaining rounds are treated as thrown away by deducting reserve ammo.

CSGO Realistic Reload 是一个轻量 SourceMod 插件，用来实现更拟真的“丢弃弹匣式换弹”。如果玩家在弹匣没打空时换弹，旧弹匣里剩下的子弹会从后备弹药中扣除。

This keeps CS:GO's original reload animation and timing intact. The plugin does not force the clip to zero; it adjusts reserve ammo at the right moment so the final HUD result feels natural.

插件会保留 CS:GO 原本的换弹动画和时序。它不会强行把当前弹匣清零，而是在合适时机扣除后备弹药，让最终 HUD 结果看起来和真实丢弃弹匣一致。

## Quick Example / 快速示例

Default CS:GO behavior:

```text
AK-47: 25 / 90  -> reload -> 30 / 85
```

With this plugin:

```text
AK-47: 25 / 90  -> reload -> 30 / 60
```

Why? The 25 rounds left in the old magazine are discarded. The weapon still loads 5 rounds normally, so reserve ammo loses `25 + 5 = 30`.

原因：旧弹匣里剩下的 25 发被视为丢弃；游戏仍然正常补入 5 发，所以后备弹总共减少 `25 + 5 = 30`。

## Highlights / 特性

- Works for human players and bots.
- 对人类玩家和 bot 都生效。

- Deducts reserve ammo instead of directly rewriting the current clip.
- 通过扣后备弹实现，不直接硬改当前弹匣。

- Prevents repeated deductions during the same reload.
- 同一次换弹只扣一次，避免重复扣弹。

- Keeps reserve ammo aligned to each weapon's default reserve cadence by default.
- 默认让后备弹按每把武器的默认备弹节奏对齐，避免 AK 出现 `30/15` 这类不自然状态，同时保留 FAMAS `90 -> 65 -> 40 -> 15 -> 0` 这种原版节奏。

- Excludes shell-by-shell shotguns by default.
- 默认排除逐发装填霰弹枪。

- No gamedata, detours, DHooks, or eItems dependency.
- 不需要 gamedata、detour、DHooks 或 eItems 依赖。

## Install / 安装

1. Compile `addons/sourcemod/scripting/realistic_reload.sp`.
2. Copy `realistic_reload.smx` to your server:

```text
addons/sourcemod/plugins/realistic_reload.smx
```

3. Restart the server, change map, or load it manually:

```text
sm plugins load realistic_reload
```

中文步骤：

1. 编译 `addons/sourcemod/scripting/realistic_reload.sp`。
2. 将 `realistic_reload.smx` 放到服务器：

```text
addons/sourcemod/plugins/realistic_reload.smx
```

3. 重启服务器、换图，或手动加载：

```text
sm plugins load realistic_reload
```

## Configuration / 配置

The plugin creates this config after first run:

插件首次运行后会生成配置文件：

```text
cfg/sourcemod/realistic_reload.cfg
```

Available ConVars:

可用控制台变量：

```cfg
// Enable or disable the plugin.
// 启用或关闭插件。
sm_realistic_reload_enable "1"

// Apply to human players.
// 对人类玩家生效。
sm_realistic_reload_humans "1"

// Apply to bots.
// 对 bot 生效。
sm_realistic_reload_bots "1"

// Keep reserve ammo aligned to each weapon's default reserve cadence.
// 让后备弹按每把武器的默认备弹节奏对齐。
sm_realistic_reload_align_reserve "1"

// Keep shell-by-shell shotgun reload behavior unchanged.
// 保持逐发装填霰弹枪的原版换弹逻辑。
sm_realistic_reload_exclude_shotguns "1"
```

## Behavior Details / 行为细节

The plugin waits until CS:GO reports that the active weapon is actually reloading. Then it deducts reserve ammo once for that reload. This avoids fighting the game's reload animation or prediction.

插件会等到 CS:GO 确认当前武器已经进入换弹状态，再对这一次换弹扣除一次后备弹。这样不会和游戏原本的换弹动画或预测逻辑冲突。

With reserve alignment enabled, the final reserve ammo is rounded down to the weapon's default reserve cadence whenever possible. For weapons whose default reserve is not a clean multiple of clip size, that remainder is preserved.

启用后备弹对齐时，最终后备弹会尽量向下对齐到该武器的默认备弹节奏。对于默认备弹不是弹匣容量整数倍的武器，会保留这个余数。

```text
AK-47: 25 / 90  -> 30 / 60
Glock: 16 / 120 -> 20 / 100
AK-47: 15 / 45  -> 30 / 0
FAMAS: 0 / 90   -> 25 / 65
AWP:   4 / 5    -> 5 / 0
```

Shotguns are excluded by default because weapons like Nova, MAG-7, Sawed-Off, and XM1014 do not behave like detachable-magazine weapons in gameplay.

霰弹枪默认排除，因为 Nova、MAG-7、Sawed-Off、XM1014 这类武器在玩法上并不是“整弹匣替换”的换弹逻辑。

## Build From Source / 从源码编译

Use the included PowerShell helper if you already have a SourceMod scripting directory:

如果你已经有 SourceMod 的 `scripting` 目录，可以用仓库里的 PowerShell 脚本编译：

```powershell
powershell -ExecutionPolicy Bypass -File tools/compile.ps1 -SourceModScriptingDir "C:\path\to\sourcemod\scripting"
```

Or set an environment variable:

也可以设置环境变量：

```powershell
$env:SM_SCRIPTING_DIR = "C:\path\to\sourcemod\scripting"
powershell -ExecutionPolicy Bypass -File tools/compile.ps1
```

Manual compile:

手动编译：

```powershell
spcomp.exe addons\sourcemod\scripting\realistic_reload.sp -iaddons\sourcemod\scripting\include --output=addons\sourcemod\plugins\realistic_reload.smx
```

## Compatibility / 兼容性

- Designed for CS:GO.
- 面向 CS:GO。

- Requires SourceMod and SDKTools.
- 需要 SourceMod 和 SDKTools。

- CS2 is not supported by SourceMod in the same way.
- CS2 并不以相同方式支持 SourceMod。

## Troubleshooting / 排查

Check the plugin is loaded:

确认插件已经加载：

```text
sm plugins list
```

Reload the plugin:

重新加载插件：

```text
sm plugins reload realistic_reload
```

If reloads still behave like vanilla CS:GO, confirm that `sm_realistic_reload_enable`, `sm_realistic_reload_humans`, and `sm_realistic_reload_bots` are set as expected.

如果换弹仍然和原版 CS:GO 一样，请确认 `sm_realistic_reload_enable`、`sm_realistic_reload_humans`、`sm_realistic_reload_bots` 的值符合预期。

## License / 许可证

MIT
