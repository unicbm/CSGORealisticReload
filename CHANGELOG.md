# Changelog / 更新日志

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
