@tool
extends Node2D

# Native Godot migration of the original web prototype.

const WORLD_25D_SCRIPT := preload("res://scripts/world_25d.gd")
const MAP_SIZE := 6
const ROOM_SIZE := 5.0
const ACTOR_SPEED := 4.0
const FURNITURE_SPEED := 2.0
const ROTATION_SPEED := 90.0
const ROTATION_STEP := 4.0
const ENTRANCE_ROOM := Vector2i(0, 5)
const ENTRANCE_POS := Vector2(0.5, 4.5)
const MONSTER_SPAWN_ROOM := Vector2i(5, 0)
const MONSTER_SPAWN_POS := Vector2(4.5, 0.5)

const MONSTER_COLOR := Color("#ff6b4a")
const THIEF_COLOR := Color("#66d9c3")
const BG_COLOR := Color("#0b0c0c")
const PANEL_COLOR := Color("#171a17")
const PANEL_ALT := Color("#111312")
const LINE_COLOR := Color("#3d413b")
const TEXT_COLOR := Color("#eee9dd")
const MUTED_COLOR := Color("#979c94")
const FLOOR_COLOR := Color("#70756b")
const FLOOR_DARK := Color("#63685f")
const GOLD_COLOR := Color("#e6cc64")
const TRACE_COLOR := Color("#d5c78f")

const DIRECTIONS := [
	{"name": "up", "delta": Vector2i(0, -1), "opposite": "down"},
	{"name": "right", "delta": Vector2i(1, 0), "opposite": "left"},
	{"name": "down", "delta": Vector2i(0, 1), "opposite": "up"},
	{"name": "left", "delta": Vector2i(-1, 0), "opposite": "right"},
]

const TREASURES := [
	{"id": "treasure-2", "label": "银制烛台", "value": 2},
	{"id": "treasure-3", "label": "祖母绿胸针", "value": 3},
	{"id": "treasure-5", "label": "怪物之心", "value": 5},
]

var rng := RandomNumberGenerator.new()
var rooms: Array = []
var monster: Dictionary = {}
var thief: Dictionary = {}
var dragging := {"monster": "", "thief": ""}
var drag_mode := {"monster": "move", "thief": "move"}
var selected_treasure := 0
var loot_value := 0
var pills := 0
var phase := "hide"
var seconds_left := 180
var phase_clock := 0.0
var elapsed := 0.0
var stomach_clock := 15.0
var attack_until := 0.0
var noises: Array = []
var afterimages: Array = []
var last_afterimage_at := -10.0
var outcome := ""
var logs: Array[String] = []
var restart_rect := Rect2()
var early_rect := Rect2()
var result_restart_rect := Rect2()

var font: Font
var world_25d: World25D


func _ready() -> void:
	rng.randomize()
	font = ThemeDB.fallback_font
	world_25d = WORLD_25D_SCRIPT.new()
	world_25d.name = "World25DRenderer"
	add_child(world_25d)
	world_25d.setup(get_viewport().world_3d)
	new_game()
	set_process(true)
	set_process_input(true)


func new_game() -> void:
	rooms = _generate_rooms()
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	selected_treasure = 0
	loot_value = 0
	pills = 0
	phase = "hide"
	seconds_left = 180
	phase_clock = 0.0
	elapsed = 0.0
	stomach_clock = 15.0
	attack_until = 0.0
	noises.clear()
	afterimages.clear()
	last_afterimage_at = -10.0
	outcome = ""
	result_restart_rect = Rect2()
	logs = ["藏宝阶段开始：怪物持有 3 件藏品。"]
	if world_25d:
		world_25d.rebuild(rooms)
		world_25d.sync(rooms, monster, thief, afterimages, dragging, false, elapsed)
	queue_redraw()


func _make_actor(room: Vector2i, pos: Vector2, dir: String) -> Dictionary:
	return {
		"room": room,
		"pos": pos,
		"dir": dir,
		"hp": 2,
	}


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if world_25d:
			world_25d.sync(rooms, monster, thief, afterimages, dragging, false, elapsed)
		queue_redraw()
		return
	elapsed += delta
	_update_phase(delta)
	_update_temporary_events()
	if phase == "hunt":
		stomach_clock -= delta
		if stomach_clock <= 0.0:
			stomach_clock += 15.0
			_add_noise("thief", "肚子叫")
			_push_log("盗贼的肚子叫了，怪物获得 2 秒方向提示。")
	if phase != "ready" and phase != "ended":
		_handle_continuous_input(delta)
	if world_25d:
		world_25d.sync(rooms, monster, thief, afterimages, dragging, elapsed < attack_until, elapsed)
	queue_redraw()


func _update_phase(delta: float) -> void:
	if phase != "hide" and phase != "ready":
		return
	phase_clock += delta
	if phase_clock < 1.0:
		return
	var ticks := int(phase_clock)
	phase_clock -= ticks
	for _tick in range(ticks):
		seconds_left -= 1
		if seconds_left > 0:
			continue
		if phase == "hide":
			_begin_hunt_countdown()
		else:
			_enter_hunt()
		break


func _update_temporary_events() -> void:
	noises = noises.filter(func(entry): return float(entry["expires"]) > elapsed)
	afterimages = afterimages.filter(func(entry): return float(entry["expires"]) > elapsed)


