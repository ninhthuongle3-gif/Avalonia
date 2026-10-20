# 第一阶段：3D 跨肩射击靶场

> 本文记录 v0.1。当前 v0.2 已更改自由/瞄准操作并加入丧尸 AI，请先阅读 [v0.2 说明](phase-two.md)。

## 运行与范围

当前仓库实际使用 Godot，因此第一阶段沿用 Godot 4.6.3，而不是另起 Unreal 项目。场景入口是 `scenes/range.tscn`。原有 `main.tscn` 和 2D 脚本保持兼容。

工作目录：`/workspace/Avalonia`。执行 `./run.sh`，按 Enter 开始。需要图形显示；在无图形环境中使用逻辑测试。没有服务器、密钥、第三方包或运行时网络依赖。首次运行由 `run.sh` 导入资源；`.godot/` 为可再生缓存。

## 玩法与验收

1. 移动、冲刺、跳跃；人物应被混凝土掩体和货柜挡住。
2. 右键瞄准；Q 换肩；靠近墙壁观察镜头收缩，沿侧墙换肩时不应穿墙。
3. 瞄准橙色靶标，左键射击；检查枪口火焰、声音、命中标记、后坐力和弹药消耗。
4. 比较站在掩体后射击靶标躯干与头部：枪口受阻时不得伤害被遮挡部位。曳光止于实际命中位置。
5. R 换弹；备用弹药不足时只装入剩余弹药。冲刺、换弹及暂停期间无法射击。
6. 击倒六个不同靶标，目标栏应显示完成并冻结用时；重复击倒同一靶标不增加独立靶标计数。靶标在 2.5 秒后自动复位。
7. T 重新训练；Esc 暂停并释放鼠标，Enter/Esc 恢复，切换到其他应用时自动暂停。

## 自动验证

```sh
./run.sh --headless --editor --import --quit
./run.sh --headless --script tests/tps_test.gd
./run.sh --headless --script tests/combat_test.gd
./run.sh --headless --script tests/input_test.gd
```

`tps_test.gd` 使用真实物理帧、输入事件、角色碰撞体、相机扫掠和射线命中，覆盖完整六靶训练。它会以非零状态报告失败。原有两个测试分别验证 2D 战斗和输入。

本次验证结果：3D 靶场 **41/41**、原有 2D 战斗 **62/62**、原有 2D 输入 **17/17**，共 **120 项通过**；四张 OpenGL 渲染截图均成功生成并检查。自动测试不能替代人工手感验收。

有 OpenGL 显示时可运行：

```sh
./run.sh --rendering-method gl_compatibility --audio-driver Dummy --script tests/tps_visual.gd
```

此脚本将标题、普通视角、右肩瞄准和左肩瞄准四张真实渲染图片保存到忽略的 `artifacts/tps-*.png`。本次云环境通过 Xorg 的 dummy 显示驱动和 Mesa llvmpipe 验证；软件渲染结果不代表目标硬件性能。`docs/tps-range.png`、`docs/tps-aim.png` 为本次渲染样例。

## 结构与可调参数

| 文件 | 职责 |
| --- | --- |
| `scripts/tps/player.gd` | 移动、镜头、武器、射线及占位角色 |
| `scripts/tps/target.gd` | 身体/头部判定、移动、击倒与复位 |
| `scripts/tps/range.gd` | 场景搭建、训练流程、输入绑定和效果 |
| `scripts/tps/hud.gd` | 操作说明、准星、弹药和训练统计 |
| `scripts/tps/geometry.gd` | 共享的程序化几何构建工具 |

移动速度、鼠标灵敏度、视野和后坐力位于 `player.gd`；弹匣、换弹时间、射击间隔分别是 `MAGAZINE`、`RELOAD_TIME`、`FIRE_INTERVAL`。

当前角色用方块和球体组成，武器握持与步态是程序化占位动作。镜头和命中正确性已经纳入自动测试；鼠标手感、视觉舒适度、音量平衡和目标硬件帧率仍需人工试玩评估。第一阶段不含丧尸行为、正式美术或联网功能。
