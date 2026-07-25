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
const FURNITURE_HIT_REACH := 1.35
const FURNITURE_HIT_DOT := 0.62
const TRINKET_SPAWN_CHANCE := 0.5
const HIT_WINDUP_TIME := 0.16
const HIT_LUNGE_TIME := 0.14
const HIT_RECOVER_TIME := 0.16
const HIT_WINDUP_DISTANCE := 0.22
const HIT_LUNGE_DISTANCE := 0.38
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
	{"id": "treasure-2", "kind": "treasure", "label": "银制烛台", "value": 2},
	{"id": "treasure-3", "kind": "treasure", "label": "祖母绿胸针", "value": 3},
	{"id": "treasure-5", "kind": "treasure", "label": "怪物之心", "value": 5},
]

const TRINKETS := ["旧怀表", "银汤匙", "铜制烟盒", "珍珠纽扣"]

var rng := RandomNumberGenerator.new()
var rooms: Array = []
var monster: Dictionary = {}
var thief: Dictionary = {}
var dragging := {"monster": "", "thief": ""}
var drag_mode := {"monster": "move", "thief": "move"}
var furniture_hit_actions := {"monster": {}, "thief": {}}
var active_storage_id := ""
var selected_treasure := 0
var loot_value := 0
var extracted_value := 0
var has_extracted := false
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
var help_open := {"monster": false, "thief": false}
var help_rects := {"monster": Rect2(), "thief": Rect2()}

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
	set_physics_process(true)
	set_process_input(true)


func new_game() -> void:
	rooms = _generate_rooms()
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	furniture_hit_actions = {"monster": {}, "thief": {}}
	active_storage_id = ""
	selected_treasure = 0
	loot_value = 0
	extracted_value = 0
	has_extracted = false
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
	help_open = {"monster": false, "thief": false}
	help_rects = {"monster": Rect2(), "thief": Rect2()}
	restart_rect = Rect2()
	early_rect = Rect2()
	logs = ["藏宝阶段开始：怪物持有 3 件藏品。"]
	if world_25d:
		world_25d.rebuild(rooms)
		world_25d.sync(rooms, monster, thief, afterimages, dragging, false, elapsed)
		world_25d.reset_physics_interpolation()
	queue_redraw()


func _make_actor(room: Vector2i, pos: Vector2, dir: String) -> Dictionary:
	return {
		"room": room,
		"pos": pos,
		"dir": dir,
		"facing": _direction_vector(dir),
		"impact_visual_offset": Vector2.ZERO,
		"hp": 2,
		"moving": false,
	}


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if world_25d:
			world_25d.sync(rooms, monster, thief, afterimages, dragging, false, elapsed)
		queue_redraw()
		return
	queue_redraw()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	elapsed += delta
	_update_phase(delta)
	_update_temporary_events()
	_update_furniture_hit_actions(delta)
	_update_storage_panel()
	if phase == "hunt":
		stomach_clock -= delta
		if stomach_clock <= 0.0:
			stomach_clock += 15.0
			_add_noise("thief", "肚子叫")
			_push_log("盗贼的肚子叫了，怪物获得 2 秒方向提示。")
	if phase != "ready" and phase != "ended":
		monster["moving"] = false
		thief["moving"] = false
		_handle_continuous_input(delta)
	if world_25d:
		world_25d.sync(rooms, monster, thief, afterimages, dragging, elapsed < attack_until, elapsed)


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

func _apply_view_relative_input(role: String, screen_input: Vector2, delta: float) -> void:
	if screen_input.is_zero_approx():
		return
	if bool(help_open[role]):
		return
	if not (furniture_hit_actions[role] as Dictionary).is_empty():
		return
	if role == "monster" and not _active_storage_furniture().is_empty():
		return
	var world_direction := screen_input.normalized()
	if world_25d:
		world_direction = world_25d.camera_relative_vector(role, screen_input)
	_move_actor_continuous(role, world_direction, delta)


