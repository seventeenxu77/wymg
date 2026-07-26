# 游戏脚本结构

`main.gd` 是场景入口和协调器，只负责生命周期、输入分发、固定帧更新以及系统调度。

逻辑层位于 `systems/`，按依赖方向排列：

1. `game_state_base.gd`：共享配置、运行状态和系统接口基底。
2. `room_system.gd`：房间生成、家具耐久度、基础实体与查询。
3. `audio_system.gd`：噪音事件、音效资源和脚步播放。
4. `round_system.gd`：四局流程、结算、商店、仓库和 GM 命令。
5. `actor_system.gd`：连续移动、碰撞、家具撞击、攻击和撤离。
6. `tool_system.gd`：道具拾取、使用、装置及状态效果。

高耦合逻辑通过 `GameStateBase` 共享同一份状态，各系统不复制运行数据。

显示层位于 `presentation/`：

- `game_hud.gd`：所有 2D HUD、分屏面板、地图、商店、结算和 GM 控制台。
- `world_25d.gd`：3D 房间、角色、家具、摄像机和角色移动小跳。

显示层只读取逻辑状态并回写点击区域，不负责修改玩法流程。
