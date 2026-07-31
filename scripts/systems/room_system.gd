@tool
class_name RoomSystem
extends "res://scripts/systems/game_state_base.gd"

const GAMEPLAY_STATE_FACTORY := preload("res://scripts/state/gameplay_state_factory.gd")


func _make_actor(room: Vector2i, pos: Vector2, dir: String) -> Dictionary:
	return GAMEPLAY_STATE_FACTORY.actor(
		room,
		pos,
		dir,
		_direction_vector(dir),
	)


func _room_index(room_pos: Vector2i) -> int:
	return room_pos.y * MAP_SIZE + room_pos.x


func _room_at(room_pos: Vector2i) -> Dictionary:
	return rooms[_room_index(room_pos)]


func _generate_rooms() -> Array:
	var generated: Array = []
	for y in range(MAP_SIZE):
		for x in range(MAP_SIZE):
			generated.append({
				"coord": Vector2i(x, y),
				"doors": [],
				"furniture": [],
				"items": [],
				"traces": [],
				"strokes": [],
			})

	var start := rng.randi_range(0, generated.size() - 1)
	var visited := {start: true}
	while visited.size() < generated.size():
		var candidates := visited.keys()
		var from_index: int = candidates[rng.randi_range(0, candidates.size() - 1)]
		var from_room: Dictionary = generated[from_index]
		var options: Array = []
		for edge in DIRECTIONS:
			var target: Vector2i = from_room["coord"] + edge["delta"]
			if target.x >= 0 and target.y >= 0 and target.x < MAP_SIZE and target.y < MAP_SIZE:
				var target_index := _room_index(target)
				if not visited.has(target_index):
					options.append(edge)
		if options.is_empty():
			continue
		var chosen: Dictionary = options[rng.randi_range(0, options.size() - 1)]
		var next_coord: Vector2i = from_room["coord"] + chosen["delta"]
		var next_index := _room_index(next_coord)
		from_room["doors"].append(chosen["name"])
		generated[next_index]["doors"].append(chosen["opposite"])
		visited[next_index] = true

	for room in generated:
		for edge in DIRECTIONS:
			var neighbor_coord: Vector2i = room["coord"] + edge["delta"]
			if neighbor_coord.x < 0 or neighbor_coord.y < 0 or neighbor_coord.x >= MAP_SIZE or neighbor_coord.y >= MAP_SIZE:
				continue
			if room["doors"].has(edge["name"]) or rng.randf() > 0.2:
				continue
			room["doors"].append(edge["name"])
			var neighbor: Dictionary = generated[_room_index(neighbor_coord)]
			if not neighbor["doors"].has(edge["opposite"]):
				neighbor["doors"].append(edge["opposite"])

	var kinds := ["床", "衣柜", "书柜", "木桶", "木箱", "花瓶"]
	var floor_textures := WORLD_25D_SCRIPT.FLOOR_TEXTURES
	for room in generated:
		room["floor_texture"] = floor_textures[rng.randi_range(0, floor_textures.size() - 1)]
		var reserved: Array = []
		for door in room["doors"]:
			match door:
				"up": reserved.append(Vector2(2.5, 0.35))
				"right": reserved.append(Vector2(4.65, 2.5))
				"down": reserved.append(Vector2(2.5, 4.65))
				"left": reserved.append(Vector2(0.35, 2.5))
		if room["coord"] == ENTRANCE_ROOM:
			reserved.append(ENTRANCE_POS)
		if room["coord"] == MONSTER_SPAWN_ROOM:
			reserved.append(MONSTER_SPAWN_POS)
		var count := rng.randi_range(1, 3)
		for index in range(count):
			var pos := _empty_position(room, reserved)
			var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
			var contents: Array = []
			if rng.randf() < TRINKET_SPAWN_CHANCE:
				contents.append({
					"id": "trinket-%d-%d-%d" % [room["coord"].x, room["coord"].y, index],
					"kind": "trinket",
					"label": TRINKETS[rng.randi_range(0, TRINKETS.size() - 1)],
					"value": 1,
					"weight": 1,
				})
			var base_durability := _furniture_durability(kind)
			room["furniture"].append({
				"id": "f-%d-%d-%d" % [room["coord"].x, room["coord"].y, index],
				"kind": kind,
				"pos": pos,
				"rotation": float(rng.randi_range(0, 3) * 90),
				"opened": false,
				"destroyed": false,
				"damage": 0,
				"base_durability": base_durability,
				"durability": base_durability + _contents_treasure_value(contents),
				"contents": contents,
				"last_hit_time": -10.0,
			})

	# Place wild common treasures in random furniture
	var all_furniture: Array = []
	for room in generated:
		for furniture in room["furniture"]:
			all_furniture.append(furniture)
	_shuffle_with_rng(all_furniture)
	var wild_placed := 0
	for furniture in all_furniture:
		if wild_placed >= WILD_TREASURE_COUNT:
			break
		if _furniture_has_treasure(furniture):
			continue
		var wild_treasure := WILD_TREASURE.duplicate(true)
		wild_treasure["id"] = "wild-treasure-%d-%d" % [current_round, wild_placed]
		furniture["contents"].append(wild_treasure)
		_refresh_furniture_durability(furniture)
		wild_placed += 1

	var visible_room_keys: Dictionary = {}
	for index in range(PILL_SPAWN_COUNT):
		var room := _random_room_for_visible_item(generated, visible_room_keys)
		var pos := _empty_position(room)
		room["items"].append({
			"id": "pill-%d" % index,
			"kind": "pill",
			"label": "治疗药丸",
			"value": 0,
			"pos": pos,
			"collected": false,
		})
		visible_room_keys[_room_key_for_distribution(room["coord"])] = room["coord"]
	var hidden_furniture: Array = []
	for room in generated:
		for furniture in room["furniture"]:
			hidden_furniture.append(furniture)
	_shuffle_with_rng(hidden_furniture)
	for index in range(mini(HIDDEN_ADRENALINE_COUNT, hidden_furniture.size())):
		var adrenaline := _make_tool_instance("adrenaline", "round-%d-adrenaline-%d" % [current_round, index])
		(hidden_furniture[index] as Dictionary)["contents"].append(adrenaline)
	return generated