func _input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for role in ["monster", "thief"]:
			if (help_rects[role] as Rect2).has_point(event.position):
				help_open[role] = not bool(help_open[role])
				get_viewport().set_input_as_handled()
				return
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
		return
	if key == KEY_F1:
		help_open["monster"] = not bool(help_open["monster"])
		return
	if key == KEY_KP_ADD:
		help_open["thief"] = not bool(help_open["thief"])
		return
	if key == KEY_ESCAPE and (bool(help_open["monster"]) or bool(help_open["thief"])):
		help_open["monster"] = false
		help_open["thief"] = false
		return
	if _help_blocks_key(key, physical):
		return
	if _handle_storage_panel_input(key, physical):
		get_viewport().set_input_as_handled()
		return
	if physical == KEY_H and phase == "hide":
		_begin_hunt_countdown()
	elif physical == KEY_Q:
		if world_25d:
			world_25d.rotate_camera("monster", -1)
	elif physical == KEY_E:
		if world_25d:
			world_25d.rotate_camera("monster", 1)
	elif physical == KEY_G:
		_hit_furniture("monster")
	elif physical == KEY_SPACE:
		_attack()
	elif key == KEY_KP_0:
		_hit_furniture("thief")
	elif key == KEY_KP_1:
		_thief_search()
	elif key == KEY_KP_2:
		_use_pill()
	elif key == KEY_KP_5:
		_thief_exit()
	elif key == KEY_KP_7:
		if world_25d:
			world_25d.rotate_camera("thief", -1)
	elif key == KEY_KP_9:
		if world_25d:
			world_25d.rotate_camera("thief", 1)


func _help_blocks_key(key: Key, physical: Key) -> bool:
	if bool(help_open["monster"]) and physical in [
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_G, KEY_R, KEY_SPACE,
	]:
		return true
	if bool(help_open["thief"]) and key in [
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_5, KEY_KP_7, KEY_KP_9,
	]:
		return true
	return false


func _handle_storage_panel_input(key: Key, physical: Key) -> bool:
	if _active_storage_furniture().is_empty():
		return false
	if key == KEY_ESCAPE:
		active_storage_id = ""
		_push_log("已关闭家具面板。")
		return true
	if physical == KEY_W:
		selected_treasure = (selected_treasure - 1 + TREASURES.size()) % TREASURES.size()
		return true
	if physical == KEY_S:
		selected_treasure = (selected_treasure + 1) % TREASURES.size()
		return true
	if physical == KEY_R:
		_place_treasure()
		return true
	return false


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
				})
			room["furniture"].append({
				"id": "f-%d-%d-%d" % [room["coord"].x, room["coord"].y, index],
				"kind": kind,
				"pos": pos,
				"rotation": float(rng.randi_range(0, 3) * 90),
				"opened": false,
				"destroyed": false,
				"damage": 0,
				"durability": _furniture_durability(kind),
				"contents": contents,
				"last_hit_time": -10.0,
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


func _furniture_durability(kind: String) -> int:
	match kind:
		"花瓶": return 1
		"木桶": return 2
		"床", "木箱": return 3
		_: return 4


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
	furniture_hit_actions = {"monster": {}, "thief": {}}
	active_storage_id = ""
	_push_log("藏宝结束：双方已回到起点，5 秒后正式开始。")


func _enter_hunt() -> void:
	if phase != "ready":
		return
	var unplaced := 0
	for treasure in TREASURES:
		if not _treasure_is_in_world(str(treasure["id"])):
			var furniture := _random_intact_furniture()
			if not furniture.is_empty():
				furniture["contents"].append((treasure as Dictionary).duplicate(true))
			unplaced += 1
	phase = "hunt"
	seconds_left = 0
	monster = _make_actor(MONSTER_SPAWN_ROOM, MONSTER_SPAWN_POS, "left")
	thief = _make_actor(ENTRANCE_ROOM, ENTRANCE_POS, "right")
	dragging = {"monster": "", "thief": ""}
	drag_mode = {"monster": "move", "thief": "move"}
	furniture_hit_actions = {"monster": {}, "thief": {}}
	active_storage_id = ""
	last_afterimage_at = -10.0
	stomach_clock = 15.0
	if unplaced > 0:
		_push_log("搜查开始：%d 件未存放藏品已自动放入家具。" % unplaced)
	else:
		_push_log("搜查开始：怪物与盗贼已回到各自起点。")


func _treasure_is_in_world(treasure_id: String) -> bool:
	for room in rooms:
		for furniture in room["furniture"]:
			for content in furniture["contents"]:
				if str(content["id"]) == treasure_id:
					return true
		for item in room["items"]:
			if str(item["id"]) == treasure_id and not bool(item["collected"]):
				return true
	return false


func _random_intact_furniture() -> Dictionary:
	var candidates: Array = []
	for room in rooms:
		for furniture in room["furniture"]:
			if not bool(furniture["destroyed"]) and not _furniture_has_treasure(furniture):
				candidates.append(furniture)
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)]