func _handle_continuous_input(delta: float) -> void:
	var mx := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var my := int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	_apply_view_relative_input("monster", Vector2(mx, my), delta)

	var tx := int(Input.is_key_pressed(KEY_RIGHT)) - int(Input.is_key_pressed(KEY_LEFT))
	var ty := int(Input.is_key_pressed(KEY_DOWN)) - int(Input.is_key_pressed(KEY_UP))
	_apply_view_relative_input("thief", Vector2(tx, ty), delta)

	if Input.is_physical_key_pressed(KEY_Z):
		_rotate_furniture("monster", -1, ROTATION_SPEED * delta)
	if Input.is_physical_key_pressed(KEY_C):
		_rotate_furniture("monster", 1, ROTATION_SPEED * delta)
	if Input.is_key_pressed(KEY_KP_4):
		_rotate_furniture("thief", -1, ROTATION_SPEED * delta)
	if Input.is_key_pressed(KEY_KP_6):
		_rotate_furniture("thief", 1, ROTATION_SPEED * delta)


func _apply_view_relative_input(role: String, screen_input: Vector2, delta: float) -> void:
	if screen_input.is_zero_approx():
		return
	if dragging[role] != "" and drag_mode[role] == "rotate":
		if not is_zero_approx(screen_input.x):
			_rotate_furniture(role, signf(screen_input.x), ROTATION_SPEED * delta)
		return
	var world_direction := screen_input.normalized()
	if world_25d:
		world_direction = world_25d.camera_relative_vector(role, screen_input)
	_move_actor_continuous(role, world_direction, delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if restart_rect.has_point(event.position) or result_restart_rect.has_point(event.position):
			new_game()
			return
		if phase == "hide" and early_rect.has_point(event.position):
			_begin_hunt_countdown()
			return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key: Key = event.keycode
	var physical: Key = event.physical_keycode
	if key == KEY_F2:
		new_game()
	elif physical == KEY_H and phase == "hide":
		_begin_hunt_countdown()
	elif physical == KEY_Q:
		if world_25d:
			world_25d.rotate_camera("monster", -1)
	elif physical == KEY_E:
		if world_25d:
			world_25d.rotate_camera("monster", 1)
	elif physical == KEY_G:
		_interact_furniture("monster")
	elif physical == KEY_F:
		_place_treasure()
	elif physical == KEY_R:
		selected_treasure = (selected_treasure + 1) % TREASURES.size()
	elif physical == KEY_SPACE:
		_attack()
	elif physical == KEY_T:
		_toggle_furniture_mode("monster")
	elif key == KEY_KP_0:
		_interact_furniture("thief")
	elif key == KEY_KP_1:
		_thief_search()
	elif key == KEY_KP_2:
		_use_pill()
	elif key == KEY_KP_3:
		_toggle_furniture_mode("thief")
	elif key == KEY_KP_5:
		_thief_exit()
	elif key == KEY_KP_7:
		if world_25d:
			world_25d.rotate_camera("thief", -1)
	elif key == KEY_KP_9:
		if world_25d:
			world_25d.rotate_camera("thief", 1)


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

	var kinds := ["沙发", "柜子", "桌子"]
	for room in generated:
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
			room["furniture"].append({
				"id": "f-%d-%d-%d" % [room["coord"].x, room["coord"].y, index],
				"kind": kinds[rng.randi_range(0, kinds.size() - 1)],
				"pos": pos,
				"rotation": float(rng.randi_range(0, 3) * 90),
			})

	for index in range(5):
		var room: Dictionary = generated[rng.randi_range(0, generated.size() - 1)]
		var pos := _empty_position(room)
		room["items"].append({
			"id": "pill-%d" % index,
			"kind": "pill",
			"label": "治疗药丸",
			"value": 0,
			"pos": pos,
			"collected": false,
		})
	return generated


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


func _push_log(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 5:
		logs.resize(5)


func _add_noise(role: String, label: String, actor_override: Dictionary = {}, throttle := 0.0) -> void:
	if phase != "hunt":
		return
	var actor := actor_override if not actor_override.is_empty() else _get_actor(role)
	if throttle > 0.0:
		for existing in noises:
			if existing["source"] == role and existing["label"] == label and elapsed - float(existing["created"]) < throttle:
				return
	noises.append({
		"source": role,
		"label": label,
		"room": actor["room"],
		"pos": actor["pos"],
		"created": elapsed,
		"expires": elapsed + 2.0,
	})


func _reveal_thief(actor_override: Dictionary = {}) -> void:
	if phase != "hunt" or elapsed - last_afterimage_at < 0.5:
		return
	var actor := actor_override if not actor_override.is_empty() else thief
	last_afterimage_at = elapsed
	afterimages.append({
		"room": actor["room"],
		"pos": actor["pos"],
		"created": elapsed,
		"expires": elapsed + 1.1,
	})


func _begin_hunt_countdown() -> void:
	if phase != "hide":
		return
	phase = "ready"
	seconds_left = 5
	phase_clock = 0.0
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	_push_log("藏宝结束：双方已回到起点，5 秒后正式开始。")


func _enter_hunt() -> void:
	if phase != "ready":
		return
	var unplaced := 0
	for treasure in TREASURES:
		var found := false
		for room in rooms:
			for item in room["items"]:
				if item["id"] == treasure["id"]:
					found = true
		if not found:
			var room: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
			room["items"].append({
				"id": treasure["id"],
				"kind": "treasure",
				"label": treasure["label"],
				"value": treasure["value"],
				"pos": _empty_position(room),
				"collected": false,
			})
			unplaced += 1
	phase = "hunt"
	seconds_left = 0
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	last_afterimage_at = -10.0
	stomach_clock = 15.0
	if unplaced > 0:
		_push_log("搜查开始：%d 件未放置藏品已自动散落。" % unplaced)
	else:
		_push_log("搜查开始：怪物与盗贼已回到各自起点。")


func _move_actor_continuous(role: String, direction: Vector2, delta: float) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if direction.is_zero_approx():
		return
	var speed := FURNITURE_SPEED if dragging[role] != "" else ACTOR_SPEED
	var motion := direction.normalized() * speed * delta
	var subdivisions := maxi(1, int(ceil(motion.length() / 0.05)))
	var step := motion / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(step.x):
			_move_actor_axis(role, Vector2(step.x, 0))
		if not is_zero_approx(step.y):
			_move_actor_axis(role, Vector2(0, step.y))


func _move_actor_axis(role: String, motion: Vector2) -> void:
	var actor := _get_actor(role)
	actor["dir"] = _direction_name(motion)
	var room := _room_at(actor["room"])

	if dragging[role] != "":
		var held := _find_furniture(room, dragging[role])
		if held.is_empty():
			dragging[role] = ""
			return
		var next_furniture: Vector2 = held["pos"] + motion
		var next_actor: Vector2 = actor["pos"] + motion
		var blocked := (
			next_furniture.x < 0.28 or next_furniture.y < 0.28
			or next_furniture.x > ROOM_SIZE - 0.28 or next_furniture.y > ROOM_SIZE - 0.28
			or next_actor.x < 0.0 or next_actor.y < 0.0
			or next_actor.x > ROOM_SIZE or next_actor.y > ROOM_SIZE
		)
		for other in room["furniture"]:
			if other["id"] == held["id"]:
				continue
			if (other["pos"] as Vector2).distance_to(next_furniture) < 0.78 or (other["pos"] as Vector2).distance_to(next_actor) < 0.58:
				blocked = true
		if blocked:
			return
		var before := {"pos": held["pos"], "rotation": held["rotation"]}
		held["pos"] = next_furniture
		_record_furniture_strokes(room, held["id"], before, held)
		actor["pos"] = next_actor
		_add_noise(role, "拖动家具", actor, 0.42)
		if role == "thief":
			_reveal_thief(actor)
		return

	var target_room: Vector2i = actor["room"]
	var target_pos: Vector2 = actor["pos"] + motion
	if target_pos.x < 0.0 or target_pos.x >= ROOM_SIZE or target_pos.y < 0.0 or target_pos.y >= ROOM_SIZE:
		var actor_pos: Vector2 = actor["pos"]
		var room_delta := Vector2i(
			int(signf(motion.x)) if not is_zero_approx(motion.x) else 0,
			int(signf(motion.y)) if not is_zero_approx(motion.y) else 0
		)
		var aligned: bool = abs(actor_pos.y - 2.5) <= 0.72 if room_delta.x != 0 else abs(actor_pos.x - 2.5) <= 0.72
		if not room["doors"].has(actor["dir"]) or not aligned:
			return
		target_room += room_delta
		if target_room.x < 0 or target_room.y < 0 or target_room.x >= MAP_SIZE or target_room.y >= MAP_SIZE:
			return
		if target_pos.x < 0.0: target_pos.x += ROOM_SIZE
		if target_pos.x >= ROOM_SIZE: target_pos.x -= ROOM_SIZE
		if target_pos.y < 0.0: target_pos.y += ROOM_SIZE
		if target_pos.y >= ROOM_SIZE: target_pos.y -= ROOM_SIZE

	var target_room_data := _room_at(target_room)
	for furniture in target_room_data["furniture"]:
		var furniture_pos: Vector2 = furniture["pos"]
		if abs(furniture_pos.x - target_pos.x) < 0.52 and abs(furniture_pos.y - target_pos.y) < 0.52:
			return
	actor["room"] = target_room
	actor["pos"] = target_pos
	if role == "monster":
		_add_noise(role, "怪物脚步", actor, 0.42)
	else:
		_reveal_thief(actor)


func _direction_name(motion: Vector2) -> String:
	if absf(motion.x) > absf(motion.y):
		return "right" if motion.x > 0.0 else "left"
	return "down" if motion.y > 0.0 else "up"


func _find_furniture(room: Dictionary, id: String) -> Dictionary:
	for furniture in room["furniture"]:
		if furniture["id"] == id:
			return furniture
	return {}


func _interact_furniture(role: String) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	if dragging[role] != "":
		dragging[role] = ""
		drag_mode[role] = "move"
		_push_log("%s松开了家具。" % _role_name(role))
		return
	var nearby: Dictionary = {}
	for furniture in room["furniture"]:
		if (furniture["pos"] as Vector2).distance_to(actor["pos"]) <= 1.25:
			nearby = furniture
			break
	room["traces"].append({
		"pos": nearby["pos"] if not nearby.is_empty() else actor["pos"],
		"role": role,
		"kind": "interact",
	})
	_add_noise(role, "操作家具")
	if role == "thief":
		_reveal_thief()
	if nearby.is_empty():
		_push_log("附近没有可以移动的家具。")
	else:
		dragging[role] = nearby["id"]
		drag_mode[role] = "move"
		_push_log("%s抓住了%s。" % [_role_name(role), nearby["kind"]])


func _toggle_furniture_mode(role: String) -> void:
	if dragging[role] == "":
		return
	drag_mode[role] = "rotate" if drag_mode[role] == "move" else "move"
	_push_log("%s切换到%s模式。" % [_role_name(role), "移动" if drag_mode[role] == "move" else "旋转"])


func _rotate_furniture(role: String, direction: float, degrees := ROTATION_STEP) -> void:
	if dragging[role] == "" or drag_mode[role] != "rotate":
		return
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var furniture := _find_furniture(room, dragging[role])
	if furniture.is_empty():
		return
	var before := {"pos": furniture["pos"], "rotation": furniture["rotation"]}
	furniture["rotation"] = fmod(float(furniture["rotation"]) + direction * degrees + 360.0, 360.0)
	_record_furniture_strokes(room, furniture["id"], before, furniture)
	_add_noise(role, "旋转家具", actor, 0.42)
	if role == "thief":
		_reveal_thief(actor)


func _furniture_corners(furniture: Dictionary) -> Array:
	var angle := deg_to_rad(float(furniture["rotation"]))
	var local_points := [
		Vector2(-0.38, -0.26), Vector2(0.38, -0.26),
		Vector2(0.38, 0.26), Vector2(-0.38, 0.26),
	]
	var result: Array = []
	for point in local_points:
		result.append((point as Vector2).rotated(angle) + (furniture["pos"] as Vector2))
	return result


func _record_furniture_strokes(room: Dictionary, furniture_id: String, before: Dictionary, after: Dictionary) -> void:
	var old_corners := _furniture_corners(before)
	var new_corners := _furniture_corners(after)
	for index in range(4):
		room["strokes"].append({
			"furniture_id": furniture_id,
			"from": old_corners[index],
			"to": new_corners[index],
		})


func _place_treasure() -> void:
	if phase != "hide":
		return
	var treasure: Dictionary = TREASURES[selected_treasure]
	for room in rooms:
		for item in room["items"]:
			if item["id"] == treasure["id"]:
				_push_log("%s已经放置过了，请切换藏品。" % treasure["label"])
				return
	var room := _room_at(monster["room"])
	for item in room["items"]:
		if (item["pos"] as Vector2).distance_to(monster["pos"]) < 0.35 and not item["collected"]:
			_push_log("这个位置已经有物品。")
			return
	room["items"].append({
		"id": treasure["id"],
		"kind": "treasure",
		"label": treasure["label"],
		"value": treasure["value"],
		"pos": monster["pos"],
		"collected": false,
	})
	room["traces"].append({"pos": monster["pos"], "role": "monster", "kind": "interact"})
	_push_log("已放置%s（价值 %d）。" % [treasure["label"], treasure["value"]])
	for index in range(TREASURES.size()):
		var candidate: Dictionary = TREASURES[index]
		var found := false
		for candidate_room in rooms:
			for item in candidate_room["items"]:
				if item["id"] == candidate["id"]:
					found = true
		if not found:
			selected_treasure = index
			break


func _thief_search() -> void:
	if phase != "hunt":
		return
	var room := _room_at(thief["room"])
	for item in room["items"]:
		if not item["collected"] and (item["pos"] as Vector2).distance_to(thief["pos"]) <= 0.58:
			item["collected"] = true
			if item["kind"] == "treasure":
				loot_value += int(item["value"])
				_push_log("盗贼取得%s，当前价值 %d。" % [item["label"], loot_value])
			else:
				pills += 1
				_push_log("盗贼捡到一颗治疗药丸。")
			_add_noise("thief", "拾取物品")
			_reveal_thief()
			return
	_push_log("附近没有可以拾取的物品。")


func _thief_exit() -> void:
	if phase != "hunt":
		return
	if thief["room"] == ENTRANCE_ROOM and (thief["pos"] as Vector2).distance_to(ENTRANCE_POS) <= 0.58:
		phase = "ended"
		if loot_value >= 5:
			outcome = "盗贼成功撤离，带出价值 %d 的藏品。" % loot_value
		else:
			outcome = "盗贼仓促撤离，价值只有 %d，行动失败。" % loot_value
	else:
		_push_log("只有回到入口处才能撤离。")


func _use_pill() -> void:
	if phase != "hunt" or pills <= 0 or int(thief["hp"]) >= 2:
		return
	thief["hp"] += 1
	pills -= 1
	_add_noise("thief", "使用药丸")
	_reveal_thief()
	_push_log("盗贼回复了 1 滴血。")


func _attack() -> void:
	if phase != "hunt" or elapsed < attack_until:
		return
	attack_until = elapsed + 0.7
	_add_noise("monster", "挥砍")
	var same_room: bool = monster["room"] == thief["room"]
	var vector: Vector2 = thief["pos"] - monster["pos"]
	var distance := vector.length()
	var facing := _direction_vector(monster["dir"])
	var dot := 1.0 if distance == 0.0 else vector.normalized().dot(facing)
	if same_room and distance <= 2.35 and dot >= cos(PI / 4.0):
		thief["hp"] -= 1
		_reveal_thief()
		if thief["hp"] <= 0:
			phase = "ended"
			outcome = "怪物砍倒了盗贼，守住了老宅。"
		else:
			_push_log("挥砍命中！盗贼失去 1 滴血。")
	else:
		_push_log("怪物挥砍落空。")


func _direction_vector(dir: String) -> Vector2:
	match dir:
		"up": return Vector2.UP
		"right": return Vector2.RIGHT
		"down": return Vector2.DOWN
		_: return Vector2.LEFT


func _draw() -> void:
	var size := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR)
	_draw_topbar(size)
	var layout := _calculate_layout(size)
	_draw_room_panel(layout["monster_panel"], layout["monster_room"], "monster")
	_draw_center_rail(layout["center"])
	_draw_room_panel(layout["thief_panel"], layout["thief_room"], "thief")
	if phase == "ready":
		_draw_countdown_overlay(size)
	elif phase == "ended":
		_draw_result_overlay(size)


func _calculate_layout(size: Vector2) -> Dictionary:
	var body_top: float = 146.0
	var margin: float = 18.0
	var gap: float = 14.0
	var center_width: float = clampf(size.x * 0.14, 205.0, 230.0)
	var side_width: float = (size.x - margin * 2.0 - center_width - gap * 2.0) / 2.0
	var panel_height: float = size.y - body_top - 18.0
	var room_side: float = minf(side_width - 34.0, panel_height - 132.0)
	room_side = maxf(room_side, 280.0)
	var left_panel := Rect2(margin, body_top, side_width, panel_height)
	var center := Rect2(margin + side_width + gap, body_top, center_width, panel_height)
	var right_panel := Rect2(center.end.x + gap, body_top, side_width, panel_height)
	var left_room := Rect2(
		left_panel.position.x + (side_width - room_side) / 2.0,
		body_top + 58.0,
		room_side,
		room_side
	)
	var right_room := Rect2(
		right_panel.position.x + (side_width - room_side) / 2.0,
		body_top + 58.0,
		room_side,
		room_side
	)
	return {
		"monster_panel": left_panel,
		"monster_room": left_room,
		"center": center,
		"thief_panel": right_panel,
		"thief_room": right_room,
	}


func _draw_topbar(size: Vector2) -> void:
	draw_rect(Rect2(0, 0, size.x, 76), Color("#0d0f0e"))
	draw_line(Vector2(0, 76), Vector2(size.x, 76), LINE_COLOR, 1)
	draw_rect(Rect2(24, 16, 56, 42), Color.TRANSPARENT, false, 1.5)
	_text("WB-01", Vector2(34, 42), 11, MUTED_COLOR)
	_text("老宅窃影", Vector2(96, 36), 24, TEXT_COLOR)
	_text("双视角 2.5D 纸片宅邸 · 随机 36 房间", Vector2(96, 57), 12, MUTED_COLOR)

	var phase_title := ""
	match phase:
		"hide": phase_title = "怪物藏宝  %d:%02d" % [seconds_left / 60, seconds_left % 60]
		"ready": phase_title = "双方准备  %d" % seconds_left
		"hunt": phase_title = "实时搜查"
		_: phase_title = "本局结束"
	_text("当前阶段", Vector2(size.x * 0.5 - 58, 29), 10, MUTED_COLOR)
	_text(phase_title, Vector2(size.x * 0.5 - 58, 51), 16, TEXT_COLOR)

	restart_rect = Rect2(size.x - 172, 19, 148, 38)
	_draw_button(restart_rect, "重新生成一局")
	early_rect = Rect2(size.x - 355, 19, 170, 38) if phase == "hide" else Rect2()
	if phase == "hide":
		_draw_button(early_rect, "提前结束藏宝", true)

	draw_rect(Rect2(0, 77, size.x, 55), PANEL_ALT)
	draw_line(Vector2(0, 132), Vector2(size.x, 132), LINE_COLOR, 1)
	var stats := [
		["怪物生命", "♥ ♥", MONSTER_COLOR],
		["已放置藏品", "%d / 3" % _placed_treasure_count(), TEXT_COLOR],
		["当前藏品", "%s · %d" % [TREASURES[selected_treasure]["label"], TREASURES[selected_treasure]["value"]], GOLD_COLOR],
		["盗贼生命", _health_text(int(thief["hp"])), THIEF_COLOR],
		["盗取价值 / 门槛", "%d / 5" % loot_value, TEXT_COLOR],
		["治疗药丸", str(pills), TEXT_COLOR],
	]
	var total_width: float = minf(size.x - 80.0, 1080.0)
	var start_x: float = (size.x - total_width) / 2.0
	var stat_width: float = total_width / float(stats.size())
	for index in range(stats.size()):
		var x: float = start_x + index * stat_width
		if index > 0:
			draw_line(Vector2(x, 85), Vector2(x, 124), Color("#30332f"), 1)
		_text(stats[index][0], Vector2(x + 14, 100), 10, MUTED_COLOR)
		_text(stats[index][1], Vector2(x + 14, 120), 14, stats[index][2])


func _placed_treasure_count() -> int:
	var count := 0
	for treasure in TREASURES:
		for room in rooms:
			for item in room["items"]:
				if item["id"] == treasure["id"]:
					count += 1
	return count


func _health_text(value: int) -> String:
	return "♥ ".repeat(max(value, 0)) + "♡ ".repeat(max(2 - value, 0))


func _draw_button(rect: Rect2, label: String, secondary := false) -> void:
	var fill := Color("#262a26") if secondary else Color("#d9d3c5")
	var color := TEXT_COLOR if secondary else Color("#171917")
	draw_rect(rect, fill)
	draw_rect(rect, Color("#777d73"), false, 1)
	_text_center(label, rect, 12, color)


func _draw_room_panel(panel: Rect2, room_rect: Rect2, role: String) -> void:
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	draw_rect(panel, PANEL_COLOR)
	draw_rect(panel, LINE_COLOR, false, 1)
	draw_line(panel.position, Vector2(panel.end.x, panel.position.y), accent, 3)
	_text("怪物视角" if role == "monster" else "盗贼视角", panel.position + Vector2(14, 21), 10, MUTED_COLOR)
	_text("房间 %d-%d" % [actor["room"].x + 1, actor["room"].y + 1], panel.position + Vector2(14, 44), 17, TEXT_COLOR)
	var door_text := "门型 %d · %s" % [room["doors"].size(), _door_label(room["doors"])]
	_text_right(door_text, Vector2(panel.end.x - 14, panel.position.y + 29), 11, MUTED_COLOR)
	if dragging[role] != "":
		_text_right("移动模式" if drag_mode[role] == "move" else "中心旋转模式", Vector2(panel.end.x - 14, panel.position.y + 47), 10, GOLD_COLOR)

	_draw_room(room_rect, role, room, actor)
	var footer := Rect2(panel.position.x, room_rect.end.y + 10, panel.size.x, panel.end.y - room_rect.end.y - 10)
	draw_rect(footer, PANEL_ALT)
	draw_line(footer.position, Vector2(footer.end.x, footer.position.y), LINE_COLOR, 1)
	var controls := ""
	if role == "monster":
		controls = "WASD 移动   G 家具   F 放藏品   R 切换\n空格 挥砍   T 模式   Z/C 家具旋转   Q/E 视角旋转"
	else:
		controls = "方向键 移动   Num0 家具   Num1 搜查   Num7/9 视角旋转\nNum2 药丸   Num3 模式   Num4/6 家具旋转   Num5 撤离"
	_multiline(controls, footer.position + Vector2(12, 22), footer.size.x - 24, 11, MUTED_COLOR, 19)


func _door_label(doors: Array) -> String:
	var result: Array[String] = []
	for door in doors:
		match door:
			"up": result.append("上")
			"right": result.append("右")
			"down": result.append("下")
			"left": result.append("左")
	return " · ".join(result)


func _draw_room(rect: Rect2, role: String, room: Dictionary, actor: Dictionary) -> void:
	draw_rect(rect.grow(7), Color("#252620"))
	if world_25d:
		var view_texture: Texture2D = world_25d.texture_for(role)
		draw_texture_rect(view_texture, rect, false)
	else:
		draw_rect(rect, FLOOR_DARK)
	draw_rect(rect, Color("#777b70"), false, 2)
	var vignette := Color(0.01, 0.012, 0.01, 0.18)
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 12)), vignette)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 12), Vector2(rect.size.x, 12)), vignette)
	_draw_noise_directions(rect, role, actor)


