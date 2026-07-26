@tool
extends Node2D

# Native Godot migration of the original web prototype.

const WORLD_25D_SCRIPT := preload("res://scripts/world_25d.gd")
const MAP_SIZE := 6
const ROOM_SIZE := 5.0
const ACTOR_SPEED := 4.0
const ACTOR_COLLISION_RADIUS := 0.25
const MONSTER_COLLISION_RADIUS := 576.0 * 0.00263 * 0.5 / WORLD_25D_SCRIPT.CELL_SIZE
const THIEF_COLLISION_RADIUS := 384.0 * 0.00270 * 0.5 / WORLD_25D_SCRIPT.CELL_SIZE
const FURNITURE_SPEED := 2.0
const ROTATION_SPEED := 90.0
const ROTATION_STEP := 4.0
const FURNITURE_HIT_REACH := 1.35
const FURNITURE_HIT_DOT := 0.62
const TRINKET_SPAWN_CHANCE := 0.5
const PILL_SPAWN_COUNT := 3
const HIDDEN_TOOL_RATIO := 0.5
const HIT_WINDUP_TIME := 0.16
const HIT_LUNGE_TIME := 0.14
const HIT_RECOVER_TIME := 0.16
const HIT_WINDUP_DISTANCE := 0.22
const HIT_LUNGE_DISTANCE := 0.38
const TOOL_INVENTORY_CAPACITY := 3
const DETECTOR_BATTERY_SECONDS := 18.0
const DETECTOR_NOISE_INTERVAL := 3.0
const TRAP_ESCAPE_PRESSES := 20
const TRAP_TRIGGER_RADIUS := 0.34
const TRAP_ARM_DELAY := 0.6
const ADRENALINE_SECONDS := 6.0
const FATIGUE_SECONDS := 3.0
const DECOY_SECONDS := 5.0
const DECOY_DASH_DISTANCE := 1.15
const PHONOGRAPH_DELAY := 2.0
const PHONOGRAPH_SECONDS := 10.0
const TELEPORT_CHANNEL_SECONDS := 5.0
const SPRING_GLOVE_REACH := 1.45
const SPRING_GLOVE_KNOCKBACK := 1.2
const SPRING_GLOVE_STUN_SECONDS := 1.0
const TOOL_INSPECT_DISTANCE := 1.05
const PICKUP_DISTANCE := 0.64
const NOISE_SAMPLE_RATE := 11025
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
const WILD_TREASURE_COUNT := 10
const WILD_TREASURE := {"id": "treasure-1", "kind": "treasure", "label": "古铜币", "value": 1}

const TOOL_DEFS := {
	"detector": {
		"label": "藏品探测器",
		"short": "探测",
		"description": "开启后探测同一房间内的藏品信号，电量有限。",
		"color": Color("#78d7e8"),
	},
	"alarm": {
		"label": "警报器",
		"short": "警报",
		"description": "藏进完好家具；家具被撞开后全图鸣响5秒。",
		"color": Color("#f0735f"),
	},
	"trap": {
		"label": "捕兽夹",
		"short": "兽夹",
		"description": "放置在地面，踩中者需左右交替20次才能挣脱。",
		"color": Color("#c6a66a"),
	},
	"adrenaline": {
		"label": "肾上腺素",
		"short": "加速",
		"description": "速度翻倍6秒，随后进入3秒减速疲劳。",
		"color": Color("#e45b68"),
	},
	"decoy": {
		"label": "替身玩偶",
		"short": "替身",
		"description": "留下一个替身，同时向面朝方向快速位移。",
		"color": Color("#b98be2"),
	},
	"phonograph": {
		"label": "留声机",
		"short": "留声",
		"description": "放置后再次靠近启动，延迟播放10秒撞击声。",
		"color": Color("#d49a5b"),
	},
	"teleporter": {
		"label": "传送器",
		"short": "传送",
		"description": "仅盗贼可用；轰鸣5秒后携带全部藏品撤离。",
		"color": Color("#68c8ff"),
	},
	"spring_glove": {
		"label": "弹簧拳套",
		"short": "拳套",
		"description": "击退相邻敌人并使其眩晕1秒，一次性使用。",
		"color": Color("#f1c65a"),
	},
}

const TOOL_SPAWN_COUNTS := {
	"detector": 2,
	"alarm": 2,
	"trap": 2,
	"adrenaline": 2,
	"decoy": 2,
	"phonograph": 2,
	"teleporter": 1,
	"spring_glove": 2,
}

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
var tool_inventories := {"monster": [], "thief": []}
var tool_selected := {"monster": 0, "thief": 0}
var status_effects := {"monster": {}, "thief": {}}
var trapped_by := {"monster": "", "thief": ""}
var trap_escape_progress := {"monster": 0, "thief": 0}
var trap_expected_left := {"monster": true, "thief": true}
var next_device_id := 0

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
	tool_inventories = {"monster": [], "thief": []}
	tool_selected = {"monster": 0, "thief": 0}
	status_effects = {
		"monster": _fresh_status_effects(),
		"thief": _fresh_status_effects(),
	}
	trapped_by = {"monster": "", "thief": ""}
	trap_escape_progress = {"monster": 0, "thief": 0}
	trap_expected_left = {"monster": true, "thief": true}
	next_device_id = 0
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
	_update_tool_states(delta)
	_update_devices()
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
	if not _role_can_act(role):
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
	if _handle_trap_escape_input("monster", key, physical):
		get_viewport().set_input_as_handled()
		return
	if _handle_trap_escape_input("thief", key, physical):
		get_viewport().set_input_as_handled()
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
	elif physical == KEY_R:
		_pick_up_nearby("monster")
	elif physical == KEY_Z:
		_cycle_tool("monster", -1)
	elif physical == KEY_X:
		_cycle_tool("monster", 1)
	elif physical == KEY_F:
		_use_selected_tool("monster")
	elif key == KEY_KP_0:
		_hit_furniture("thief")
	elif key == KEY_KP_1:
		_pick_up_nearby("thief")
	elif key == KEY_KP_2:
		_use_pill()
	elif key == KEY_KP_3:
		_use_selected_tool("thief")
	elif key == KEY_KP_4:
		_cycle_tool("thief", -1)
	elif key == KEY_KP_5:
		_thief_exit()
	elif key == KEY_KP_6:
		_cycle_tool("thief", 1)
	elif key == KEY_KP_7:
		if world_25d:
			world_25d.rotate_camera("thief", -1)
	elif key == KEY_KP_9:
		if world_25d:
			world_25d.rotate_camera("thief", 1)