func _furniture_has_treasure(furniture: Dictionary) -> bool:
	for content in furniture.get("contents", []):
		if str(content.get("kind", "")) == "treasure":
			return true
	return false


func _move_actor_continuous(role: String, direction: Vector2, delta: float) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if direction.is_zero_approx():
		return
	var speed := FURNITURE_SPEED if dragging[role] != "" else ACTOR_SPEED
	var intended_direction := direction.normalized()
	var actor := _get_actor(role)
	actor["facing"] = intended_direction
	actor["dir"] = _direction_name(intended_direction)
	var motion := intended_direction * speed * delta
	var subdivisions := maxi(1, int(ceil(motion.length() / 0.05)))
	var step := motion / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(step.x):
			_move_actor_axis(role, Vector2(step.x, 0))
		if not is_zero_approx(step.y):
			_move_actor_axis(role, Vector2(0, step.y))
	actor["facing"] = intended_direction
	actor["dir"] = _direction_name(intended_direction)


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
			if bool(other.get("destroyed", false)):
				continue
			if (other["pos"] as Vector2).distance_to(next_furniture) < 0.78 or (other["pos"] as Vector2).distance_to(next_actor) < 0.58:
				blocked = true
		if blocked:
			return
		var before := {"pos": held["pos"], "rotation": held["rotation"]}
		held["pos"] = next_furniture
		_record_furniture_strokes(room, held["id"], before, held)
		actor["pos"] = next_actor
		actor["moving"] = true
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
		if bool(furniture.get("destroyed", false)):
			continue
		var furniture_pos: Vector2 = furniture["pos"]
		if abs(furniture_pos.x - target_pos.x) < 0.52 and abs(furniture_pos.y - target_pos.y) < 0.52:
			return
	actor["room"] = target_room
	actor["pos"] = target_pos
	actor["moving"] = true
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


func _hit_furniture(role: String) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not (furniture_hit_actions[role] as Dictionary).is_empty():
		return
	var actor := _get_actor(role)
	var nearby := _furniture_in_front(role)
	if nearby.is_empty():
		_push_log("%s前方没有可撞击的家具。" % _role_name(role))
		return
	if bool(nearby["destroyed"]):
		_push_log("%s已经损毁。" % nearby["kind"])
		return
	if role == "monster":
		active_storage_id = ""
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	furniture_hit_actions[role] = {
		"elapsed": 0.0,
		"impacted": false,
		"room": actor["room"],
		"furniture_id": str(nearby["id"]),
		"facing": facing.normalized(),
	}


func _update_furniture_hit_actions(delta: float) -> void:
	var impact_time := HIT_WINDUP_TIME + HIT_LUNGE_TIME
	var total_time := impact_time + HIT_RECOVER_TIME
	for role in ["monster", "thief"]:
		var action: Dictionary = furniture_hit_actions[role]
		if action.is_empty():
			continue
		action["elapsed"] = float(action["elapsed"]) + delta
		var action_time: float = action["elapsed"]
		var facing: Vector2 = action["facing"]
		var actor := _get_actor(role)
		if action_time < HIT_WINDUP_TIME:
			var windup_t := smoothstep(0.0, 1.0, action_time / HIT_WINDUP_TIME)
			actor["impact_visual_offset"] = -facing * HIT_WINDUP_DISTANCE * windup_t
		elif action_time < impact_time:
			var lunge_t := smoothstep(0.0, 1.0, (action_time - HIT_WINDUP_TIME) / HIT_LUNGE_TIME)
			actor["impact_visual_offset"] = facing * lerpf(-HIT_WINDUP_DISTANCE, HIT_LUNGE_DISTANCE, lunge_t)
		else:
			if not bool(action["impacted"]):
				action["impacted"] = true
				_apply_furniture_hit(role, action)
			var recover_t := clampf((action_time - impact_time) / HIT_RECOVER_TIME, 0.0, 1.0)
			actor["impact_visual_offset"] = facing * HIT_LUNGE_DISTANCE * (1.0 - smoothstep(0.0, 1.0, recover_t))
		if action_time >= total_time:
			actor["impact_visual_offset"] = Vector2.ZERO
			furniture_hit_actions[role] = {}