func _room_point(rect: Rect2, pos: Vector2) -> Vector2:
	return rect.position + Vector2((pos.x + 0.5) / ROOM_SIZE, (pos.y + 0.5) / ROOM_SIZE) * rect.size


func _item_is_hidden(room: Dictionary, item: Dictionary) -> bool:
	for furniture in room["furniture"]:
		if (furniture["pos"] as Vector2).distance_to(item["pos"]) < 0.44:
			return true
	return false


func _draw_furniture(rect: Rect2, furniture: Dictionary, selected: bool, mode: String) -> void:
	var center := _room_point(rect, furniture["pos"])
	var unit := rect.size.x / ROOM_SIZE
	var angle := deg_to_rad(float(furniture["rotation"]))
	var local_points := [
		Vector2(-unit * 0.38, -unit * 0.26), Vector2(unit * 0.38, -unit * 0.26),
		Vector2(unit * 0.38, unit * 0.26), Vector2(-unit * 0.38, unit * 0.26),
	]
	var points := PackedVector2Array()
	for point in local_points:
		points.append(center + (point as Vector2).rotated(angle))
	draw_colored_polygon(points, Color("#65675f"))
	for index in range(4):
		draw_line(points[index], points[(index + 1) % 4], GOLD_COLOR if selected else Color("#b6b0a4"), 2)
	if selected:
		draw_circle(center, 4, GOLD_COLOR if mode == "rotate" else TEXT_COLOR)
	var label_rect := Rect2(center - Vector2(unit * 0.38, 10), Vector2(unit * 0.76, 20))
	_text_center(furniture["kind"], label_rect, int(clamp(unit * 0.13, 9, 12)), TEXT_COLOR)


