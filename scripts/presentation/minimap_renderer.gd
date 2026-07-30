@tool
class_name MinimapRenderer
extends RefCounted

# Draws the gameplay minimap through the owning GameHud CanvasItem.
# Keeping the host as Variant preserves the current presentation API while
# isolating the page-specific drawing code from the main HUD coordinator.


static func draw(hud: Variant, rect: Rect2, role: String) -> void:
	var angle: float = hud._minimap_rotation(role)
	var center := rect.get_center()
	var rotated_bounds_scale := absf(cos(angle)) + absf(sin(angle))
	var grid_side := minf(rect.size.x, rect.size.y) / maxf(rotated_bounds_scale, 1.0)
	var grid_rect := Rect2(center - Vector2.ONE * grid_side / 2.0, Vector2.ONE * grid_side)
	var gap := 3.0
	var cell: float = (grid_side - gap * (hud.MAP_SIZE - 1)) / hud.MAP_SIZE
	var actor: Dictionary = hud._get_actor(role)
	var accent: Color = hud.MONSTER_COLOR if role == "monster" else hud.THIEF_COLOR

	for room in hud.rooms:
		var coord: Vector2i = room["coord"]
		var owned_robot: Dictionary = hud._owned_robot_in_room(coord, role)
		var cell_rect := Rect2(
			grid_rect.position + Vector2(coord.x, coord.y) * (cell + gap),
			Vector2(cell, cell)
		)
		var has_actor: bool = actor["room"] == coord
		var fill: Color = accent.darkened(0.2) if has_actor else Color("#252824")
		if (
			not owned_robot.is_empty()
			and hud.elapsed < float(owned_robot.get("alert_until", 0.0))
		):
			var pulse: float = 0.55 + sin(hud.elapsed * 12.0) * 0.2
			fill = Color("#db4f3f").lerp(Color("#f0b05e"), pulse)
		var corners := PackedVector2Array([
			hud._rotate_minimap_point(cell_rect.position, center, angle),
			hud._rotate_minimap_point(
				Vector2(cell_rect.end.x, cell_rect.position.y),
				center,
				angle,
			),
			hud._rotate_minimap_point(cell_rect.end, center, angle),
			hud._rotate_minimap_point(
				Vector2(cell_rect.position.x, cell_rect.end.y),
				center,
				angle,
			),
		])
		hud.draw_colored_polygon(corners, fill)
		for corner_index in range(corners.size()):
			hud.draw_line(
				corners[corner_index],
				corners[(corner_index + 1) % corners.size()],
				Color("#4b5048"),
				1,
			)
		_draw_room_doors(hud, room, cell_rect, center, angle, cell)
		if has_actor:
			var marker_center: Vector2 = hud._rotate_minimap_point(
				cell_rect.get_center(),
				center,
				angle,
			)
			hud.draw_circle(marker_center, maxf(cell * 0.18, 3.5), accent)
			hud.draw_circle(
				marker_center,
				maxf(cell * 0.18, 3.5),
				Color("#111311"),
				false,
				1.0,
			)
		_draw_robot_marker(hud, owned_robot, cell_rect, center, angle, cell)
		if role == "monster":
			_draw_treasure_markers(hud, room, cell_rect, center, angle, cell)

	_draw_enemy_decoys(hud, role, grid_rect, center, angle, cell, gap)


static func _draw_room_doors(
	hud: Variant,
	room: Dictionary,
	cell_rect: Rect2,
	center: Vector2,
	angle: float,
	cell: float
) -> void:
	var door_length := cell * 0.32
	for door in room["doors"]:
		var door_from := Vector2.ZERO
		var door_to := Vector2.ZERO
		match door:
			"up":
				door_from = Vector2(cell_rect.get_center().x - door_length / 2, cell_rect.position.y)
				door_to = Vector2(cell_rect.get_center().x + door_length / 2, cell_rect.position.y)
			"down":
				door_from = Vector2(cell_rect.get_center().x - door_length / 2, cell_rect.end.y)
				door_to = Vector2(cell_rect.get_center().x + door_length / 2, cell_rect.end.y)
			"left":
				door_from = Vector2(cell_rect.position.x, cell_rect.get_center().y - door_length / 2)
				door_to = Vector2(cell_rect.position.x, cell_rect.get_center().y + door_length / 2)
			"right":
				door_from = Vector2(cell_rect.end.x, cell_rect.get_center().y - door_length / 2)
				door_to = Vector2(cell_rect.end.x, cell_rect.get_center().y + door_length / 2)
		hud.draw_line(
			hud._rotate_minimap_point(door_from, center, angle),
			hud._rotate_minimap_point(door_to, center, angle),
			hud.TEXT_COLOR,
			2,
		)


static func _draw_robot_marker(
	hud: Variant,
	robot: Dictionary,
	cell_rect: Rect2,
	center: Vector2,
	angle: float,
	cell: float
) -> void:
	if robot.is_empty():
		return
	var robot_center: Vector2 = hud._rotate_minimap_point(
		cell_rect.get_center() + Vector2(-cell * 0.22, cell * 0.22),
		center,
		angle,
	)
	var robot_color := (
		Color("#6d716b")
		if hud.elapsed < float(robot.get("stunned_until", 0.0))
		else Color("#8fd0a4")
	)
	hud.draw_circle(robot_center, maxf(cell * 0.1, 2.5), robot_color)
	hud.draw_circle(
		robot_center,
		maxf(cell * 0.1, 2.5),
		Color("#111311"),
		false,
		1.0,
	)


static func _draw_treasure_markers(
	hud: Variant,
	room: Dictionary,
	cell_rect: Rect2,
	center: Vector2,
	angle: float,
	cell: float
) -> void:
	for marker in hud._monster_treasure_markers(room):
		var local_pos: Vector2 = marker["pos"]
		var marker_center: Vector2 = cell_rect.position + local_pos / hud.ROOM_SIZE * cell_rect.size
		marker_center = hud._rotate_minimap_point(marker_center, center, angle)
		var marker_size := clampf(cell * 0.38, 8.0, 14.0)
		var marker_rect := Rect2(
			marker_center - Vector2.ONE * marker_size * 0.5,
			Vector2.ONE * marker_size,
		)
		hud.draw_rect(marker_rect.grow(1.5), Color("#111311"))
		hud._draw_treasure_icon(str(marker["id"]), marker_rect)
		hud.draw_rect(marker_rect.grow(1.5), hud.GOLD_COLOR, false, 1.0)


static func _draw_enemy_decoys(
	hud: Variant,
	role: String,
	grid_rect: Rect2,
	center: Vector2,
	angle: float,
	cell: float,
	gap: float
) -> void:
	for room in hud.rooms:
		for item in room["items"]:
			if (
				bool(item.get("collected", false))
				or str(item.get("device_type", "")) != "decoy"
				or str(item.get("owner", "")) == role
			):
				continue
			var decoy_coord: Vector2i = room["coord"]
			var decoy_center: Vector2 = (
				grid_rect.position
				+ Vector2(decoy_coord.x, decoy_coord.y) * (cell + gap)
				+ Vector2.ONE * cell * 0.5
			)
			decoy_center = hud._rotate_minimap_point(decoy_center, center, angle)
			var decoy_color: Color = (
				hud.THIEF_COLOR
				if str(item.get("owner", "")) == "thief"
				else hud.MONSTER_COLOR
			)
			hud.draw_circle(decoy_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), decoy_color)
			hud.draw_circle(
				decoy_center + Vector2(2, -2),
				maxf(cell * 0.14, 3.0),
				Color("#111311"),
				false,
				1.0,
			)