func _apply_furniture_hit(role: String, action: Dictionary) -> void:
	var room_coord: Vector2i = action["room"]
	var room := _room_at(room_coord)
	var furniture := _find_furniture(room, str(action["furniture_id"]))
	if furniture.is_empty() or bool(furniture["destroyed"]):
		return
	room["traces"].append({
		"pos": furniture["pos"],
		"role": role,
		"kind": "interact",
	})
	_add_noise(role, "撞击家具")
	if role == "thief":
		_reveal_thief()
	furniture["last_hit_time"] = elapsed
	if role == "monster":
		var was_open := bool(furniture["opened"])
		furniture["opened"] = true
		active_storage_id = str(furniture["id"])
		if was_open:
			_push_log("%s已打开，藏品面板与家具面板已显示。" % furniture["kind"])
		else:
			_push_log("怪物一击打开了%s，藏品面板与家具面板已显示。" % furniture["kind"])
	else:
		furniture["damage"] = int(furniture["damage"]) + 1
		var durability: int = int(furniture["durability"])
		if int(furniture["damage"]) >= durability:
			furniture["damage"] = durability
			furniture["destroyed"] = true
			furniture["opened"] = true
			var released := _release_furniture_contents(room, furniture)
			_push_log("盗贼撞毁了%s，掉出 %d 件财物。" % [furniture["kind"], released])
		else:
			_push_log("%s损毁度 %d / %d。" % [furniture["kind"], furniture["damage"], durability])


func _interact_furniture(role: String) -> void:
	_hit_furniture(role)


func _furniture_in_front(role: String, require_open := false) -> Dictionary:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var best: Dictionary = {}
	var best_distance := INF
	for furniture in room["furniture"]:
		if require_open and (not bool(furniture["opened"]) or bool(furniture["destroyed"])):
			continue
		var offset: Vector2 = (furniture["pos"] as Vector2) - (actor["pos"] as Vector2)
		var distance := offset.length()
		if distance <= 0.001 or distance > FURNITURE_HIT_REACH:
			continue
		if offset.normalized().dot(facing) < FURNITURE_HIT_DOT:
			continue
		if distance < best_distance:
			best = furniture
			best_distance = distance
	return best


func _update_storage_panel() -> void:
	if active_storage_id == "":
		return
	if _active_storage_furniture().is_empty():
		active_storage_id = ""


func _active_storage_furniture() -> Dictionary:
	if phase != "hide" or active_storage_id == "":
		return {}
	var room := _room_at(monster["room"])
	var furniture := _find_furniture(room, active_storage_id)
	if furniture.is_empty() or not bool(furniture["opened"]) or bool(furniture["destroyed"]):
		return {}
	if (furniture["pos"] as Vector2).distance_to(monster["pos"]) > 1.65:
		return {}
	return furniture


