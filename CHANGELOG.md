# Changelog / 更新日志

## 1.0.5

- Discard the current clip immediately after CS:GO confirms reload start, preventing the HUD from showing vanilla ammo first and jumping later.
- 在 CS:GO 确认换弹开始后立刻丢弃当前弹匣，避免 HUD 先显示原版弹药再后跳。
- Clear reload state and refill carried primary/secondary weapons on new round/spawn to prevent previous-round low ammo from leaking into the next round.
- 新回合/出生时清理换弹状态，并补满保留的主武器/手枪，避免上回合低弹药带入下一回合。

## 1.0.4

- Replace reserve pre-deduction with a two-stage correction: record the expected final ammo when reload starts, then apply it only after CS:GO actually increases the clip.
- 将“预先扣 reserve”改成两阶段校正：换弹开始时记录期望结果，只有 CS:GO 确实增加弹匣后才写入最终弹药。
- Fix low-reserve detachable magazine cases such as FAMAS `19/15 -> 15/0`, FAMAS `9/15 -> 15/0`, and AWP `4/5 -> 5/0`.
- 修复低后备弹场景，例如 FAMAS `19/15 -> 15/0`、FAMAS `9/15 -> 15/0`、AWP `4/5 -> 5/0`。

## 1.0.3

- Restore reserve detection by considering both weapon reserve props and the player's ammo pool instead of trusting a single source.
- 同时读取武器 reserve prop 和玩家 ammo pool，避免单一来源为 0 时导致功能整体跳过。
- Harden partial-final-magazine correction so the reserve is forced to zero only after the game actually completes the reload.
- 加固最后一个不完整弹匣的修正逻辑，只在游戏确实完成换弹后才把后备弹压到 0。

## 1.0.2

- Use the player's authoritative ammo pool before weapon reserve props, fixing cases where CS:GO ignored the reserve deduction.
- 优先读写玩家真实后备弹药池，而不是武器实体上的 reserve prop，修复 CS:GO 忽略扣弹的问题。
- Correct final partial magazines after reload, such as FAMAS `1/15 -> 15/0`.
- 修正最后一个不完整弹匣的换弹结果，例如 FAMAS `1/15 -> 15/0`。

## 1.0.1

- Fix reserve alignment for weapons whose default reserve is not a clip-size multiple, such as FAMAS `25/90`.
- 修复 FAMAS `25/90` 这类默认备弹不是弹匣容量整数倍的武器的后备弹对齐逻辑。
- Fix low-reserve partial reloads such as AWP `4/5 -> 5/0`.
- 修复 AWP `4/5 -> 5/0` 这类低后备弹提前换弹场景。

## 1.0.0

- Initial standalone release.
- 初始独立版本。
- Adds realistic magazine discard behavior by deducting reserve ammo during reload.
- 通过换弹时扣除后备弹药，实现拟真的“丢弃旧弹匣”效果。
