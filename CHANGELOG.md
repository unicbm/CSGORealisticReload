# Changelog / 更新日志

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