func _release_furniture_contents(room: Dictionary, furniture: Dictionary) -> int:
	var contents: Array = furniture["contents"]
	var released := contents.size()
	for index in range(contents.size()):
		var item: Dictionary = (contents[index] as Dictionary).duplicate(true)
		var angle := TAU * float(index) / float(maxi(contents.size(), 1))
		var offset := Vector2.RIGHT.rotated(angle) * (0.28 + 0.08 * float(index))
		item["pos"] = (furniture["pos"] as Vector2) + offset
		item["collected"] = false
		room["items"].append(item)
	contents.clear()
	return released


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
	var furniture := _active_storage_furniture()
	if furniture.is_empty():
		_push_log("先面向家具按 G 完成冲撞，打开面板后用 R 存取。")
		return
	var contents: Array = furniture["contents"]
	for index in range(contents.size()):
		var content: Dictionary = contents[index]
		if content["id"] == treasure["id"]:
			contents.remove_at(index)
			_push_log("已从%s取出%s。" % [furniture["kind"], treasure["label"]])
			return
	if _furniture_has_treasure(furniture):
		_push_log("%s只能存放一件藏品，请先取出原有藏品。" % furniture["kind"])
		return
	for room in rooms:
		for other_furniture in room["furniture"]:
			for content in other_furniture["contents"]:
				if content["id"] == treasure["id"]:
					_push_log("%s已存放在其他家具，请先取出。" % treasure["label"])
					return
		for item in room["items"]:
			if item["id"] == treasure["id"] and not bool(item["collected"]):
				_push_log("%s已在房间中。" % treasure["label"])
				return
	contents.append(treasure.duplicate(true))
	var room := _room_at(monster["room"])
	room["traces"].append({"pos": monster["pos"], "role": "monster", "kind": "interact"})
	_push_log("已将%s存入%s（价值 %d）。" % [treasure["label"], furniture["kind"], treasure["value"]])


func _thief_search() -> void:
	if phase != "hunt":
		return
	var room := _room_at(thief["room"])
	for item in room["items"]:
		if not item["collected"] and (item["pos"] as Vector2).distance_to(thief["pos"]) <= 0.58:
			item["collected"] = true
			if item["kind"] == "treasure" or item["kind"] == "trinket":
				loot_value += int(item["value"])
				_push_log("盗贼携带%s，身上价值 %d。" % [item["label"], loot_value])
			else:
				pills += 1
				_push_log("盗贼捡到一颗治疗药丸。")
			_add_noise("thief", "拾取物品")
			_reveal_thief()
			return
	_push_log("附近没有可以拾取的物品。")


func _thief_exit() -> void:
	if phase != "hunt" or has_extracted:
		return
	if thief["room"] == ENTRANCE_ROOM and (thief["pos"] as Vector2).distance_to(ENTRANCE_POS) <= 0.58:
		has_extracted = true
		extracted_value = loot_value
		phase = "ended"
		if extracted_value >= 5:
			outcome = "盗贼完成本局唯一一次撤离，带出价值 %d 的财物。" % extracted_value
		else:
			outcome = "盗贼已撤离，但带出价值只有 %d，行动失败。" % extracted_value
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
	var facing: Vector2 = monster.get("facing", _direction_vector(monster["dir"]))
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
	var layout := _calculate_layout(size)
	_draw_room_panel(layout["monster_panel"], layout["monster_room"], "monster")
	_draw_room_panel(layout["thief_panel"], layout["thief_room"], "thief")
	if phase == "ready":
		_draw_countdown_overlay(size)
	elif phase == "ended":
		_draw_result_overlay(size)