func _total_tool_spawn_count() -> int:
	return HIDDEN_ADRENALINE_COUNT


func _room_key_for_distribution(coord: Vector2i) -> String:
	return "%d:%d" % [coord.x, coord.y]


func _random_room_for_visible_item(generated: Array, used_room_keys: Dictionary) -> Dictionary:
	var candidates: Array = []
	for room in generated:
		var coord: Vector2i = room["coord"]
		if used_room_keys.has(_room_key_for_distribution(coord)):
			continue
		var sufficiently_separated := true
		for used_coord in used_room_keys.values():
			var other: Vector2i = used_coord
			if abs(coord.x - other.x) + abs(coord.y - other.y) < 2:
				sufficiently_separated = false
				break
		if sufficiently_separated:
			candidates.append(room)
	if candidates.is_empty():
		for room in generated:
			if not used_room_keys.has(_room_key_for_distribution(room["coord"])):
				candidates.append(room)
	if candidates.is_empty():
		candidates = generated
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _shuffle_with_rng(entries: Array) -> void:
	for index in range(entries.size() - 1, 0, -1):
		var swap_index := rng.randi_range(0, index)
		var temporary = entries[index]
		entries[index] = entries[swap_index]
		entries[swap_index] = temporary


func _furniture_durability(kind: String) -> int:
	match kind:
		"花瓶": return 1
		"木桶": return 2
		"木箱": return 3
		_: return 4


func _contents_treasure_value(contents: Array) -> int:
	var bonus := 0
	for content in contents:
		if str(content.get("kind", "")) in ["treasure", "trinket"]:
			bonus += int(content.get("value", 0))
	return bonus


func _effective_furniture_durability(furniture: Dictionary) -> int:
	if not furniture.has("base_durability"):
		return int(furniture.get("durability", 1))
	var base := int(furniture["base_durability"])
	return base + _contents_treasure_value(furniture.get("contents", []))


func _refresh_furniture_durability(furniture: Dictionary) -> void:
	furniture["durability"] = _effective_furniture_durability(furniture)


func _empty_position(room: Dictionary, reserved: Array = []) -> Vector2:
	for _attempt in range(80):
		var pos := Vector2(
			0.4 + rng.randf() * (ROOM_SIZE - 0.8),
			0.4 + rng.randf() * (ROOM_SIZE - 0.8)
		)
		var occupied := false
		for furniture in room["furniture"]:
			if (furniture["pos"] as Vector2).distance_to(pos) < 0.9:
				occupied = true
		for item in room["items"]:
			if not item["collected"] and (item["pos"] as Vector2).distance_to(pos) < 0.55:
				occupied = true
		for point in reserved:
			if (point as Vector2).distance_to(pos) < 0.72:
				occupied = true
		if not occupied:
			return pos
	return Vector2(2.5, 2.5)


func _get_actor(role: String) -> Dictionary:
	return monster if role == "monster" else thief


func _role_name(role: String) -> String:
	return "怪物" if role == "monster" else "盗贼"


func _fresh_status_effects() -> Dictionary:
	return GAMEPLAY_STATE_FACTORY.status_effects()


func _make_tool_instance(tool_type: String, id: String) -> Dictionary:
	var definition: Dictionary = TOOL_DEFS[tool_type]
	return GAMEPLAY_STATE_FACTORY.tool(
		tool_type,
		id,
		definition,
		DETECTOR_BATTERY_SECONDS,
	)


func _furniture_has_treasure(furniture: Dictionary) -> bool:
	for content in furniture.get("contents", []):
		if str(content.get("kind", "")) == "treasure":
			return true
	return false


func _furniture_has_primary_content(furniture: Dictionary) -> bool:
	for content in furniture.get("contents", []):
		if str(content.get("kind", "")) in ["treasure", "alarm"]:
			return true
	return false


func _find_furniture(room: Dictionary, id: String) -> Dictionary:
	for furniture in room["furniture"]:
		if furniture["id"] == id:
			return furniture
	return {}


func _direction_vector(dir: String) -> Vector2:
	match dir:
		"up": return Vector2.UP
		"right": return Vector2.RIGHT
		"down": return Vector2.DOWN
		_: return Vector2.LEFT