func _draw_doors(rect: Rect2, doors: Array) -> void:
	var length := rect.size.x * 0.13
	var thickness := 15.0
	for door in doors:
		var door_rect := Rect2()
		match door:
			"up":
				door_rect = Rect2(rect.position.x + rect.size.x / 2.0 - length / 2.0, rect.position.y - thickness / 2.0, length, thickness)
			"down":
				door_rect = Rect2(rect.position.x + rect.size.x / 2.0 - length / 2.0, rect.end.y - thickness / 2.0, length, thickness)
			"left":
				door_rect = Rect2(rect.position.x - thickness / 2.0, rect.position.y + rect.size.y / 2.0 - length / 2.0, thickness, length)
			"right":
				door_rect = Rect2(rect.end.x - thickness / 2.0, rect.position.y + rect.size.y / 2.0 - length / 2.0, thickness, length)
		draw_rect(door_rect, Color("#111311"))
		draw_rect(door_rect, Color("#858a80"), false, 1)


func _draw_actor(rect: Rect2, actor: Dictionary, role: String) -> void:
	var center := _room_point(rect, actor["pos"])
	var radius := rect.size.x / ROOM_SIZE * 0.22
	var color := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	draw_circle(center, radius + 3, Color(1, 1, 1, 0.14))
	draw_circle(center, radius, color)
	_text_center("怪" if role == "monster" else "盗", Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), int(clamp(radius * 0.9, 10, 15)), Color("#101110"))
	var facing := _direction_vector(actor["dir"])
	draw_line(center + facing * radius * 0.7, center + facing * radius * 1.45, color, 3)