func _calculate_layout(size: Vector2) -> Dictionary:
	var margin := 10.0
	var gap := 10.0
	var side_width := (size.x - margin * 2.0 - gap) / 2.0
	var panel_height := size.y - margin * 2.0
	var room_side := minf(side_width - 18.0, panel_height - 136.0)
	room_side = maxf(room_side, 280.0)
	var left_panel := Rect2(margin, margin, side_width, panel_height)
	var right_panel := Rect2(left_panel.end.x + gap, margin, side_width, panel_height)
	var left_room := Rect2(
		left_panel.position.x + (side_width - room_side) / 2.0,
		left_panel.position.y + 48.0,
		room_side,
		room_side
	)
	var right_room := Rect2(
		right_panel.position.x + (side_width - room_side) / 2.0,
		right_panel.position.y + 48.0,
		room_side,
		room_side
	)
	return {
		"monster_panel": left_panel,
		"monster_room": left_room,
		"thief_panel": right_panel,
		"thief_room": right_room,
	}


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
	_text("怪物视角" if role == "monster" else "盗贼视角", panel.position + Vector2(12, 20), 10, MUTED_COLOR)
	_text("房间 %d-%d · %s" % [actor["room"].x + 1, actor["room"].y + 1, _phase_short_label()], panel.position + Vector2(12, 39), 14, TEXT_COLOR)
	var help_rect := Rect2(Vector2(panel.end.x - 40, panel.position.y + 9), Vector2(28, 28))
	help_rects[role] = help_rect
	draw_rect(help_rect, Color("#252925"))
	draw_rect(help_rect, accent, false, 1.5)
	_text_center("?", help_rect, 16, accent)

	_draw_room(room_rect, role, room, actor)
	if role == "monster":
		_draw_storage_exchange(room_rect)
	_draw_view_minimap(room_rect, role)
	if bool(help_open[role]):
		_draw_help_overlay(room_rect, role)
	var footer := Rect2(panel.position.x, room_rect.end.y + 10, panel.size.x, panel.end.y - room_rect.end.y - 10)
	draw_rect(footer, PANEL_ALT)
	draw_line(footer.position, Vector2(footer.end.x, footer.position.y), LINE_COLOR, 1)
	var controls := ""
	if role == "monster":
		controls = "WASD 移动  G 撞击  空格 攻击  Q/E 视角  Tab 地图  F1 帮助\n家具面板：W/S 选择  R 存取  Esc 关闭"
	else:
		controls = "方向键 移动  Num0 撞击  Num1 拾取  Num2 药丸  Num5 撤离\nNum7/9 视角  按住 Num8 地图  Num+ 帮助"
	_multiline(controls, footer.position + Vector2(12, 22), footer.size.x - 24, 11, MUTED_COLOR, 19)


func _phase_short_label() -> String:
	match phase:
		"hide": return "藏宝 %d:%02d" % [seconds_left / 60, seconds_left % 60]
		"ready": return "准备 %d" % seconds_left
		"hunt": return "实时搜查"
		_: return "本局结束"


func _draw_view_minimap(room_rect: Rect2, role: String) -> void:
	var expanded := _map_expanded(role)
	var map_size := clampf(room_rect.size.x * 0.2, 92.0, 124.0)
	var map_rect := Rect2(room_rect.position + Vector2(14, 14), Vector2(map_size, map_size))
	if expanded:
		map_size = minf(room_rect.size.x, room_rect.size.y) * 0.72
		map_rect = Rect2(room_rect.get_center() - Vector2.ONE * map_size / 2.0, Vector2.ONE * map_size)
	draw_rect(map_rect.grow(7), Color(0.035, 0.04, 0.035, 0.94))
	draw_rect(map_rect.grow(7), MONSTER_COLOR if role == "monster" else THIEF_COLOR, false, 1.5)
	_draw_minimap(map_rect)
	if not expanded:
		_text("TAB" if role == "monster" else "N8", map_rect.position + Vector2(4, 12), 8, Color(1, 1, 1, 0.7))


func _map_expanded(role: String) -> bool:
	return Input.is_key_pressed(KEY_TAB) if role == "monster" else Input.is_key_pressed(KEY_KP_8)


func _draw_help_overlay(room_rect: Rect2, role: String) -> void:
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	var card := room_rect.grow(-42)
	draw_rect(card, Color(0.035, 0.04, 0.035, 0.97))
	draw_rect(card, accent, false, 2.0)
	_text_center("本局规则", Rect2(card.position + Vector2(0, 20), Vector2(card.size.x, 28)), 20, TEXT_COLOR)
	var rules := (
		"· 怪物一击打开家具；盗贼必须撞到耐久归零。\n\n"
		+ "· 每件家具最多存一件正式藏品，并有 50% 概率藏有小玩意儿。\n\n"
		+ "· 财物只有从入口撤离后才结算，每局只能撤离一次。\n\n"
		+ "· 高价值家具晃动更明显；撞击和操作会制造噪音。\n\n"
		+ "· 双方视角、移动键、地图与帮助界面彼此独立。"
	)
	_multiline(rules, card.position + Vector2(34, 78), card.size.x - 68, 12, MUTED_COLOR, 21)
	var close_label := "F1 / Esc 关闭" if role == "monster" else "Num+ / Esc 关闭"
	_text_center(close_label, Rect2(Vector2(card.position.x, card.end.y - 48), Vector2(card.size.x, 25)), 11, accent)


