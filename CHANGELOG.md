# Changelog / 更新日志

## 1.0.4

- Preserve official weapon reserve tables while respecting servers that raise a weapon's actual reserve ammo above the built-in value.
- 保留官方武器备弹表；当服务器把实际备弹调高到内置值以上时，按观测到的实际备弹节奏对齐。
- Fix custom TEC-9 setups such as `18/120` being collapsed to the official `18/90` cadence after the first early reload.
- 修复自定义 TEC-9 `18/120` 这类配置在第一次提前换弹后被压回官方 `18/90` 节奏的问题。

## 1.0.3

- Fix interrupted reloads so weapon switches before completion no longer lose reserve ammo.
- 修复换弹中途切枪时错误扣除备弹的问题，未完成换弹不再造成备弹丢失。
- Add opt-in reload timing diagnostics with `sm_realistic_reload_debug`.
- 新增 `sm_realistic_reload_debug` 可选换弹时序诊断日志。

## 1.0.2

- Treat MAG-7 as a magazine-fed weapon instead of excluding it with shell-by-shell shotguns.
- 将 MAG-7 按多发弹匣武器处理，不再和逐发装填霰弹枪一起排除。
- Refresh README and add Codex agent guidance plus GitHub About copy.
- 精简 README，并补充 Codex agent 指引和 GitHub About 文案。

## 1.0.1

- Preserve each weapon's default reserve cadence when aligning reserve ammo, fixing FAMAS/Galil-style reserve sequences such as FAMAS `90 -> 65 -> 40 -> 15 -> 0`.
- 对齐后备弹时保留每把武器默认备弹节奏，修复 FAMAS/Galil 这类序列，例如 FAMAS `90 -> 65 -> 40 -> 15 -> 0`。
- Prefer item definition index for weapons whose classname is ambiguous, such as USP-S appearing as `weapon_hkp2000`.
- 对 classname 有歧义的武器优先使用 item definition index，例如 USP-S 显示为 `weapon_hkp2000` 的情况。
- Apply the final partial magazine directly so cases like Galil `1/20` become `20/0` instead of inheriting the old clip.
- 最后一匣非满弹匣时直接应用结果，避免 Galil `1/20` 这类情况继承旧弹匣变成错误数值。
- Remove temporary reload debug logging from the release build.
- 从发布版本移除临时换弹 debug 日志。

## 1.0.0-debug1

- Rebased on `1.0.0` behavior and added console debug logging for reload diagnosis.
- 基于 `1.0.0` 行为添加控制台 debug 日志，用于排查换弹参数来源。
- Logs clip, reload state, weapon reserve props, player ammo pool, ammo type, weapon classname, def index, and plugin apply decisions.
- 记录弹匣、换弹状态、武器 reserve prop、玩家 ammo pool、ammo type、武器 classname、def index，以及插件是否执行扣弹。

## 1.0.0

- Initial standalone release.
- 初始独立版本。
- Adds realistic magazine discard behavior by deducting reserve ammo during reload.
- 通过换弹时扣除后备弹药，实现拟真的“丢弃旧弹匣”效果。
