有几个问题：
1.两个房间之间门的连接需要连续，也就是房间之间是紧贴着的，目前我看到了两个门室友之间有明显的沟壑。
2.当角色在房间里面的时候，周围的房间都应该不显示，呈现黑色，只有当前房间内显示。
3.目前的房间太小了，至少应该是现在的两倍才对。
4.速度变成现在的两倍。
5.支持转动视角，比如按qe是逆时针顺时针转动45度。（已实现：Q/E 逆时针/顺时针旋转怪物视角45°，Num7/9 旋转盗贼视角）

## 2026-07-26 远距离房间幽灵可见性（像素级距离渐变shader版）

- 新增 `LAYER_MONSTER_GHOST(128)` 和 `LAYER_THIEF_GHOST(256)` 视觉层
- 每个房间自动生成两套简化幽灵几何体（灰色地板+墙壁+门柱），不含家具/物品
- **仅显示曼哈顿距离=1的相邻房间**幽灵，更远的房间完全不可见
- **使用自定义空间shader实现像素级距离渐变透明度**：每个像素根据世界空间距离玩家位置计算alpha
  - `fade_start=4.0, fade_end=14.0`：靠近玩家的像素完全不透明（上限0.55），远离的像素平滑过渡到完全透明
  - 通过 `varying world_vertex` 在vertex shader中计算世界坐标，fragment shader中计算距离
  - `render_mode unshaded, blend_mix, cull_disabled`
- 每个玩家的shader独立（monster_ghost_shader / thief_ghost_shader），共用同一个Shader实例
- 每帧更新shader的 `player_position` uniform 为玩家的精确3D世界坐标
- 当前房间的幽灵自动隐藏（由真实房间渲染替代）
- 新增函数：`_create_ghost_materials()`（shader版）, `_create_ghost_room()`, `_add_ghost_wall_piece()`, `_sync_ghost_visibility()`, `_manhattan_distance()`