func _draw_storage_exchange(room_rect: Rect2) -> void:
	var furniture := _active_storage_furniture()
	if furniture.is_empty():
		return
	var overlay_height := minf(210.0, room_rect.size.y * 0.48)
	var overlay := Rect2(
		room_rect.position + Vector2(14.0, room_rect.size.y - overlay_height - 14.0),
		Vector2(room_rect.size.x - 28.0, overlay_height)
	)
	draw_rect(overlay, Color(0.055, 0.062, 0.055, 0.96))
	draw_rect(overlay, GOLD_COLOR, false, 2.0)
	var title_rect := Rect2(overlay.position, Vector2(overlay.size.x, 34.0))
	draw_rect(title_rect, Color("#25271f"))
	_text("家具已打开 · W/S 选择 · R 存取 · Esc 关闭", title_rect.position + Vector2(12, 22), 11, GOLD_COLOR)

	var gap := 10.0
	var column_width := (overlay.size.x - 34.0 - gap) / 2.0
	var left := Rect2(overlay.position + Vector2(12, 44), Vector2(column_width, overlay.size.y - 56))
	var right := Rect2(Vector2(left.end.x + gap, left.position.y), left.size)
	draw_rect(left, Color("#151815"))
	draw_rect(right, Color("#151815"))
	draw_rect(left, LINE_COLOR, false, 1.0)
	draw_rect(right, LINE_COLOR, false, 1.0)
	_text("怪物藏品", left.position + Vector2(10, 20), 11, TEXT_COLOR)
	_text("家具面板 · %s" % furniture["kind"], right.position + Vector2(10, 20), 11, TEXT_COLOR)

	var row_y := left.position.y + 34.0
	for index in range(TREASURES.size()):
		var treasure: Dictionary = TREASURES[index]
		var row := Rect2(Vector2(left.position.x + 7, row_y - 14), Vector2(left.size.x - 14, 25))
		if index == selected_treasure:
			draw_rect(row, Color(0.9, 0.75, 0.24, 0.16))
			draw_rect(row, GOLD_COLOR, false, 1.0)
		var status := _treasure_panel_status(str(treasure["id"]), str(furniture["id"]))
		_text("%s%s · %d" % ["▶ " if index == selected_treasure else "   ", treasure["label"], treasure["value"]], Vector2(row.position.x + 4, row_y + 3), 10, TEXT_COLOR)
		_text_right(status, Vector2(row.end.x - 4, row_y + 3), 9, GOLD_COLOR if status == "随身" else MUTED_COLOR)
		row_y += 29.0

	var stored_treasure := "空藏品槽"
	var trinket_names: Array[String] = []
	for content in furniture["contents"]:
		if content["kind"] == "treasure":
			stored_treasure = "%s · 价值 %d" % [content["label"], content["value"]]
		elif content["kind"] == "trinket":
			trinket_names.append("%s · %d" % [content["label"], content["value"]])
	_text("藏品槽（限 1 件）", right.position + Vector2(10, 43), 9, MUTED_COLOR)
	_multiline(stored_treasure, right.position + Vector2(10, 62), right.size.x - 20, 10, GOLD_COLOR if stored_treasure != "空藏品槽" else TEXT_COLOR, 16)
	_text("其他物品", right.position + Vector2(10, 91), 9, MUTED_COLOR)
	var trinket_text := "无" if trinket_names.is_empty() else "、".join(trinket_names)
	_multiline(trinket_text, right.position + Vector2(10, 110), right.size.x - 20, 9, TEXT_COLOR, 15)


func _treasure_panel_status(treasure_id: String, current_furniture_id: String) -> String:
	for room in rooms:
		for furniture in room["furniture"]:
			for content in furniture["contents"]:
				if str(content["id"]) == treasure_id:
					return "本家具" if str(furniture["id"]) == current_furniture_id else "已存放"
		for item in room["items"]:
			if str(item["id"]) == treasure_id and not bool(item["collected"]):
				return "已掉落"
	return "随身"


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
	_text_center("带出价值 %d · 剩余生命 %d" % [extracted_value, max(int(thief["hp"]), 0)], Rect2(card.position + Vector2(0, 185), Vector2(card.size.x, 25)), 12, MUTED_COLOR)
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