func _help_blocks_key(key: Key, physical: Key) -> bool:
	if bool(help_open["monster"]) and physical in [
		KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E, KEY_G, KEY_R, KEY_SPACE,
		KEY_Z, KEY_X, KEY_F,
	]:
		return true
	if bool(help_open["thief"]) and key in [
		KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT,
		KEY_KP_0, KEY_KP_1, KEY_KP_2, KEY_KP_3, KEY_KP_4, KEY_KP_5,
		KEY_KP_6, KEY_KP_7, KEY_KP_9,
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

	var kinds := ["衣柜", "书柜", "木桶", "木箱", "花瓶"]
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
		furniture["contents"].append(WILD_TREASURE.duplicate(true))
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
	var hidden_tool_count := int(round(float(_total_tool_spawn_count()) * HIDDEN_TOOL_RATIO))
	var generated_tools: Array = []
	var tool_index := 0
	for tool_type in TOOL_SPAWN_COUNTS:
		for _copy in range(int(TOOL_SPAWN_COUNTS[tool_type])):
			generated_tools.append(_make_tool_instance(str(tool_type), "tool-%d" % tool_index))
			tool_index += 1
	_shuffle_with_rng(generated_tools)
	var hidden_index := 0
	for index in range(generated_tools.size()):
		var tool_item: Dictionary = generated_tools[index]
		if index < hidden_tool_count and hidden_index < hidden_furniture.size():
			(hidden_furniture[hidden_index] as Dictionary)["contents"].append(tool_item)
			hidden_index += 1
		else:
			var room := _random_room_for_visible_item(generated, visible_room_keys)
			tool_item["pos"] = _empty_position(room)
			tool_item["collected"] = false
			room["items"].append(tool_item)
			visible_room_keys[_room_key_for_distribution(room["coord"])] = room["coord"]
	return generated


func _total_tool_spawn_count() -> int:
	var total := 0
	for count in TOOL_SPAWN_COUNTS.values():
		total += int(count)
	return total


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
	return {
		"adrenaline_until": 0.0,
		"fatigue_until": 0.0,
		"stunned_until": 0.0,
		"teleport_started": -1.0,
		"teleport_ends": -1.0,
	}


func _make_tool_instance(tool_type: String, id: String) -> Dictionary:
	var definition: Dictionary = TOOL_DEFS[tool_type]
	var result := {
		"id": id,
		"kind": "tool",
		"tool_type": tool_type,
		"label": definition["label"],
		"value": 0,
	}
	if tool_type == "detector":
		result["charge"] = DETECTOR_BATTERY_SECONDS
		result["active"] = false
		result["next_noise"] = 0.0
	return result


func _push_log(message: String) -> void:
	logs.push_front(message)
	if logs.size() > 5:
		logs.resize(5)


func _add_noise(
	role: String,
	label: String,
	actor_override: Dictionary = {},
	throttle := 0.0,
	duration := 2.0,
	global := false
) -> void:
	if phase != "hunt":
		return
	var actor := actor_override if not actor_override.is_empty() else _get_actor(role)
	_add_noise_at(role, label, actor["room"], actor["pos"], throttle, duration, global)


func _add_noise_at(
	source: String,
	label: String,
	room: Vector2i,
	pos: Vector2,
	throttle := 0.0,
	duration := 2.0,
	global := false
) -> void:
	if phase != "hunt":
		return
	if throttle > 0.0:
		for existing in noises:
			if existing["source"] == source and existing["label"] == label and elapsed - float(existing["created"]) < throttle:
				return
	noises.append({
		"source": source,
		"label": label,
		"room": room,
		"pos": pos,
		"created": elapsed,
		"expires": elapsed + duration,
		"duration": duration,
		"global": global,
	})
	if global:
		_play_global_noise(label, duration)


func _play_global_noise(label: String, event_duration: float) -> void:
	if not is_inside_tree():
		return
	var sound_duration := 0.22
	var base_frequency := 360.0
	if "警报" in label:
		sound_duration = minf(event_duration, 5.0)
		base_frequency = 520.0
	elif "传送器" in label:
		sound_duration = minf(event_duration, TELEPORT_CHANNEL_SECONDS)
		base_frequency = 92.0
	elif "捕兽夹触发" in label:
		sound_duration = 0.72
		base_frequency = 180.0
	elif "捕兽夹" in label:
		sound_duration = 0.18
		base_frequency = 240.0
	elif "留声机" in label:
		sound_duration = 0.2
		base_frequency = 145.0
	elif "探测器" in label:
		sound_duration = 0.16
		base_frequency = 760.0
	var sample_count := maxi(1, int(ceil(sound_duration * NOISE_SAMPLE_RATE)))
	var bytes := PackedByteArray()
	bytes.resize(sample_count * 2)
	for index in range(sample_count):
		var sample_time := float(index) / float(NOISE_SAMPLE_RATE)
		var remaining := sound_duration - sample_time
		var envelope := minf(sample_time * 28.0, 1.0) * minf(remaining * 18.0, 1.0)
		var frequency := base_frequency
		if "警报" in label:
			frequency *= 1.32 if int(sample_time * 4.0) % 2 == 0 else 0.88
		elif "传送器" in label:
			frequency += sin(sample_time * TAU * 0.8) * 18.0
		var wave := sin(sample_time * TAU * frequency)
		if "留声机" in label or "捕兽夹" in label:
			wave = signf(wave) * 0.65 + sin(sample_time * TAU * frequency * 2.31) * 0.35
		var sample_value := int(clampf(wave * envelope * 0.24, -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, sample_value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = NOISE_SAMPLE_RATE
	stream.stereo = false
	stream.data = bytes
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = -8.0
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


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
	status_effects = {
		"monster": _fresh_status_effects(),
		"thief": _fresh_status_effects(),
	}
	trapped_by = {"monster": "", "thief": ""}
	trap_escape_progress = {"monster": 0, "thief": 0}
	trap_expected_left = {"monster": true, "thief": true}
	for role in ["monster", "thief"]:
		for tool in tool_inventories[role]:
			if str(tool.get("tool_type", "")) == "detector":
				tool["active"] = false
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
	status_effects = {
		"monster": _fresh_status_effects(),
		"thief": _fresh_status_effects(),
	}
	trapped_by = {"monster": "", "thief": ""}
	trap_escape_progress = {"monster": 0, "thief": 0}
	trap_expected_left = {"monster": true, "thief": true}
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
			if not bool(furniture["destroyed"]) and not _furniture_has_primary_content(furniture):
				candidates.append(furniture)
	if candidates.is_empty():
		return {}
	return candidates[rng.randi_range(0, candidates.size() - 1)]


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


func _move_actor_continuous(role: String, direction: Vector2, delta: float) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	if direction.is_zero_approx():
		return
	var speed := (FURNITURE_SPEED if dragging[role] != "" else ACTOR_SPEED) * _movement_multiplier(role)
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


func _role_can_act(role: String) -> bool:
	if str(trapped_by.get(role, "")) != "":
		return false
	var effects: Dictionary = status_effects.get(role, {})
	return elapsed >= float(effects.get("stunned_until", 0.0))


func _movement_multiplier(role: String) -> float:
	var effects: Dictionary = status_effects.get(role, {})
	if elapsed < float(effects.get("adrenaline_until", 0.0)):
		return 2.0
	if elapsed < float(effects.get("fatigue_until", 0.0)):
		return 0.5
	return 1.0


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
			or not _position_clears_room_walls(room, next_actor, role)
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
	if not _position_clears_room_walls(target_room_data, target_pos, role):
		return
	for furniture in target_room_data["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		if _actor_overlaps_furniture(target_pos, furniture, role):
			return
	actor["room"] = target_room
	actor["pos"] = target_pos
	actor["moving"] = true
	if role == "monster":
		_add_noise(role, "怪物脚步", actor, 0.42)
	else:
		_reveal_thief(actor)


func _actor_collision_radius(role: String) -> float:
	return MONSTER_COLLISION_RADIUS if role == "monster" else THIEF_COLLISION_RADIUS


func _position_clears_room_walls(room: Dictionary, pos: Vector2, role := "") -> bool:
	var doors: Array = room["doors"]
	var collision_radius := ACTOR_COLLISION_RADIUS if role == "" else _actor_collision_radius(role)
	var door_center_limit := (
		WORLD_25D_SCRIPT.DOOR_GAP / (2.0 * WORLD_25D_SCRIPT.CELL_SIZE)
		- collision_radius
	)
	if pos.x < collision_radius:
		if not doors.has("left") or absf(pos.y - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if pos.x > ROOM_SIZE - collision_radius:
		if not doors.has("right") or absf(pos.y - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if pos.y < collision_radius:
		if not doors.has("up") or absf(pos.x - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	if pos.y > ROOM_SIZE - collision_radius:
		if not doors.has("down") or absf(pos.x - ROOM_SIZE * 0.5) > door_center_limit:
			return false
	return true


func _actor_overlaps_furniture(actor_pos: Vector2, furniture: Dictionary, role := "") -> bool:
	var half_extents := _furniture_half_extents(str(furniture["kind"]))
	var collision_radius := ACTOR_COLLISION_RADIUS if role == "" else _actor_collision_radius(role)
	var local_pos := (
		actor_pos - (furniture["pos"] as Vector2)
	).rotated(-deg_to_rad(float(furniture["rotation"])))
	var closest := Vector2(
		clampf(local_pos.x, -half_extents.x, half_extents.x),
		clampf(local_pos.y, -half_extents.y, half_extents.y),
	)
	return local_pos.distance_squared_to(closest) < collision_radius * collision_radius


func _furniture_half_extents(kind: String) -> Vector2:
	# Ground-plane footprint of the renderer's hidden 3D base meshes, converted
	# from world metres to the room's continuous coordinate system.
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
	if not _role_can_act(role):
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
		_trigger_furniture_alarm(room_coord, furniture)
		if phase == "hide":
			active_storage_id = str(furniture["id"])
			if was_open:
				_push_log("%s已打开，藏品面板与家具面板已显示。" % furniture["kind"])
			else:
				_push_log("怪物一击打开了%s，藏品面板与家具面板已显示。" % furniture["kind"])
		else:
			var released_tools := _release_furniture_tools(room, furniture)
			if released_tools > 0:
				_push_log("怪物打开%s，发现并掉出 %d 件道具。" % [furniture["kind"], released_tools])
			elif was_open:
				_push_log("%s已经打开，里面没有可取道具。" % furniture["kind"])
			else:
				_push_log("怪物一击打开了%s。" % furniture["kind"])
	else:
		furniture["damage"] = int(furniture["damage"]) + 1
		var durability: int = int(furniture["durability"])
		if int(furniture["damage"]) >= durability:
			furniture["damage"] = durability
			furniture["destroyed"] = true
			furniture["opened"] = true
			_trigger_furniture_alarm(room_coord, furniture)
			var released := _release_furniture_contents(room, furniture)
			_push_log("盗贼撞毁了%s，掉出 %d 件物品。" % [furniture["kind"], released])
		else:
			_push_log("%s损毁度 %d / %d。" % [furniture["kind"], furniture["damage"], durability])


func _trigger_furniture_alarm(room_coord: Vector2i, furniture: Dictionary) -> bool:
	var contents: Array = furniture["contents"]
	for index in range(contents.size() - 1, -1, -1):
		var content: Dictionary = contents[index]
		if str(content.get("kind", "")) != "alarm":
			continue
		var owner := str(content.get("owner", "neutral"))
		contents.remove_at(index)
		_add_noise_at(
			owner,
			"家具警报",
			room_coord,
			furniture["pos"],
			0.0,
			5.0,
			true,
		)
		_push_log("%s里的警报器被触发，全宅邸响起5秒警报！" % furniture["kind"])
		return true
	return false


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


func _nearest_intact_furniture(role: String, max_distance := 1.25) -> Dictionary:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var best: Dictionary = {}
	var best_distance := INF
	for furniture in room["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		var distance := (furniture["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= max_distance and distance < best_distance:
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


func _release_furniture_tools(room: Dictionary, furniture: Dictionary) -> int:
	var contents: Array = furniture["contents"]
	var released := 0
	for index in range(contents.size() - 1, -1, -1):
		var content: Dictionary = contents[index]
		if str(content.get("kind", "")) != "tool":
			continue
		var item := content.duplicate(true)
		var angle := float(released) * 1.9 + 0.35
		item["pos"] = (furniture["pos"] as Vector2) + Vector2.RIGHT.rotated(angle) * (0.34 + released * 0.06)
		item["collected"] = false
		room["items"].append(item)
		contents.remove_at(index)
		released += 1
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
	if _furniture_has_primary_content(furniture):
		_push_log("%s的藏品槽已被占用，请先取出原有内容。" % furniture["kind"])
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


func _selected_tool(role: String) -> Dictionary:
	var inventory: Array = tool_inventories[role]
	if inventory.is_empty():
		return {}
	var index := clampi(int(tool_selected[role]), 0, inventory.size() - 1)
	tool_selected[role] = index
	return inventory[index]


func _cycle_tool(role: String, direction: int) -> void:
	var inventory: Array = tool_inventories[role]
	if inventory.is_empty():
		_push_log("%s没有携带道具。" % _role_name(role))
		return
	tool_selected[role] = posmod(int(tool_selected[role]) + direction, inventory.size())
	_push_log("%s选择了%s。" % [_role_name(role), _selected_tool(role)["label"]])


func _consume_selected_tool(role: String) -> void:
	var inventory: Array = tool_inventories[role]
	if inventory.is_empty():
		return
	var index := clampi(int(tool_selected[role]), 0, inventory.size() - 1)
	inventory.remove_at(index)
	tool_selected[role] = clampi(index, 0, maxi(inventory.size() - 1, 0))


func _pick_up_nearby(role: String) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for item in room["items"]:
		if not _role_can_pick_up_item(role, item):
			continue
		var distance := (item["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= PICKUP_DISTANCE and distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	if nearest.is_empty():
		_push_log("%s附近没有可拾取物品。" % _role_name(role))
		return
	var is_world_tool := str(nearest.get("kind", "")) == "tool"
	var is_trap_tool := (
		str(nearest.get("kind", "")) == "device"
		and str(nearest.get("device_type", "")) == "trap"
		and str(nearest.get("state", "")) == "recoverable"
	)
	if is_world_tool or is_trap_tool:
		var inventory: Array = tool_inventories[role]
		if inventory.size() >= TOOL_INVENTORY_CAPACITY:
			_push_log("%s的3格道具栏已满。" % _role_name(role))
			return
		var tool_type := "trap" if is_trap_tool else str(nearest["tool_type"])
		if role == "monster" and tool_type == "teleporter":
			_push_log("传送器只能由盗贼使用。")
			return
		var carried := _make_tool_instance(tool_type, str(nearest["id"]))
		if tool_type == "detector":
			carried["charge"] = float(nearest.get("charge", DETECTOR_BATTERY_SECONDS))
		inventory.append(carried)
		tool_selected[role] = inventory.size() - 1
		nearest["collected"] = true
		_add_noise(role, "拾取道具")
		if role == "thief":
			_reveal_thief()
		_push_log("%s拾取了%s（%d/3）。" % [_role_name(role), carried["label"], inventory.size()])
		return
	if role != "thief":
		return
	nearest["collected"] = true
	if str(nearest["kind"]) in ["treasure", "trinket"]:
		loot_value += int(nearest["value"])
		_push_log("盗贼携带%s，身上价值 %d。" % [nearest["label"], loot_value])
	else:
		pills += 1
		_push_log("盗贼捡到一颗治疗药丸。")
	_add_noise("thief", "拾取物品")
	_reveal_thief()


func _role_can_pick_up_item(role: String, item: Dictionary) -> bool:
	if bool(item.get("collected", false)):
		return false
	var is_tool := str(item.get("kind", "")) == "tool"
	var is_recovered_trap := (
		str(item.get("kind", "")) == "device"
		and str(item.get("device_type", "")) == "trap"
		and str(item.get("state", "")) == "recoverable"
	)
	var is_loot := str(item.get("kind", "")) in ["treasure", "trinket", "pill"]
	if role == "monster" and not (is_tool or is_recovered_trap):
		return false
	if role == "thief" and not (is_tool or is_recovered_trap or is_loot):
		return false
	if role == "monster" and str(item.get("tool_type", "")) == "teleporter":
		return false
	return true


func _nearby_tool_for_panel(role: String) -> Dictionary:
	var actor := _get_actor(role)
	if actor.is_empty():
		return {}
	var room := _room_at(actor["room"])
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for item in room["items"]:
		if bool(item.get("collected", false)):
			continue
		var kind := str(item.get("kind", ""))
		var device_type := str(item.get("device_type", ""))
		if kind != "tool" and (kind != "device" or device_type == "decoy"):
			continue
		var tool_type := str(item.get("tool_type", device_type))
		if not TOOL_DEFS.has(tool_type):
			continue
		var distance := (item["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= TOOL_INSPECT_DISTANCE and distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	if nearest.is_empty():
		return {}
	return {"item": nearest, "distance": nearest_distance}


func _thief_search() -> void:
	_pick_up_nearby("thief")


func _use_selected_tool(role: String) -> void:
	if phase == "ended" or phase == "ready" or (phase == "hide" and role == "thief"):
		return
	if not _role_can_act(role):
		return
	if _activate_nearby_phonograph(role):
		return
	var tool := _selected_tool(role)
	if tool.is_empty():
		_push_log("%s没有可用道具。" % _role_name(role))
		return
	match str(tool["tool_type"]):
		"detector": _toggle_detector(role, tool)
		"alarm": _place_alarm(role)
		"trap": _place_trap(role)
		"adrenaline": _use_adrenaline(role)
		"decoy": _use_decoy(role)
		"phonograph": _place_phonograph(role)
		"teleporter": _start_teleporter(role)
		"spring_glove": _use_spring_glove(role)


func _toggle_detector(role: String, tool: Dictionary) -> void:
	if float(tool.get("charge", 0.0)) <= 0.0:
		tool["active"] = false
		_push_log("藏品探测器电量已经耗尽。")
		return
	tool["active"] = not bool(tool.get("active", false))
	if bool(tool["active"]):
		tool["next_noise"] = elapsed + DETECTOR_NOISE_INTERVAL
		_push_log("%s开启探测器，本房间藏品信号开始显现。" % _role_name(role))
	else:
		_push_log("%s关闭探测器。" % _role_name(role))


func _place_alarm(role: String) -> void:
	var furniture := _nearest_intact_furniture(role)
	if furniture.is_empty():
		_push_log("必须靠近一件完好的家具才能安装警报器；本次未消耗道具。")
		return
	if _furniture_has_primary_content(furniture):
		_push_log("%s的藏品槽已经被占用。" % furniture["kind"])
		return
	furniture["contents"].append({
		"id": "alarm-%d" % next_device_id,
		"kind": "alarm",
		"label": "警报器",
		"value": 0,
		"signal_value": 3,
		"owner": role,
	})
	next_device_id += 1
	_consume_selected_tool(role)
	_add_noise(role, "安装警报器")
	if role == "thief":
		_reveal_thief()
	_push_log("%s把警报器藏进了%s。" % [_role_name(role), furniture["kind"]])


func _device_position(role: String, forward_distance := 0.42) -> Vector2:
	var actor := _get_actor(role)
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var target: Vector2 = actor["pos"] + facing.normalized() * forward_distance
	var room := _room_at(actor["room"])
	if not _position_clears_room_walls(room, target, role):
		return actor["pos"]
	for furniture in room["furniture"]:
		if not bool(furniture.get("destroyed", false)) and _actor_overlaps_furniture(target, furniture, role):
			return actor["pos"]
	return target


func _spawn_device(role: String, device_type: String, position: Vector2) -> Dictionary:
	var actor := _get_actor(role)
	var device := {
		"id": "device-%d" % next_device_id,
		"kind": "device",
		"device_type": device_type,
		"label": TOOL_DEFS[device_type]["label"],
		"value": 0,
		"owner": role,
		"pos": position,
		"collected": false,
		"created": elapsed,
		"state": "active",
	}
	next_device_id += 1
	_room_at(actor["room"])["items"].append(device)
	return device


func _place_trap(role: String) -> void:
	var device := _spawn_device(role, "trap", _device_position(role, 0.5))
	device["armed_at"] = elapsed + TRAP_ARM_DELAY
	_consume_selected_tool(role)
	_push_log("%s放置了捕兽夹，0.6秒后完成布置。" % _role_name(role))


func _use_adrenaline(role: String) -> void:
	var effects: Dictionary = status_effects[role]
	if elapsed < float(effects["fatigue_until"]):
		_push_log("%s仍受肾上腺素或疲劳影响。" % _role_name(role))
		return
	effects["adrenaline_until"] = elapsed + ADRENALINE_SECONDS
	effects["fatigue_until"] = elapsed + ADRENALINE_SECONDS + FATIGUE_SECONDS
	_consume_selected_tool(role)
	_add_noise(role, "注射肾上腺素")
	if role == "thief":
		_reveal_thief()
	_push_log("%s进入6秒双倍加速，随后疲劳3秒。" % _role_name(role))


func _use_decoy(role: String) -> void:
	var actor := _get_actor(role)
	var decoy := _spawn_device(role, "decoy", actor["pos"])
	decoy["expires"] = elapsed + DECOY_SECONDS
	decoy["character_role"] = role
	_consume_selected_tool(role)
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	_displace_actor(role, facing.normalized() * DECOY_DASH_DISTANCE)
	_add_noise(role, "替身位移")
	if role == "thief":
		_reveal_thief()
	_push_log("%s留下替身并向前位移。" % _role_name(role))


func _place_phonograph(role: String) -> void:
	var device := _spawn_device(role, "phonograph", _device_position(role, 0.45))
	device["state"] = "idle"
	_consume_selected_tool(role)
	_push_log("%s放置了留声机；靠近后再按使用键启动。" % _role_name(role))


func _activate_nearby_phonograph(role: String) -> bool:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	for item in room["items"]:
		if (
			bool(item.get("collected", false))
			or str(item.get("device_type", "")) != "phonograph"
			or str(item.get("state", "")) != "idle"
			or str(item.get("owner", "")) != role
		):
			continue
		if (item["pos"] as Vector2).distance_to(actor["pos"]) > 0.9:
			continue
		item["state"] = "playing"
		item["starts_at"] = elapsed + PHONOGRAPH_DELAY
		item["expires"] = elapsed + PHONOGRAPH_DELAY + PHONOGRAPH_SECONDS
		item["next_noise"] = elapsed + PHONOGRAPH_DELAY
		_push_log("%s启动留声机，2秒后开始播放10秒撞击声。" % _role_name(role))
		return true
	return false


func _start_teleporter(role: String) -> void:
	if role != "thief":
		_push_log("传送器只能由盗贼启动。")
		return
	if phase != "hunt" or has_extracted:
		return
	var effects: Dictionary = status_effects[role]
	if float(effects["teleport_ends"]) > elapsed:
		_push_log("传送器已经在轰鸣充能。")
		return
	effects["teleport_started"] = elapsed
	effects["teleport_ends"] = elapsed + TELEPORT_CHANNEL_SECONDS
	_consume_selected_tool(role)
	_add_noise(role, "传送器轰鸣", {}, 0.0, TELEPORT_CHANNEL_SECONDS, true)
	_reveal_thief()
	_push_log("传送器开始持续轰鸣，5秒后携带全部财物撤离。")


func _use_spring_glove(role: String) -> void:
	var actor := _get_actor(role)
	var target_role := "thief" if role == "monster" else "monster"
	var target := _get_actor(target_role)
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var vector: Vector2 = target["pos"] - actor["pos"]
	var hit_actor: bool = (
		actor["room"] == target["room"]
		and vector.length() <= SPRING_GLOVE_REACH
		and (vector.is_zero_approx() or vector.normalized().dot(facing) >= 0.5)
	)
	_consume_selected_tool(role)
	_add_noise(role, "弹簧拳套")
	if hit_actor:
		status_effects[target_role]["stunned_until"] = elapsed + SPRING_GLOVE_STUN_SECONDS
		_cancel_teleporter(target_role, "被弹簧拳套击中")
		_displace_actor(target_role, facing.normalized() * SPRING_GLOVE_KNOCKBACK)
		if target_role == "thief":
			_reveal_thief()
		_push_log("%s被击退并眩晕1秒！" % _role_name(target_role))
	elif _destroy_device_in_front(role, ["decoy", "phonograph"]):
		_push_log("弹簧拳套击碎了前方装置。")
	else:
		_push_log("%s的弹簧拳套落空并损毁。" % _role_name(role))


func _displace_actor(role: String, displacement: Vector2) -> void:
	if displacement.is_zero_approx():
		return
	var actor := _get_actor(role)
	dragging[role] = ""
	drag_mode[role] = "move"
	var old_facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var old_dir := str(actor["dir"])
	var subdivisions := maxi(1, int(ceil(displacement.length() / 0.05)))
	var step := displacement / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(step.x):
			_move_actor_axis(role, Vector2(step.x, 0))
		if not is_zero_approx(step.y):
			_move_actor_axis(role, Vector2(0, step.y))
	actor["facing"] = old_facing
	actor["dir"] = old_dir


func _handle_trap_escape_input(role: String, key: Key, physical: Key) -> bool:
	if str(trapped_by.get(role, "")) == "":
		return false
	var pressed_left := physical == KEY_A if role == "monster" else key == KEY_LEFT
	var pressed_right := physical == KEY_D if role == "monster" else key == KEY_RIGHT
	if not pressed_left and not pressed_right:
		return false
	var expects_left: bool = bool(trap_expected_left[role])
	if (expects_left and pressed_left) or (not expects_left and pressed_right):
		trap_escape_progress[role] = int(trap_escape_progress[role]) + 1
		trap_expected_left[role] = not expects_left
		_add_noise(role, "捕兽夹挣扎", {}, 0.12, 2.0, true)
		if int(trap_escape_progress[role]) >= TRAP_ESCAPE_PRESSES:
			_escape_trap(role)
	return true


func _escape_trap(role: String) -> void:
	var device_id := str(trapped_by[role])
	for room in rooms:
		for item in room["items"]:
			if str(item.get("id", "")) != device_id:
				continue
			item["state"] = "recoverable"
			item["tool_type"] = "trap"
			item["label"] = TOOL_DEFS["trap"]["label"]
			break
	trapped_by[role] = ""
	trap_escape_progress[role] = 0
	trap_expected_left[role] = true
	_push_log("%s挣脱捕兽夹，夹子现在可以被任意一方拾取。" % _role_name(role))


func _cancel_teleporter(role: String, reason: String) -> void:
	var effects: Dictionary = status_effects.get(role, {})
	if float(effects.get("teleport_ends", -1.0)) <= elapsed:
		return
	effects["teleport_started"] = -1.0
	effects["teleport_ends"] = -1.0
	_push_log("%s，%s的传送被打断。" % [reason, _role_name(role)])


func _update_tool_states(delta: float) -> void:
	for room in rooms:
		for furniture in room["furniture"]:
			furniture["detector_active"] = false
	for role in ["monster", "thief"]:
		var inventory: Array = tool_inventories[role]
		for tool in inventory:
			if str(tool.get("tool_type", "")) != "detector" or not bool(tool.get("active", false)):
				continue
			var charge := maxf(float(tool.get("charge", 0.0)) - delta, 0.0)
			tool["charge"] = charge
			if charge <= 0.0:
				tool["active"] = false
				_push_log("%s的藏品探测器电量耗尽。" % _role_name(role))
				continue
			var actor := _get_actor(role)
			for furniture in _room_at(actor["room"])["furniture"]:
				furniture["detector_active"] = true
			if elapsed >= float(tool.get("next_noise", 0.0)):
				tool["next_noise"] = elapsed + DETECTOR_NOISE_INTERVAL
				_add_noise(role, "探测器脉冲", {}, 0.0, 2.0, true)
		var effects: Dictionary = status_effects[role]
		var teleport_ends := float(effects.get("teleport_ends", -1.0))
		if teleport_ends > 0.0 and elapsed >= teleport_ends:
			effects["teleport_started"] = -1.0
			effects["teleport_ends"] = -1.0
			if role == "thief" and phase == "hunt" and not has_extracted:
				_complete_extraction("传送器")


func _update_devices() -> void:
	for room in rooms:
		for item in room["items"]:
			if bool(item.get("collected", false)) or str(item.get("kind", "")) != "device":
				continue
			match str(item.get("device_type", "")):
				"trap":
					var trap_state := str(item.get("state", ""))
					if trap_state == "sprung":
						if elapsed >= float(item.get("next_noise", 0.0)):
							item["next_noise"] = elapsed + 1.0
							_add_noise_at(
								str(item.get("trapped_role", item.get("owner", "neutral"))),
								"捕兽夹持续响动",
								room["coord"],
								item["pos"],
								0.0,
								2.0,
								true,
							)
						continue
					if trap_state != "active" or elapsed < float(item.get("armed_at", INF)):
						continue
					for role in ["monster", "thief"]:
						if str(trapped_by[role]) != "":
							continue
						var actor := _get_actor(role)
						if actor["room"] != room["coord"]:
							continue
						if (actor["pos"] as Vector2).distance_to(item["pos"]) <= TRAP_TRIGGER_RADIUS:
							item["state"] = "sprung"
							item["trapped_role"] = role
							item["next_noise"] = elapsed + 1.0
							trapped_by[role] = str(item["id"])
							trap_escape_progress[role] = 0
							trap_expected_left[role] = true
							_cancel_teleporter(role, "踩中捕兽夹")
							_add_noise_at(role, "捕兽夹触发", room["coord"], item["pos"], 0.0, 3.0, true)
							_push_log("%s踩中捕兽夹，左右键交替20次才能挣脱！" % _role_name(role))
							break
				"decoy":
					if elapsed >= float(item.get("expires", INF)):
						item["collected"] = true
				"phonograph":
					if str(item.get("state", "")) == "idle":
						continue
					if elapsed >= float(item.get("expires", INF)):
						item["collected"] = true
						_push_log("留声机播放完毕并自动粉碎。")
					elif elapsed >= float(item.get("starts_at", INF)) and elapsed >= float(item.get("next_noise", INF)):
						item["next_noise"] = elapsed + 0.9
						_add_noise_at(
							str(item.get("owner", "neutral")),
							"留声机撞击",
							room["coord"],
							item["pos"],
							0.0,
							2.0,
							true,
						)


func _destroy_device_in_front(role: String, types: Array) -> bool:
	var actor := _get_actor(role)
	var room := _room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", _direction_vector(str(actor["dir"])))
	var best: Dictionary = {}
	var best_distance := INF
	for item in room["items"]:
		if bool(item.get("collected", false)) or str(item.get("kind", "")) != "device":
			continue
		if not types.has(str(item.get("device_type", ""))):
			continue
		if str(item.get("owner", "")) == role:
			continue
		var offset: Vector2 = item["pos"] - actor["pos"]
		var distance := offset.length()
		if distance > SPRING_GLOVE_REACH or distance >= best_distance:
			continue
		if not offset.is_zero_approx() and offset.normalized().dot(facing) < 0.5:
			continue
		best = item
		best_distance = distance
	if best.is_empty():
		return false
	best["collected"] = true
	return true


func _thief_exit() -> void:
	if phase != "hunt" or has_extracted:
		return
	if thief["room"] == ENTRANCE_ROOM and (thief["pos"] as Vector2).distance_to(ENTRANCE_POS) <= 0.58:
		_complete_extraction("入口")
	else:
		_push_log("只有回到入口处才能撤离。")


func _complete_extraction(method: String) -> void:
	if has_extracted:
		return
	has_extracted = true
	extracted_value = loot_value
	phase = "ended"
	if extracted_value >= 5:
		outcome = "盗贼通过%s完成本局唯一一次撤离，带出价值 %d 的财物。" % [method, extracted_value]
	else:
		outcome = "盗贼通过%s撤离，但带出价值只有 %d，行动失败。" % [method, extracted_value]


func _use_pill() -> void:
	if phase != "hunt" or pills <= 0 or int(thief["hp"]) >= 2 or not _role_can_act("thief"):
		return
	thief["hp"] += 1
	pills -= 1
	_add_noise("thief", "使用药丸")
	_reveal_thief()
	_push_log("盗贼回复了 1 滴血。")


func _attack() -> void:
	if phase != "hunt" or elapsed < attack_until or not _role_can_act("monster"):
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
		_cancel_teleporter("thief", "受到怪物攻击")
		_reveal_thief()
		if thief["hp"] <= 0:
			phase = "ended"
			outcome = "怪物砍倒了盗贼，守住了老宅。"
		else:
			_push_log("挥砍命中！盗贼失去 1 滴血。")
	else:
		if _destroy_device_in_front("monster", ["decoy", "phonograph"]):
			_push_log("怪物击碎了前方的装置。")
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
	var room_side := minf(side_width - 18.0, panel_height - 105.0)
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
	if role == "monster" and phase == "hide":
		early_rect = Rect2(Vector2(help_rect.position.x - 126, panel.position.y + 9), Vector2(116, 28))
		_draw_button(early_rect, "提前结束藏宝", true)
	elif role == "monster":
		early_rect = Rect2()

	_draw_room(room_rect, role, room, actor)
	if role == "monster":
		_draw_storage_exchange(room_rect)
	_draw_view_minimap(room_rect, role)
	_draw_role_status(room_rect, role)
	_draw_nearby_tool_panel(room_rect, role)
	if bool(help_open[role]):
		_draw_help_overlay(room_rect, role)
	var footer := Rect2(panel.position.x, room_rect.end.y + 10, panel.size.x, panel.end.y - room_rect.end.y - 10)
	draw_rect(footer, PANEL_ALT)
	draw_line(footer.position, Vector2(footer.end.x, footer.position.y), LINE_COLOR, 1)
	_draw_toolbelt(footer, role)


func _draw_toolbelt(footer: Rect2, role: String) -> void:
	var inventory: Array = tool_inventories[role]
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	var start := footer.position + Vector2(12, 5)
	var gap := 6.0
	var slot_width := (footer.size.x - 24.0 - gap * 2.0) / 3.0
	for index in range(TOOL_INVENTORY_CAPACITY):
		var slot := Rect2(start + Vector2(index * (slot_width + gap), 0), Vector2(slot_width, 36))
		draw_rect(slot, Color("#20231f"))
		draw_rect(slot, accent if index == int(tool_selected[role]) and index < inventory.size() else LINE_COLOR, false, 1.5)
		if index >= inventory.size():
			_text_center("%d · 空" % [index + 1], slot, 9, MUTED_COLOR)
			continue
		var tool: Dictionary = inventory[index]
		var label := str(TOOL_DEFS[str(tool["tool_type"])]["short"])
		var status := ""
		if str(tool["tool_type"]) == "detector":
			status = " ON" if bool(tool.get("active", false)) else " %.0fs" % float(tool.get("charge", 0.0))
		_text_center("%d · %s%s" % [index + 1, label, status], slot, 9, TEXT_COLOR)


func _draw_role_status(room_rect: Rect2, role: String) -> void:
	var message := ""
	var color := GOLD_COLOR
	if str(trapped_by.get(role, "")) != "":
		var key_hint := "A/D" if role == "monster" else "←/→"
		message = "被捕！%s交替按压 %d / %d" % [key_hint, trap_escape_progress[role], TRAP_ESCAPE_PRESSES]
		color = MONSTER_COLOR
	else:
		var effects: Dictionary = status_effects[role]
		if elapsed < float(effects.get("stunned_until", 0.0)):
			message = "眩晕 %.1f秒" % (float(effects["stunned_until"]) - elapsed)
		elif elapsed < float(effects.get("adrenaline_until", 0.0)):
			message = "肾上腺素 2× · %.1f秒" % (float(effects["adrenaline_until"]) - elapsed)
		elif elapsed < float(effects.get("fatigue_until", 0.0)):
			message = "疲劳 0.5× · %.1f秒" % (float(effects["fatigue_until"]) - elapsed)
		elif float(effects.get("teleport_ends", -1.0)) > elapsed:
			message = "传送器轰鸣 · %.1f秒" % (float(effects["teleport_ends"]) - elapsed)
			color = Color("#68c8ff")
	if message == "":
		return
	var status_rect := Rect2(
		Vector2(room_rect.get_center().x - 150, room_rect.position.y + 14),
		Vector2(300, 32),
	)
	draw_rect(status_rect, Color(0.04, 0.045, 0.04, 0.92))
	draw_rect(status_rect, color, false, 2.0)
	_text_center(message, status_rect, 12, color)


func _draw_nearby_tool_panel(room_rect: Rect2, role: String) -> void:
	if bool(help_open[role]) or (role == "monster" and not _active_storage_furniture().is_empty()):
		return
	var nearby := _nearby_tool_for_panel(role)
	if nearby.is_empty():
		return
	var item: Dictionary = nearby["item"]
	var tool_type := str(item.get("tool_type", item.get("device_type", "")))
	var definition: Dictionary = TOOL_DEFS[tool_type]
	var accent: Color = definition["color"]
	var panel_width := minf(room_rect.size.x - 32.0, 520.0)
	var panel := Rect2(
		Vector2(room_rect.get_center().x - panel_width / 2.0, room_rect.end.y - 88.0),
		Vector2(panel_width, 70.0),
	)
	draw_rect(panel, Color(0.035, 0.04, 0.035, 0.96))
	draw_rect(panel, Color(accent, 0.9), false, 1.5)
	draw_rect(Rect2(panel.position, Vector2(5.0, panel.size.y)), accent)

	var title := str(definition["label"])
	var state := str(item.get("state", ""))
	if tool_type == "trap" and state == "recoverable":
		title += " · 可拾取"
	elif tool_type == "phonograph" and state == "idle":
		title += " · 待启动"
	elif tool_type == "phonograph" and state == "playing":
		title += " · 播放中"
	_text(title, panel.position + Vector2(17, 25), 14, TEXT_COLOR)
	_text(str(definition["description"]), panel.position + Vector2(17, 51), 10, MUTED_COLOR)

	var hint := "已布置"
	var distance := float(nearby["distance"])
	if _role_can_pick_up_item(role, item):
		if distance > PICKUP_DISTANCE:
			hint = "继续靠近"
		elif str(item.get("kind", "")) in ["tool", "device"] and tool_inventories[role].size() >= TOOL_INVENTORY_CAPACITY:
			hint = "道具栏已满"
		else:
			hint = "R 拾取" if role == "monster" else "Num1 拾取"
	elif tool_type == "teleporter" and role == "monster":
		hint = "仅盗贼可用"
	elif tool_type == "phonograph" and state == "idle" and str(item.get("owner", "")) == role:
		hint = "F 启动" if role == "monster" else "Num3 启动"
	_text_right(hint, panel.position + Vector2(panel.size.x - 15, 25), 10, accent)


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
	_draw_minimap(map_rect, role)
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
		+ "· 真实藏品不会自行晃动；探测器开启后才按价值显示信号。\n\n"
		+ "· 每人最多携带3件道具；部分道具藏在家具内部。\n\n"
		+ "· 警报器只能靠近完好家具安装；全图噪音会暴露方向。\n\n"
		+ "· 捕兽夹需左右键严格交替20次挣脱；传送器轰鸣5秒后撤离。"
	)
	_multiline(rules, card.position + Vector2(34, 78), card.size.x - 68, 11, MUTED_COLOR, 19)
	var controls := ""
	if role == "monster":
		controls = (
			"WASD 移动　G 撞击　空格 攻击　R 拾取\n"
			+ "Z/X 选择道具　F 使用　Q/E 转动视角　Tab 地图\n"
			+ "H 结束藏宝　家具面板：W/S 选择　R 存取　Esc 关闭"
		)
	else:
		controls = (
			"方向键 移动　Num0 撞击　Num1 拾取　Num2 药丸\n"
			+ "Num4/6 选择道具　Num3 使用　Num5 撤离\n"
			+ "Num7/9 转动视角　按住 Num8 地图　Num+ 帮助"
		)
	var controls_title_y := minf(card.position.y + 354.0, card.end.y - 132.0)
	_text("完整键位", Vector2(card.position.x + 34, controls_title_y), 13, accent)
	_multiline(
		controls,
		Vector2(card.position.x + 34, controls_title_y + 28),
		card.size.x - 68,
		11,
		TEXT_COLOR,
		20,
	)
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
		elif content["kind"] == "alarm":
			stored_treasure = "警报器 · 假藏品信号"
		elif content["kind"] == "tool":
			trinket_names.append("道具：%s" % content["label"])
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
		if view_texture:
			draw_texture_rect(view_texture, rect, false)
		else:
			draw_rect(rect, FLOOR_DARK)
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
		if room_distance >= 3 and not bool(noise.get("global", false)):
			continue
		var source_global: Vector2 = Vector2(noise["room"]) * ROOM_SIZE + (noise["pos"] as Vector2)
		var angle: float = actor_global.angle_to_point(source_global)
		if world_25d:
			var source_normalized: Vector2 = world_25d.project_normalized(
				role,
				noise["room"],
				noise["pos"],
				0.55,
			)
			var source_screen := rect.position + source_normalized * rect.size
			angle = origin.angle_to_point(source_screen)
		var color: Color = (
			MONSTER_COLOR if noise["source"] == "monster"
			else THIEF_COLOR if noise["source"] == "thief"
			else GOLD_COLOR
		)
		var duration := maxf(float(noise.get("duration", 2.0)), 0.01)
		var fade: float = clampf((float(noise["expires"]) - elapsed) / duration, 0.0, 1.0)
		for radius in [25.0, 42.0, 59.0]:
			draw_arc(origin, radius, angle - 0.58, angle + 0.58, 12, Color(color, fade), 2)


func _minimap_rotation(role: String) -> float:
	if not world_25d:
		return 0.0
	return deg_to_rad(float(world_25d.camera_yaw_degrees[role]))


func _rotate_minimap_point(point: Vector2, center: Vector2, angle: float) -> Vector2:
	return center + (point - center).rotated(angle)


func _draw_minimap(rect: Rect2, role: String) -> void:
	var angle := _minimap_rotation(role)
	var center := rect.get_center()
	var rotated_bounds_scale := absf(cos(angle)) + absf(sin(angle))
	var grid_side := minf(rect.size.x, rect.size.y) / maxf(rotated_bounds_scale, 1.0)
	var grid_rect := Rect2(center - Vector2.ONE * grid_side / 2.0, Vector2.ONE * grid_side)
	var gap := 3.0
	var cell := (grid_side - gap * (MAP_SIZE - 1)) / MAP_SIZE
	var actor: Dictionary = _get_actor(role)
	var accent := MONSTER_COLOR if role == "monster" else THIEF_COLOR
	for room in rooms:
		var coord: Vector2i = room["coord"]
		var cell_rect := Rect2(
			grid_rect.position + Vector2(coord.x, coord.y) * (cell + gap),
			Vector2(cell, cell)
		)
		var has_actor: bool = actor["room"] == coord
		var fill := accent.darkened(0.2) if has_actor else Color("#252824")
		var corners := PackedVector2Array([
			_rotate_minimap_point(cell_rect.position, center, angle),
			_rotate_minimap_point(Vector2(cell_rect.end.x, cell_rect.position.y), center, angle),
			_rotate_minimap_point(cell_rect.end, center, angle),
			_rotate_minimap_point(Vector2(cell_rect.position.x, cell_rect.end.y), center, angle),
		])
		draw_colored_polygon(corners, fill)
		for corner_index in range(corners.size()):
			draw_line(corners[corner_index], corners[(corner_index + 1) % corners.size()], Color("#4b5048"), 1)
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
			draw_line(
				_rotate_minimap_point(door_from, center, angle),
				_rotate_minimap_point(door_to, center, angle),
				TEXT_COLOR,
				2,
			)
		if has_actor:
			var marker_center := _rotate_minimap_point(cell_rect.get_center(), center, angle)
			draw_circle(marker_center, maxf(cell * 0.18, 3.5), accent)
			draw_circle(marker_center, maxf(cell * 0.18, 3.5), Color("#111311"), false, 1.0)
	var opponent_role := "thief" if role == "monster" else "monster"
	var opponent := _get_actor(opponent_role)
	var opponent_coord: Vector2i = opponent["room"]
	var opponent_center := grid_rect.position + Vector2(opponent_coord.x, opponent_coord.y) * (cell + gap) + Vector2.ONE * cell * 0.5
	opponent_center = _rotate_minimap_point(opponent_center, center, angle)
	var opponent_color := THIEF_COLOR if opponent_role == "thief" else MONSTER_COLOR
	draw_circle(opponent_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), opponent_color)
	draw_circle(opponent_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), Color("#111311"), false, 1.0)
	for room in rooms:
		for item in room["items"]:
			if (
				bool(item.get("collected", false))
				or str(item.get("device_type", "")) != "decoy"
				or str(item.get("owner", "")) == role
			):
				continue
			var decoy_coord: Vector2i = room["coord"]
			var decoy_center := grid_rect.position + Vector2(decoy_coord.x, decoy_coord.y) * (cell + gap) + Vector2.ONE * cell * 0.5
			decoy_center = _rotate_minimap_point(decoy_center, center, angle)
			var decoy_color := THIEF_COLOR if str(item.get("owner", "")) == "thief" else MONSTER_COLOR
			draw_circle(decoy_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), decoy_color)
			draw_circle(decoy_center + Vector2(2, -2), maxf(cell * 0.14, 3.0), Color("#111311"), false, 1.0)


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