func _draw_afterimage(rect: Rect2, pos: Vector2, alpha: float) -> void:
	var center := _room_point(rect, pos)
	var radius := rect.size.x / ROOM_SIZE * 0.21
	draw_circle(center, radius, Color(1.0, 0.12, 0.12, 0.25 * alpha))
	draw_arc(center, radius, 0, TAU, 28, Color(1.0, 0.3, 0.25, alpha), 2)
	_text_center("人", Rect2(center - Vector2(radius, radius), Vector2(radius * 2, radius * 2)), 11, Color(1.0, 0.65, 0.6, alpha))


func _draw_attack_cone(rect: Rect2, actor: Dictionary) -> void:
	var center := _room_point(rect, actor["pos"])
	var unit := rect.size.x / ROOM_SIZE
	var facing := _direction_vector(actor["dir"])
	var left := facing.rotated(-PI / 4.0) * unit * 2.35
	var right := facing.rotated(PI / 4.0) * unit * 2.35
	var points := PackedVector2Array([center, center + left, center + right])
	draw_colored_polygon(points, Color(1.0, 0.25, 0.12, 0.24))
	draw_line(center, center + left, MONSTER_COLOR, 1.5)
	draw_line(center, center + right, MONSTER_COLOR, 1.5)


func _draw_noise_directions(rect: Rect2, role: String, actor: Dictionary) -> void:
	var actor_global := Vector2(actor["room"]) * ROOM_SIZE + (actor["pos"] as Vector2)
	var origin := _room_point(rect, actor["pos"])
	if world_25d:
		var normalized: Vector2 = world_25d.project_normalized(role, actor["room"], actor["pos"], 0.55)
		origin = rect.position + normalized * rect.size
	for noise in noises:
		if noise["source"] == role:
			continue
		var room_distance: int = abs(noise["room"].x - actor["room"].x) + abs(noise["room"].y - actor["room"].y)
		if room_distance >= 3:
			continue
		var source_global: Vector2 = Vector2(noise["room"]) * ROOM_SIZE + (noise["pos"] as Vector2)
		var angle: float = actor_global.angle_to_point(source_global)
		var color: Color = MONSTER_COLOR if noise["source"] == "monster" else THIEF_COLOR
		var fade: float = clampf((float(noise["expires"]) - elapsed) / 2.0, 0.0, 1.0)
		for radius in [25.0, 42.0, 59.0]:
			draw_arc(origin, radius, angle - 0.58, angle + 0.58, 12, Color(color, fade), 2)


