class_name MansionCollision
extends RefCounted

const WORLD_25D_SCRIPT := preload("res://scripts/world_25d.gd")

const ROOM_SIZE := 5.0
const ACTOR_COLLISION_RADIUS := 0.25
const MONSTER_COLLISION_RADIUS := (
	576.0 * 0.00263 * 0.5 / WORLD_25D_SCRIPT.CELL_SIZE
)
const THIEF_COLLISION_RADIUS := (
	384.0 * 0.00270 * 0.5 / WORLD_25D_SCRIPT.CELL_SIZE
)


static func actor_radius(role: String) -> float:
	return MONSTER_COLLISION_RADIUS if role == "monster" else THIEF_COLLISION_RADIUS


static func position_clears_room_walls(
	room: Dictionary,
	position: Vector2,
	role := "",
) -> bool:
	var doors: Array = room["doors"]
	var collision_radius := (
		ACTOR_COLLISION_RADIUS
		if role.is_empty()
		else actor_radius(role)
	)
	var door_center_limit := (
		WORLD_25D_SCRIPT.DOOR_GAP / (2.0 * WORLD_25D_SCRIPT.CELL_SIZE)
		- collision_radius
	)
	if position.x < collision_radius:
		if not doors.has("left") or absf(position.y - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if position.x > ROOM_SIZE - collision_radius:
		if not doors.has("right") or absf(position.y - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if position.y < collision_radius:
		if not doors.has("up") or absf(position.x - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if position.y > ROOM_SIZE - collision_radius:
		if not doors.has("down") or absf(position.x - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	return true


static func actor_overlaps_furniture(
	actor_position: Vector2,
	furniture: Dictionary,
	role := "",
) -> bool:
	var half_extents := furniture_half_extents(str(furniture["kind"]))
	var collision_radius := (
		ACTOR_COLLISION_RADIUS
		if role.is_empty()
		else actor_radius(role)
	)
	var local_position := (
		actor_position - (furniture["pos"] as Vector2)
	).rotated(-deg_to_rad(float(furniture["rotation"])))
	var closest := Vector2(
		clampf(local_position.x, -half_extents.x, half_extents.x),
		clampf(local_position.y, -half_extents.y, half_extents.y),
	)
	return local_position.distance_squared_to(closest) < collision_radius * collision_radius


static func furniture_half_extents(kind: String) -> Vector2:
	var world_size: Vector2
	match kind:
		"床": world_size = Vector2(1.74, 0.87)
		"衣柜": world_size = Vector2(0.87, 0.87)
		"书柜": world_size = Vector2(1.0, 0.87)
		"木桶": world_size = Vector2(0.5, 0.5)
		"木箱": world_size = Vector2(0.6, 0.6)
		"花瓶": world_size = Vector2(0.28, 0.28)
		_: world_size = Vector2(0.6, 0.6)
	return world_size / WORLD_25D_SCRIPT.CELL_SIZE * 0.5
