# Changelog / 更新日志

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