func _draw_center_rail(rect: Rect2) -> void:
	draw_rect(rect, PANEL_COLOR)
	draw_rect(rect, LINE_COLOR, false, 1)
	_text("全宅结构", rect.position + Vector2(12, 22), 10, MUTED_COLOR)
	var map_size: float = minf(rect.size.x - 24.0, 198.0)
	var map_rect := Rect2(rect.position + Vector2((rect.size.x - map_size) / 2.0, 38), Vector2(map_size, map_size))
	_draw_minimap(map_rect)
	_text("● 怪物", map_rect.position + Vector2(4, map_size + 19), 10, MONSTER_COLOR)
	_text_right("● 盗贼", map_rect.position + Vector2(map_size - 4, map_size + 19), 10, THIEF_COLOR)

	var rules_y: float = map_rect.end.y + 48.0
	draw_line(Vector2(rect.position.x, rules_y - 13), Vector2(rect.end.x, rules_y - 13), LINE_COLOR, 1)
	_text("本局规则", Vector2(rect.position.x + 12, rules_y + 5), 10, MUTED_COLOR)
	var rules: String = "盗贼行走无声；互动和每 15 秒肚子叫会暴露方向。\n\n噪音仅在曼哈顿房间距离小于 3 时被感知。\n\n红色人形是盗贼移动或操作时留下的短暂残影。\n\n家具会遮住其下方物品。"
	_multiline(rules, Vector2(rect.position.x + 12, rules_y + 27), rect.size.x - 24, 10, MUTED_COLOR, 16)

	var log_y: float = minf(rect.end.y - 190.0, rules_y + 205.0)
	draw_line(Vector2(rect.position.x, log_y), Vector2(rect.end.x, log_y), LINE_COLOR, 1)
	_text("事件记录", Vector2(rect.position.x + 12, log_y + 22), 10, MUTED_COLOR)
	var cursor: float = log_y + 43.0
	for entry in logs:
		_multiline("· " + entry, Vector2(rect.position.x + 12, cursor), rect.size.x - 24, 9, Color("#b2b5af"), 14)
		cursor += 33.0
		if cursor > rect.end.y - 10:
			break


func _draw_minimap(rect: Rect2) -> void:
	var gap := 3.0
	var cell := (rect.size.x - gap * (MAP_SIZE - 1)) / MAP_SIZE
	for room in rooms:
		var coord: Vector2i = room["coord"]
		var cell_rect := Rect2(
			rect.position + Vector2(coord.x, coord.y) * (cell + gap),
			Vector2(cell, cell)
		)
		var has_monster: bool = monster["room"] == coord
		var has_thief: bool = thief["room"] == coord
		var fill := Color("#252824")
		if has_monster and has_thief:
			fill = Color("#7b6e65")
		elif has_monster:
			fill = MONSTER_COLOR.darkened(0.15)
		elif has_thief:
			fill = THIEF_COLOR.darkened(0.25)
		draw_rect(cell_rect, fill)
		draw_rect(cell_rect, Color("#4b5048"), false, 1)
		var door_length := cell * 0.32
		for door in room["doors"]:
			match door:
				"up":
					draw_line(Vector2(cell_rect.get_center().x - door_length / 2, cell_rect.position.y), Vector2(cell_rect.get_center().x + door_length / 2, cell_rect.position.y), TEXT_COLOR, 2)
				"down":
					draw_line(Vector2(cell_rect.get_center().x - door_length / 2, cell_rect.end.y), Vector2(cell_rect.get_center().x + door_length / 2, cell_rect.end.y), TEXT_COLOR, 2)
				"left":
					draw_line(Vector2(cell_rect.position.x, cell_rect.get_center().y - door_length / 2), Vector2(cell_rect.position.x, cell_rect.get_center().y + door_length / 2), TEXT_COLOR, 2)
				"right":
					draw_line(Vector2(cell_rect.end.x, cell_rect.get_center().y - door_length / 2), Vector2(cell_rect.end.x, cell_rect.get_center().y + door_length / 2), TEXT_COLOR, 2)
		if has_monster or has_thief:
			var label := "怪盗" if has_monster and has_thief else ("怪" if has_monster else "盗")
			_text_center(label, cell_rect, int(clamp(cell * 0.34, 7, 10)), Color("#111311"))


func _draw_countdown_overlay(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.025, 0.02, 0.72))
	var card := Rect2(size / 2.0 - Vector2(220, 135), Vector2(440, 270))
	draw_rect(card, PANEL_COLOR)
	draw_rect(card, Color("#8b8f86"), false, 1)
	_text_center("双方玩家准备", Rect2(card.position + Vector2(0, 30), Vector2(card.size.x, 22)), 11, MUTED_COLOR)
	_text_center(str(seconds_left), Rect2(card.position + Vector2(0, 62), Vector2(card.size.x, 100)), 76, TEXT_COLOR)
	_text_center("怪物与盗贼已回到起点，倒计时结束后正式开始。", Rect2(card.position + Vector2(0, 190), Vector2(card.size.x, 30)), 12, MUTED_COLOR)


func _draw_result_overlay(size: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.015, 0.018, 0.015, 0.86))
	var card := Rect2(size / 2.0 - Vector2(270, 155), Vector2(540, 310))
	draw_rect(card, PANEL_COLOR)
	draw_rect(card, Color("#777d73"), false, 1)
	_text_center("行动结算", Rect2(card.position + Vector2(0, 28), Vector2(card.size.x, 24)), 11, MUTED_COLOR)
	_multiline(outcome, card.position + Vector2(45, 84), card.size.x - 90, 22, TEXT_COLOR, 32, HORIZONTAL_ALIGNMENT_CENTER)
	_text_center("盗取价值 %d · 剩余生命 %d" % [loot_value, max(int(thief["hp"]), 0)], Rect2(card.position + Vector2(0, 185), Vector2(card.size.x, 25)), 12, MUTED_COLOR)
	result_restart_rect = Rect2(card.position + Vector2(170, 235), Vector2(200, 42))
	_draw_button(result_restart_rect, "生成新宅邸")


func _text(text: String, pos: Vector2, size: int, color: Color) -> void:
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_right(text: String, pos: Vector2, size: int, color: Color) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, pos - Vector2(width, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_center(text: String, rect: Rect2, size: int, color: Color) -> void:
	var measured := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var baseline := rect.position + Vector2((rect.size.x - measured.x) / 2.0, (rect.size.y + measured.y * 0.65) / 2.0)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _multiline(text: String, pos: Vector2, width: float, size: int, color: Color, line_height: float, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var lines := text.split("\n")
	var y := pos.y
	for line in lines:
		if line.is_empty():
			y += line_height
			continue
		draw_string(font, Vector2(pos.x, y), line, alignment, width, size, color)
		y += line_height
