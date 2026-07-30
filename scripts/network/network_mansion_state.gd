class_name NetworkMansionState
extends RefCounted

const ROOM_SYSTEM_SCRIPT := preload("res://scripts/systems/room_system.gd")
const GAMEPLAY_STATE_FACTORY := preload("res://scripts/state/gameplay_state_factory.gd")
const MANSION_COLLISION := preload("res://scripts/state/mansion_collision.gd")
const GAME_STATE_BASE := preload("res://scripts/systems/game_state_base.gd")
const NETWORK_TOOL_CATALOG := preload("res://scripts/network/network_tool_catalog.gd")

const MAP_SIZE := 6
const ROOM_SIZE := 5.0
const ACTOR_SPEED := 4.0
const HIDE_SECONDS := 180
const READY_SECONDS := 5
const HUNT_SECONDS := 8 * 60
const ENTRANCE_ROOM := Vector2i(0, 5)
const MONSTER_SPAWN_ROOM := Vector2i(5, 0)
const MONSTER_SPAWN_POS := Vector2(4.5, 0.5)
const FURNITURE_HIT_REACH := 1.35
const FURNITURE_HIT_DOT := 0.62
const STORAGE_REACH := 1.65
const FURNITURE_ACTION_COOLDOWN := 0.42
const PICKUP_DISTANCE := 0.64
const EXTRACTION_DISTANCE := 0.58
const ENTRANCE_POS := Vector2(0.5, 4.5)
const THIEF_HIDE_DELAY := 0.8
const THIEF_REVEAL_SECONDS := 1.0
const DEFAULT_NOISE_SECONDS := 2.0
const MAX_HP := 2
const MONSTER_ATTACK_RANGE := 2.35
const MONSTER_ATTACK_HALF_ANGLE := PI / 4.0
const MONSTER_ATTACK_COOLDOWN := 1.0
const MONSTER_ATTACK_HIT_STUN_SECONDS := 0.8
const REVIVE_DISTANCE := 1.15
const REVIVE_SECONDS := 2.5
const REVIVE_HIT_STUN_SECONDS := 0.45
const REVIVE_INVULNERABLE_SECONDS := 1.25
const TOOL_INVENTORY_CAPACITY := GAME_STATE_BASE.TOOL_INVENTORY_CAPACITY
const TRAP_TRIGGER_RADIUS := GAME_STATE_BASE.TRAP_TRIGGER_RADIUS
const TRAP_ARM_DELAY := GAME_STATE_BASE.TRAP_ARM_DELAY
const TRAP_ESCAPE_PRESSES := GAME_STATE_BASE.TRAP_ESCAPE_PRESSES
const ADRENALINE_SECONDS := GAME_STATE_BASE.ADRENALINE_SECONDS
const FATIGUE_SECONDS := GAME_STATE_BASE.FATIGUE_SECONDS
const DECOY_SECONDS := GAME_STATE_BASE.DECOY_SECONDS
const DECOY_SPEED := GAME_STATE_BASE.DECOY_SPEED
const DECOY_DASH_DISTANCE := GAME_STATE_BASE.DECOY_DASH_DISTANCE
const PHONOGRAPH_DELAY := GAME_STATE_BASE.PHONOGRAPH_DELAY
const PHONOGRAPH_SECONDS := GAME_STATE_BASE.PHONOGRAPH_SECONDS
const PHONOGRAPH_REACH := 0.9
const DEVICE_RECORD_SIZE := 16
const DETECTOR_BATTERY_SECONDS := GAME_STATE_BASE.DETECTOR_BATTERY_SECONDS
const DETECTOR_NOISE_INTERVAL := GAME_STATE_BASE.DETECTOR_NOISE_INTERVAL
const TELEPORT_CHANNEL_SECONDS := GAME_STATE_BASE.TELEPORT_CHANNEL_SECONDS
const SPRING_GLOVE_REACH := GAME_STATE_BASE.SPRING_GLOVE_REACH
const SPRING_GLOVE_KNOCKBACK := GAME_STATE_BASE.SPRING_GLOVE_KNOCKBACK
const SPRING_GLOVE_STUN_SECONDS := GAME_STATE_BASE.SPRING_GLOVE_STUN_SECONDS
const ROBOT_SPEED := GAME_STATE_BASE.ROBOT_SPEED
const ROBOT_STUN_SECONDS := GAME_STATE_BASE.ROBOT_STUN_SECONDS
const ROBOT_ALARM_SECONDS := GAME_STATE_BASE.ROBOT_ALARM_SECONDS
const ROBOT_ALARM_COOLDOWN := GAME_STATE_BASE.ROBOT_ALARM_COOLDOWN
const ROBOT_TURN_SECONDS := 1.4
const TOOL_INVENTORY_RECORD_STRIDE := 5

var world_seed := 0
var rooms: Array = []
var actors: Dictionary = {}
var active_storage_by_peer: Dictionary = {}
var last_furniture_action_at: Dictionary = {}
var noises: Array = []
var pending_world_events: Array = []
var next_noise_id := 1
var next_device_id := 1
var rng := RandomNumberGenerator.new()
var phase := "hide"
var seconds_left := HIDE_SECONDS
var phase_clock := 0.0
var elapsed := 0.0
var debug_combat_spawns := false
var debug_tool_loadouts := false


func initialize(seed_value: int, players: Dictionary) -> void:
	world_seed = seed_value
	rng.seed = world_seed ^ 0x5A17
	var generator: RoomSystem = ROOM_SYSTEM_SCRIPT.new()
	generator.rng.seed = world_seed
	generator.current_round = 1
	rooms = generator._generate_rooms()
	generator.free()
	actors.clear()
	active_storage_by_peer.clear()
	last_furniture_action_at.clear()
	noises.clear()
	pending_world_events.clear()
	next_noise_id = 1
	next_device_id = 1
	phase = "hide"
	seconds_left = HIDE_SECONDS
	phase_clock = 0.0
	elapsed = 0.0
	sync_players(players)


func sync_players(players: Dictionary) -> void:
	var live_ids: Dictionary = {}
	for peer_id_variant in players:
		var peer_id := int(peer_id_variant)
		var player: Dictionary = players[peer_id_variant]
		var slot := str(player.get("slot", "spectator"))
		if slot == "spectator":
			continue
		live_ids[peer_id] = true
		if actors.has(peer_id):
			var existing: Dictionary = actors[peer_id]
			existing["name"] = str(player.get("name", "玩家"))
			existing["slot"] = slot
			actors[peer_id] = existing
			continue
		actors[peer_id] = _make_actor(peer_id, player)
	for peer_id_variant in actors.keys():
		var peer_id := int(peer_id_variant)
		if not live_ids.has(peer_id):
			actors.erase(peer_id)
			active_storage_by_peer.erase(peer_id)
			last_furniture_action_at.erase(peer_id)


func step(
	delta: float,
	inputs: Dictionary,
	rescue_inputs: Dictionary = {},
) -> void:
	elapsed += delta
	_update_phase(delta)
	for peer_id_variant in actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = actors[peer_id_variant]
		actor["moving"] = false
		var role := _role_for_slot(str(actor.get("slot", "")))
		if (
			bool(actor.get("extracted", false))
			or bool(actor.get("downed", false))
			or bool(actor.get("trapped", false))
			or elapsed < float(actor.get("hit_stun_until", 0.0))
			or phase == "ready"
			or (phase == "hide" and role == "thief")
		):
			actors[peer_id] = actor
			continue
		var input_vector: Vector2 = inputs.get(peer_id, Vector2.ZERO)
		if role == "thief" and bool(rescue_inputs.get(peer_id, false)):
			input_vector = Vector2.ZERO
		_move_actor(
			peer_id,
			actor,
			role,
			input_vector,
			delta,
			_actor_speed_multiplier(actor),
		)
		if bool(actor.get("moving", false)):
			if role == "thief":
				actor["hidden_from_monster"] = false
				actor["last_moved_at"] = elapsed
			else:
				_add_noise(peer_id, "怪物脚步", 1.2, 0.42)
		actors[peer_id] = actor
	_update_tool_states(delta)
	_update_devices(delta)
	_update_rescues(delta, rescue_inputs)
	_update_thief_stealth()
	prune_noises(elapsed)


func begin_hunt_countdown(requester_peer_id := 0) -> bool:
	if phase != "hide":
		return false
	if requester_peer_id != 0:
		if not actors.has(requester_peer_id):
			return false
		var requester: Dictionary = actors[requester_peer_id]
		if _role_for_slot(str(requester.get("slot", ""))) != "monster":
			return false
	phase = "ready"
	seconds_left = READY_SECONDS
	phase_clock = 0.0
	active_storage_by_peer.clear()
	_respawn_all()
	return true


func interact_furniture(peer_id: int) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	if (
		elapsed - float(last_furniture_action_at.get(peer_id, -100.0))
		< FURNITURE_ACTION_COOLDOWN
	):
		return _rejected_event(peer_id, "动作尚未结束。")
	var actor: Dictionary = actors[peer_id]
	var role := _role_for_slot(str(actor.get("slot", "")))
	if bool(actor.get("extracted", false)):
		return _rejected_event(peer_id, "你已经撤离宅邸。")
	if bool(actor.get("downed", false)):
		return _rejected_event(peer_id, "倒地状态无法交互。")
	if bool(actor.get("trapped", false)):
		return _rejected_event(peer_id, "被捕兽夹困住时无法交互。")
	if elapsed < float(actor.get("hit_stun_until", 0.0)):
		return _rejected_event(peer_id, "受击硬直中，暂时无法交互。")
	var robot_entry := _enemy_robot_in_front(peer_id, actor)
	if not robot_entry.is_empty():
		return _stun_robot(peer_id, actor, robot_entry)
	if role == "monster" and phase != "hide":
		return _rejected_event(peer_id, "怪物只能在藏匿阶段打开家具。")
	if role == "thief" and phase != "hunt":
		return _rejected_event(peer_id, "盗贼要等狩猎开始后才能破坏家具。")
	var furniture := _furniture_in_front(actor)
	if furniture.is_empty():
		return _rejected_event(peer_id, "面前没有可交互的家具。")
	if bool(furniture.get("destroyed", false)):
		return _rejected_event(peer_id, "这件家具已经损毁。")

	var room_coord: Vector2i = actor["room"]
	var room := room_at(room_coord)
	last_furniture_action_at[peer_id] = elapsed
	furniture["last_hit_time"] = elapsed
	_add_noise(peer_id, "撞击家具")
	if role == "thief":
		_reveal_thief(actor)
	var released_items: Array = []
	var message := ""
	if role == "monster":
		var was_open := bool(furniture.get("opened", false))
		furniture["opened"] = true
		var monster_alarm_triggered := _trigger_furniture_alarm(room, furniture)
		active_storage_by_peer[peer_id] = str(furniture["id"])
		message = (
			"%s已打开，可用 A / D 选择藏品、R 存取。"
			% str(furniture.get("kind", "家具"))
			if was_open
			else "打开了%s，可用 A / D 选择藏品、R 存取。"
			% str(furniture.get("kind", "家具"))
		)
		if monster_alarm_triggered:
			message += " 家具内的警报器已触发！"
	else:
		_refresh_furniture_durability(furniture)
		furniture["damage"] = int(furniture.get("damage", 0)) + 1
		var durability := int(furniture.get("durability", 1))
		if int(furniture["damage"]) >= durability:
			furniture["damage"] = durability
			furniture["destroyed"] = true
			furniture["opened"] = true
			var thief_alarm_triggered := _trigger_furniture_alarm(room, furniture)
			released_items = _release_furniture_contents(room, furniture)
			message = "砸毁了%s，掉出 %d 件物品。" % [
				str(furniture.get("kind", "家具")),
				released_items.size(),
			]
			if thief_alarm_triggered:
				message += " 警报器已触发！"
		else:
			message = "%s损毁度 %d / %d。" % [
				str(furniture.get("kind", "家具")),
				int(furniture["damage"]),
				durability,
			]
	return _furniture_event(
		peer_id,
		room_coord,
		furniture,
		released_items,
		message,
		str(active_storage_by_peer.get(peer_id, "")),
		true,
	)


func pick_up_item(peer_id: int) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	var actor: Dictionary = actors[peer_id]
	var role := _role_for_slot(str(actor.get("slot", "")))
	if phase != "hunt":
		return _rejected_event(peer_id, "狩猎开始后才能拾取物品。")
	if bool(actor.get("extracted", false)):
		return _rejected_event(peer_id, "你已经撤离宅邸。")
	if bool(actor.get("downed", false)):
		return _rejected_event(peer_id, "倒地状态无法拾取物品。")
	if bool(actor.get("trapped", false)):
		return _rejected_event(peer_id, "被捕兽夹困住时无法拾取物品。")
	if elapsed < float(actor.get("hit_stun_until", 0.0)):
		return _rejected_event(peer_id, "受击硬直中，暂时无法拾取。")
	var room_coord: Vector2i = actor["room"]
	var room := room_at(room_coord)
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for item_variant in room["items"]:
		var item: Dictionary = item_variant
		if not _actor_can_pick_up_item(actor, item):
			continue
		var distance := (item["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= PICKUP_DISTANCE and distance < nearest_distance:
			nearest = item
			nearest_distance = distance
	if nearest.is_empty():
		return _rejected_event(peer_id, "附近没有可拾取的物品。")

	nearest["collected"] = true
	_reveal_thief(actor)
	_add_noise(peer_id, "拾取物品", 1.6)
	var item_copy: Dictionary = nearest.duplicate(true)
	var item_kind := str(nearest.get("kind", ""))
	var message := ""
	if item_kind == "tool" or (
		item_kind == "device"
		and str(nearest.get("device_type", "")) == "trap"
		and str(nearest.get("state", "")) == "recoverable"
	):
		var tool_type := str(nearest.get(
			"tool_type",
			nearest.get("device_type", ""),
		))
		var tools: Array = actor.get("tools", [])
		tools.append(_make_network_tool(tool_type, str(nearest["id"])))
		actor["tool_selected"] = tools.size() - 1
		message = "拾取了%s，装备栏 %d / %d。" % [
			str(nearest.get("label", "道具")),
			tools.size(),
			TOOL_INVENTORY_CAPACITY,
		]
	elif item_kind in ["treasure", "trinket"]:
		if role != "thief":
			nearest["collected"] = false
			return _rejected_event(peer_id, "怪物不能拾取财物。")
		var carried_loot: Array = actor["carried_loot"]
		carried_loot.append(item_copy)
		actor["carried_value"] = (
			int(actor.get("carried_value", 0))
			+ int(nearest.get("value", 0))
		)
		message = "拾取了%s，当前携带价值 %d。" % [
			str(nearest.get("label", "财物")),
			int(actor["carried_value"]),
		]
	else:
		actor["pills"] = int(actor.get("pills", 0)) + 1
		message = "拾取了%s，当前携带 %d 颗。" % [
			str(nearest.get("label", "药丸")),
			int(actor["pills"]),
		]
	actors[peer_id] = actor
	return {
		"accepted": true,
		"kind": "item",
		"requester_peer_id": peer_id,
		"room": room_coord,
		"item_id": str(nearest["id"]),
		"actor": _tool_actor_mutation(peer_id, actor),
		"message": message,
	}


func extract_thief(peer_id: int) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	var actor: Dictionary = actors[peer_id]
	if _role_for_slot(str(actor.get("slot", ""))) != "thief":
		return _rejected_event(peer_id, "怪物不能从入口撤离。")
	if phase != "hunt":
		return _rejected_event(peer_id, "狩猎开始后才能撤离。")
	if bool(actor.get("extracted", false)):
		return _rejected_event(peer_id, "你已经撤离宅邸。")
	if bool(actor.get("downed", false)):
		return _rejected_event(peer_id, "倒地状态无法撤离。")
	if elapsed < float(actor.get("hit_stun_until", 0.0)):
		return _rejected_event(peer_id, "受击硬直中，暂时无法撤离。")
	if (
		actor["room"] != ENTRANCE_ROOM
		or (actor["pos"] as Vector2).distance_to(ENTRANCE_POS) > EXTRACTION_DISTANCE
	):
		return _rejected_event(peer_id, "只有回到入口处才能撤离。")

	var carried_loot: Array = actor.get("carried_loot", [])
	actor["extracted_loot"] = carried_loot.duplicate(true)
	carried_loot.clear()
	actor["extracted_value"] = int(actor.get("carried_value", 0))
	actor["carried_value"] = 0
	actor["extracted"] = true
	actor["moving"] = false
	actors[peer_id] = actor
	return {
		"accepted": true,
		"kind": "extraction",
		"requester_peer_id": peer_id,
		"message": "撤离成功，本次带出价值 %d 的财物；其他玩家仍可继续行动。"
		% int(actor["extracted_value"]),
	}


func toggle_treasure(peer_id: int, treasure_index: int) -> Dictionary:
	if phase != "hide" or not actors.has(peer_id):
		return _rejected_event(peer_id, "当前不能存取藏品。")
	var actor: Dictionary = actors[peer_id]
	if _role_for_slot(str(actor.get("slot", ""))) != "monster":
		return _rejected_event(peer_id, "只有怪物能在藏匿阶段放置藏品。")
	if elapsed < float(actor.get("hit_stun_until", 0.0)):
		return _rejected_event(peer_id, "受击硬直中，暂时无法操作。")
	if treasure_index < 0 or treasure_index >= GAME_STATE_BASE.TREASURES.size():
		return _rejected_event(peer_id, "无效的藏品选择。")
	var furniture := _active_storage_furniture(peer_id)
	if furniture.is_empty():
		active_storage_by_peer.erase(peer_id)
		return _rejected_event(peer_id, "请先面向家具按 G 打开它。")

	var treasure: Dictionary = GAME_STATE_BASE.TREASURES[treasure_index]
	var contents: Array = furniture["contents"]
	var message := ""
	for index in range(contents.size()):
		var content: Dictionary = contents[index]
		if str(content.get("id", "")) != str(treasure["id"]):
			continue
		contents.remove_at(index)
		_refresh_furniture_durability(furniture)
		message = "已从%s取出%s。" % [furniture["kind"], treasure["label"]]
		return _furniture_event(
			peer_id,
			actor["room"],
			furniture,
			[],
			message,
			str(furniture["id"]),
		)

	if _furniture_has_primary_content(furniture):
		return _rejected_event(peer_id, "%s的藏品槽已被占用。" % furniture["kind"])
	if _treasure_is_deployed(str(treasure["id"])):
		return _rejected_event(peer_id, "%s已存放在其他位置。" % treasure["label"])
	contents.append(treasure.duplicate(true))
	_refresh_furniture_durability(furniture)
	message = "已将%s存入%s（价值 %d）。" % [
		treasure["label"],
		furniture["kind"],
		int(treasure["value"]),
	]
	return _furniture_event(
		peer_id,
		actor["room"],
		furniture,
		[],
		message,
		str(furniture["id"]),
	)


func attack(peer_id: int) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	var attacker: Dictionary = actors[peer_id]
	if _role_for_slot(str(attacker.get("slot", ""))) != "monster":
		return _rejected_event(peer_id, "只有怪物能够发动横扫。")
	if phase != "hunt":
		return _rejected_event(peer_id, "狩猎开始后才能攻击。")
	if bool(attacker.get("extracted", false)) or bool(attacker.get("downed", false)):
		return _rejected_event(peer_id, "当前状态无法攻击。")
	if bool(attacker.get("trapped", false)):
		return _rejected_event(peer_id, "被捕兽夹困住时无法攻击。")
	if elapsed < float(attacker.get("hit_stun_until", 0.0)):
		return _rejected_event(peer_id, "硬直状态无法攻击。")
	if elapsed < float(attacker.get("attack_ready_at", 0.0)):
		return _rejected_event(
			peer_id,
			"横扫冷却 %.1f 秒。"
			% (float(attacker["attack_ready_at"]) - elapsed),
		)

	var facing: Vector2 = attacker.get("facing", Vector2.LEFT)
	if facing.is_zero_approx():
		facing = Vector2.LEFT
	facing = facing.normalized()
	attacker["attack_started_at"] = elapsed
	attacker["attack_ready_at"] = elapsed + MONSTER_ATTACK_COOLDOWN
	actors[peer_id] = attacker
	_add_noise(peer_id, "挥砍")

	var hit_targets: Array = []
	var downed_targets: Array[int] = []
	var target_peer_ids := actors.keys()
	target_peer_ids.sort()
	for target_peer_id_variant in target_peer_ids:
		var target_peer_id := int(target_peer_id_variant)
		if target_peer_id == peer_id:
			continue
		var target: Dictionary = actors[target_peer_id_variant]
		if (
			_role_for_slot(str(target.get("slot", ""))) != "thief"
			or bool(target.get("extracted", false))
			or bool(target.get("downed", false))
			or elapsed < float(target.get("hit_invulnerable_until", 0.0))
			or target.get("room", Vector2i(-1, -1)) != attacker["room"]
		):
			continue
		var offset: Vector2 = (target["pos"] as Vector2) - (attacker["pos"] as Vector2)
		var distance := offset.length()
		var facing_dot := 1.0 if distance <= 0.001 else offset.normalized().dot(facing)
		if (
			distance > MONSTER_ATTACK_RANGE
			or facing_dot < cos(MONSTER_ATTACK_HALF_ANGLE)
		):
			continue
		target["hp"] = maxi(int(target.get("hp", MAX_HP)) - 1, 0)
		target["moving"] = false
		target["hit_stun_until"] = elapsed + MONSTER_ATTACK_HIT_STUN_SECONDS
		target["hit_reaction_started_at"] = elapsed
		target["hit_reaction_direction"] = facing
		target["rescue_progress"] = 0.0
		target["being_revived"] = false
		_cancel_teleporter(target)
		_reveal_thief(target)
		if int(target["hp"]) <= 0:
			target["downed"] = true
			target["hidden_from_monster"] = false
			downed_targets.append(target_peer_id)
		actors[target_peer_id] = target
		hit_targets.append(_combat_actor_mutation(target_peer_id, target))

	var message := (
		"横扫命中 %d 名盗贼，其中 %d 名倒地。"
		% [hit_targets.size(), downed_targets.size()]
		if not hit_targets.is_empty()
		else "横扫落空。"
	)
	return {
		"accepted": true,
		"kind": "combat",
		"combat_type": "attack",
		"requester_peer_id": peer_id,
		"attacker_peer_id": peer_id,
		"attack_started_at": elapsed,
		"attack_facing": facing,
		"targets": hit_targets,
		"downed_peer_ids": downed_targets,
		"message": message,
	}


func cycle_tool(peer_id: int, direction: int) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	var actor: Dictionary = actors[peer_id]
	var tools: Array = actor.get("tools", [])
	if tools.is_empty():
		return _rejected_event(peer_id, "装备栏中没有道具。")
	actor["tool_selected"] = posmod(
		int(actor.get("tool_selected", 0)) + signi(direction),
		tools.size(),
	)
	actors[peer_id] = actor
	var selected: Dictionary = tools[int(actor["tool_selected"])]
	return _tool_event(
		peer_id,
		"selection",
		actor,
		[],
		"已选择%s。" % str(selected.get("label", "道具")),
	)


func use_selected_tool(peer_id: int) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	var actor: Dictionary = actors[peer_id]
	var role := _role_for_slot(str(actor.get("slot", "")))
	if (
		bool(actor.get("extracted", false))
		or bool(actor.get("downed", false))
		or bool(actor.get("trapped", false))
		or elapsed < float(actor.get("hit_stun_until", 0.0))
	):
		return _rejected_event(peer_id, "当前状态无法使用道具。")
	if phase == "ready" or (phase == "hide" and role == "thief"):
		return _rejected_event(peer_id, "当前阶段无法使用道具。")
	var nearby_phonograph := _nearby_owned_phonograph(peer_id, actor)
	if not nearby_phonograph.is_empty():
		var phonograph: Dictionary = nearby_phonograph["item"]
		phonograph["state"] = "playing"
		phonograph["starts_at"] = elapsed + PHONOGRAPH_DELAY
		phonograph["expires"] = elapsed + PHONOGRAPH_DELAY + PHONOGRAPH_SECONDS
		phonograph["next_noise"] = phonograph["starts_at"]
		return _tool_event(
			peer_id,
			"phonograph_started",
			actor,
			[_device_mutation(nearby_phonograph["room"], phonograph)],
			"留声机将在 %.0f 秒后播放，并持续 %.0f 秒。"
			% [PHONOGRAPH_DELAY, PHONOGRAPH_SECONDS],
		)
	var tools: Array = actor.get("tools", [])
	if tools.is_empty():
		return _rejected_event(peer_id, "装备栏中没有可用道具。")
	var selected := clampi(int(actor.get("tool_selected", 0)), 0, tools.size() - 1)
	actor["tool_selected"] = selected
	var tool: Dictionary = tools[selected]
	var tool_type := str(tool.get("tool_type", ""))
	if not NETWORK_TOOL_CATALOG.supports(tool_type):
		return _rejected_event(peer_id, "该道具尚未迁移到联机模式。")
	match tool_type:
		"adrenaline":
			if elapsed < float(actor.get("fatigue_until", 0.0)):
				return _rejected_event(peer_id, "肾上腺素或疲劳效果尚未结束。")
			actor["adrenaline_until"] = elapsed + ADRENALINE_SECONDS
			actor["fatigue_until"] = (
				elapsed + ADRENALINE_SECONDS + FATIGUE_SECONDS
			)
			_consume_selected_tool(actor)
			_reveal_if_thief(actor)
			actors[peer_id] = actor
			_add_noise(peer_id, "注射肾上腺素")
			return _tool_event(
				peer_id,
				"adrenaline",
				actor,
				[],
				"肾上腺素：%.0f 秒双倍速度，随后 %.0f 秒疲劳。"
				% [ADRENALINE_SECONDS, FATIGUE_SECONDS],
			)
		"decoy":
			var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
			if facing.is_zero_approx():
				facing = Vector2.RIGHT
			facing = facing.normalized()
			var decoy := _spawn_device(
				peer_id,
				actor,
				"decoy",
				actor["pos"],
			)
			decoy["expires"] = elapsed + DECOY_SECONDS
			decoy["character_role"] = role
			decoy["move_direction"] = -facing
			_move_actor(
				peer_id,
				actor,
				role,
				facing,
				DECOY_DASH_DISTANCE / ACTOR_SPEED,
			)
			_consume_selected_tool(actor)
			_reveal_if_thief(actor)
			actors[peer_id] = actor
			_add_noise(peer_id, "替身位移")
			return _tool_event(
				peer_id,
				"decoy",
				actor,
				[_device_mutation(room_at(decoy["room"]), decoy)],
				"本体向前位移，替身将沿反方向奔跑 %.0f 秒。"
				% DECOY_SECONDS,
			)
		"phonograph":
			var phonograph := _spawn_device(
				peer_id,
				actor,
				"phonograph",
				_device_position(actor, role, 0.45),
			)
			phonograph["state"] = "idle"
			_consume_selected_tool(actor)
			_reveal_if_thief(actor)
			actors[peer_id] = actor
			return _tool_event(
				peer_id,
				"phonograph_placed",
				actor,
				[_device_mutation(room_at(phonograph["room"]), phonograph)],
				"已放置留声机；靠近后再次按 C 启动。",
			)
		"trap":
			var trap := _spawn_device(
				peer_id,
				actor,
				"trap",
				_device_position(actor, role, 0.5),
			)
			trap["armed_at"] = elapsed + TRAP_ARM_DELAY
			_consume_selected_tool(actor)
			_reveal_if_thief(actor)
			actors[peer_id] = actor
			return _tool_event(
				peer_id,
				"trap_placed",
				actor,
				[_device_mutation(room_at(trap["room"]), trap)],
				"已放置捕兽夹，%.1f 秒后启用。" % TRAP_ARM_DELAY,
			)
		"detector":
			if float(tool.get("charge", 0.0)) <= 0.0:
				tool["active"] = false
				return _rejected_event(peer_id, "藏品探测器电量已经耗尽。")
			tool["active"] = not bool(tool.get("active", false))
			if bool(tool["active"]):
				tool["next_noise"] = elapsed + DETECTOR_NOISE_INTERVAL
			actors[peer_id] = actor
			return _tool_event(
				peer_id,
				"detector",
				actor,
				[],
				"已%s藏品探测器，剩余电量 %.1f 秒。"
				% [
					"开启" if bool(tool["active"]) else "关闭",
					float(tool.get("charge", 0.0)),
				],
			)
		"alarm":
			return _install_alarm(peer_id, actor, tool)
		"teleporter":
			if role != "thief":
				return _rejected_event(peer_id, "传送器只能由盗贼启动。")
			if phase != "hunt":
				return _rejected_event(peer_id, "狩猎开始后才能启动传送器。")
			if float(actor.get("teleport_ends", -1.0)) > elapsed:
				return _rejected_event(peer_id, "传送器已经在轰鸣充能。")
			actor["teleport_started"] = elapsed
			actor["teleport_ends"] = elapsed + TELEPORT_CHANNEL_SECONDS
			_consume_selected_tool(actor)
			_reveal_thief(actor)
			actors[peer_id] = actor
			_add_noise(peer_id, "传送器轰鸣", TELEPORT_CHANNEL_SECONDS)
			return _tool_event(
				peer_id,
				"teleporter",
				actor,
				[],
				"传送器开始持续轰鸣，%.0f 秒后携带财物撤离。"
				% TELEPORT_CHANNEL_SECONDS,
			)
		"spring_glove":
			return _use_spring_glove(peer_id, actor, tool)
		"robot":
			return _use_robot(peer_id, actor, tool)
	return _rejected_event(peer_id, "该道具尚未迁移到联机模式。")


func escape_trap(peer_id: int, pressed_left: bool) -> Dictionary:
	if not actors.has(peer_id):
		return _rejected_event(peer_id, "玩家不在本局中。")
	var actor: Dictionary = actors[peer_id]
	var device_id := str(actor.get("trapped_by", ""))
	if device_id.is_empty() or not bool(actor.get("trapped", false)):
		return _rejected_event(peer_id, "当前没有被捕兽夹困住。")
	var expects_left := bool(actor.get("trap_expected_left", true))
	if pressed_left != expects_left:
		return _rejected_event(peer_id, "必须严格左右交替挣脱。")
	actor["trap_escape_progress"] = (
		int(actor.get("trap_escape_progress", 0)) + 1
	)
	actor["trap_expected_left"] = not expects_left
	actor["trap_prompt"] = "A" if not expects_left else "D"
	var devices: Array = []
	var message := "捕兽夹挣脱 %d / %d。" % [
		int(actor["trap_escape_progress"]),
		TRAP_ESCAPE_PRESSES,
	]
	if int(actor["trap_escape_progress"]) >= TRAP_ESCAPE_PRESSES:
		var found := _find_device_entry(device_id)
		if not found.is_empty():
			var trap: Dictionary = found["item"]
			trap["state"] = "recoverable"
			trap["tool_type"] = "trap"
			trap["trapped_peer_id"] = 0
			devices.append(_device_mutation(found["room"], trap))
		actor["trapped"] = false
		actor["trapped_by"] = ""
		actor["trap_escape_progress"] = 0
		actor["trap_expected_left"] = true
		actor["trap_prompt"] = ""
		message = "已挣脱捕兽夹；夹子现在可以被任意玩家拾取。"
	actors[peer_id] = actor
	return _tool_event(
		peer_id,
		"trap_escape",
		actor,
		devices,
		message,
	)


func _install_alarm(
	peer_id: int,
	actor: Dictionary,
	_tool: Dictionary,
) -> Dictionary:
	var found := _nearest_intact_furniture(actor)
	if found.is_empty():
		return _rejected_event(
			peer_id,
			"必须靠近一件完好的家具才能安装警报器。",
		)
	var furniture: Dictionary = found["furniture"]
	if _furniture_has_primary_content(furniture):
		return _rejected_event(peer_id, "这件家具的藏品槽已被占用。")
	furniture["contents"].append({
		"id": "network-alarm-%d" % next_device_id,
		"kind": "alarm",
		"label": "警报器",
		"value": 0,
		"owner_peer_id": peer_id,
	})
	next_device_id += 1
	_consume_selected_tool(actor)
	_reveal_if_thief(actor)
	actors[peer_id] = actor
	_add_noise(peer_id, "安装警报器")
	var event := _tool_event(
		peer_id,
		"alarm_installed",
		actor,
		[],
		"已将警报器安装进%s。" % str(furniture.get("kind", "家具")),
	)
	event["room"] = actor["room"]
	event["furniture"] = _furniture_replication(furniture)
	return event


func _use_spring_glove(
	peer_id: int,
	actor: Dictionary,
	_tool: Dictionary,
) -> Dictionary:
	var role := _role_for_slot(str(actor.get("slot", "")))
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	if facing.is_zero_approx():
		facing = Vector2.RIGHT
	facing = facing.normalized()
	var target_peer_id := _enemy_actor_in_front(peer_id, actor, SPRING_GLOVE_REACH)
	_consume_selected_tool(actor)
	_reveal_if_thief(actor)
	actors[peer_id] = actor
	_add_noise(peer_id, "弹簧拳套")
	var event := _tool_event(
		peer_id,
		"spring_glove",
		actor,
		[],
		"弹簧拳套落空并损毁。",
	)
	if target_peer_id != 0:
		var target: Dictionary = actors[target_peer_id]
		var target_role := _role_for_slot(str(target.get("slot", "")))
		target["hit_stun_until"] = maxf(
			float(target.get("hit_stun_until", 0.0)),
			elapsed + SPRING_GLOVE_STUN_SECONDS,
		)
		_cancel_teleporter(target)
		_displace_actor(target_peer_id, target, target_role, facing * SPRING_GLOVE_KNOCKBACK)
		_reveal_if_thief(target)
		actors[target_peer_id] = target
		event["target_peer_id"] = target_peer_id
		event["target_actors"] = [_tool_actor_mutation(target_peer_id, target)]
		event["message"] = "%s被击退并眩晕 %.0f 秒。" % [
			str(target.get("name", "玩家")),
			SPRING_GLOVE_STUN_SECONDS,
		]
		return event
	var device_entry := _enemy_breakable_device_in_front(peer_id, actor)
	if not device_entry.is_empty():
		var device: Dictionary = device_entry["item"]
		device["collected"] = true
		event["devices"] = [_device_mutation(device_entry["room"], device)]
		event["message"] = "弹簧拳套击碎了前方的%s。" % str(
			device.get("label", "装置"),
		)
	return event


func _use_robot(
	peer_id: int,
	actor: Dictionary,
	tool: Dictionary,
) -> Dictionary:
	var robot_id := str(tool.get("robot_id", ""))
	if not robot_id.is_empty():
		var found := _find_device_entry(robot_id)
		if found.is_empty():
			_consume_selected_tool(actor)
			actors[peer_id] = actor
			return _tool_event(
				peer_id,
				"robot_lost",
				actor,
				[],
				"巡夜偶已经失效，对应控制器已损毁。",
			)
		var robot: Dictionary = found["item"]
		if elapsed < float(robot.get("stunned_until", 0.0)):
			return _rejected_event(
				peer_id,
				"巡夜偶仍在停机，%.1f 秒后才能换位。"
				% (float(robot["stunned_until"]) - elapsed),
			)
		var old_room: Vector2i = actor["room"]
		var old_pos: Vector2 = actor["pos"]
		actor["room"] = found["room"]["coord"]
		actor["pos"] = robot["pos"]
		actor["moving"] = false
		robot["collected"] = true
		_consume_selected_tool(actor)
		_reveal_if_thief(actor)
		actors[peer_id] = actor
		_add_noise_at(peer_id, "巡夜偶换位起点", old_room, old_pos, 2.0)
		_add_noise_at(
			peer_id,
			"巡夜偶换位终点",
			actor["room"],
			actor["pos"],
			2.0,
		)
		return _tool_event(
			peer_id,
			"robot_swap",
			actor,
			[_device_mutation(found["room"], robot)],
			"已与巡夜偶交换位置，巡夜偶随即报废。",
		)
	var role := _role_for_slot(str(actor.get("slot", "")))
	var robot := _spawn_device(
		peer_id,
		actor,
		"robot",
		_device_position(actor, role, 0.52),
	)
	robot["origin_room"] = actor["room"]
	robot["stunned_until"] = 0.0
	robot["next_alarm"] = 0.0
	robot["alert_until"] = 0.0
	robot["next_turn_at"] = elapsed
	robot["move_direction"] = _random_cardinal_direction()
	tool["deployed"] = true
	tool["robot_id"] = str(robot["id"])
	tool["robot_serial"] = int(robot["serial"])
	tool["stunned_until"] = 0.0
	_reveal_if_thief(actor)
	actors[peer_id] = actor
	_add_noise(peer_id, "召唤发条巡夜偶")
	return _tool_event(
		peer_id,
		"robot_deployed",
		actor,
		[_device_mutation(room_at(robot["room"]), robot)],
		"已召唤巡夜偶；再次按 C 可与正常工作的巡夜偶换位。",
	)


func apply_world_event(event: Dictionary) -> bool:
	if not bool(event.get("accepted", false)):
		return false
	var event_kind := str(event.get("kind", ""))
	if event_kind == "extraction":
		return true
	if event_kind == "noise":
		return _apply_noise_event(event)
	if event_kind == "combat":
		return true
	if event_kind == "tool":
		return _apply_tool_event(event)
	if event_kind not in ["furniture", "item"]:
		return false
	var room_coord: Vector2i = event.get("room", Vector2i(-1, -1))
	if (
		room_coord.x < 0
		or room_coord.y < 0
		or room_coord.x >= MAP_SIZE
		or room_coord.y >= MAP_SIZE
	):
		return false
	var room := room_at(room_coord)
	if event_kind == "item":
		var item := _find_item(room, str(event.get("item_id", "")))
		if item.is_empty():
			return false
		item["collected"] = true
		var actor_mutation: Dictionary = event.get("actor", {})
		if not actor_mutation.is_empty():
			_apply_tool_event({
				"actor": actor_mutation,
				"devices": [],
			})
		return true
	var mutation: Dictionary = event.get("furniture", {})
	var furniture := _find_furniture(room, str(mutation.get("id", "")))
	if furniture.is_empty():
		return false
	for key in ["opened", "destroyed", "damage", "durability", "contents", "last_hit_time"]:
		if mutation.has(key):
			furniture[key] = mutation[key].duplicate(true) if mutation[key] is Array else mutation[key]
	for item_variant in event.get("released_items", []):
		var item: Dictionary = item_variant
		if not _room_has_item(room, str(item.get("id", ""))):
			room["items"].append(item.duplicate(true))
	return true


func drain_world_events() -> Array:
	var drained := pending_world_events.duplicate(true)
	pending_world_events.clear()
	return drained


func prune_noises(now: float) -> void:
	for index in range(noises.size() - 1, -1, -1):
		var noise: Dictionary = noises[index]
		if now >= float(noise.get("expires", 0.0)):
			noises.remove_at(index)


func peer_can_hear_noise(peer_id: int, noise: Dictionary) -> bool:
	if not actors.has(peer_id):
		return false
	var listener: Dictionary = actors[peer_id]
	if bool(listener.get("extracted", false)):
		return false
	var listener_role := _role_for_slot(str(listener.get("slot", "")))
	if listener_role == str(noise.get("source_role", "")):
		return false
	if bool(noise.get("global", false)):
		return true
	var listener_room: Vector2i = listener["room"]
	var noise_room: Vector2i = noise.get("room", Vector2i.ZERO)
	var distance := (
		absi(listener_room.x - noise_room.x)
		+ absi(listener_room.y - noise_room.y)
	)
	return distance < 3


func snapshot() -> Dictionary:
	var replicated_actors: Dictionary = {}
	var replicated_inventories: Dictionary = {}
	for peer_id_variant in actors:
		var actor: Dictionary = actors[peer_id_variant]
		var room_coord: Vector2i = actor["room"]
		var actor_position: Vector2 = actor["pos"]
		replicated_actors[int(peer_id_variant)] = PackedFloat32Array([
			float(room_coord.x),
			float(room_coord.y),
			actor_position.x,
			actor_position.y,
			float(_direction_index(str(actor.get("dir", "down")))),
			1.0 if bool(actor.get("moving", false)) else 0.0,
			1.0 if bool(actor.get("hidden_from_monster", false)) else 0.0,
			int(actor.get("carried_value", 0)),
			(actor.get("carried_loot", []) as Array).size(),
			int(actor.get("pills", 0)),
			1 if bool(actor.get("extracted", false)) else 0,
			int(actor.get("extracted_value", 0)),
			int(actor.get("hp", MAX_HP)),
			1 if bool(actor.get("downed", false)) else 0,
			float(actor.get("hit_stun_until", 0.0)),
			float(actor.get("hit_invulnerable_until", 0.0)),
			float(actor.get("attack_started_at", -10.0)),
			float(actor.get("attack_ready_at", 0.0)),
			float(actor.get("hit_reaction_started_at", -10.0)),
			float((actor.get("hit_reaction_direction", Vector2.ZERO) as Vector2).x),
			float((actor.get("hit_reaction_direction", Vector2.ZERO) as Vector2).y),
			float(actor.get("rescue_progress", 0.0)),
			1 if bool(actor.get("being_revived", false)) else 0,
			float(actor.get("adrenaline_until", 0.0)),
			float(actor.get("fatigue_until", 0.0)),
			1 if bool(actor.get("trapped", false)) else 0,
			int(actor.get("trap_escape_progress", 0)),
			1 if bool(actor.get("trap_expected_left", true)) else 0,
			float(actor.get("teleport_started", -1.0)),
			float(actor.get("teleport_ends", -1.0)),
		])
		var inventory_record := PackedFloat32Array([
			float(actor.get("tool_selected", 0)),
		])
		for tool_variant in actor.get("tools", []):
			var tool: Dictionary = tool_variant
			inventory_record.append(float(NETWORK_TOOL_CATALOG.type_index(
				str(tool.get("tool_type", "")),
			)))
			inventory_record.append(float(tool.get("charge", 0.0)))
			inventory_record.append(
				1.0 if bool(tool.get("active", false)) else 0.0
			)
			inventory_record.append(float(tool.get("robot_serial", 0)))
			inventory_record.append(float(tool.get("stunned_until", 0.0)))
		replicated_inventories[int(peer_id_variant)] = inventory_record
	return {
		"a": replicated_actors,
		"i": replicated_inventories,
		"d": _device_snapshot(),
		"p": _phase_index(phase),
		"t": seconds_left,
		"e": elapsed,
	}


func apply_device_snapshot(records: PackedFloat32Array) -> void:
	var live_ids: Dictionary = {}
	for offset in range(0, records.size(), DEVICE_RECORD_SIZE):
		if offset + DEVICE_RECORD_SIZE > records.size():
			break
		var serial := roundi(records[offset])
		var device_id := "network-device-%d" % serial
		var device_type := NETWORK_TOOL_CATALOG.type_from_index(
			roundi(records[offset + 5]),
		)
		if device_type not in ["decoy", "phonograph", "trap", "robot"]:
			continue
		live_ids[device_id] = true
		var target_room_coord := Vector2i(
			roundi(records[offset + 1]),
			roundi(records[offset + 2]),
		)
		var found := _find_device_entry(device_id, true)
		var device: Dictionary
		if found.is_empty():
			device = _make_device_dictionary(
				device_type,
				device_id,
				roundi(records[offset + 7]),
				Vector2(records[offset + 3], records[offset + 4]),
			)
			device["serial"] = serial
			room_at(target_room_coord)["items"].append(device)
		else:
			device = found["item"]
			var current_room: Dictionary = found["room"]
			if current_room["coord"] != target_room_coord:
				(current_room["items"] as Array).erase(device)
				room_at(target_room_coord)["items"].append(device)
		device["room"] = target_room_coord
		device["pos"] = Vector2(records[offset + 3], records[offset + 4])
		device["state"] = _device_state_from_index(
			device_type,
			roundi(records[offset + 6]),
		)
		device["created"] = records[offset + 8]
		device["armed_at"] = records[offset + 9]
		device["expires"] = records[offset + 10]
		device["starts_at"] = records[offset + 11]
		device["next_noise"] = records[offset + 12]
		device["move_direction"] = Vector2(
			records[offset + 13],
			records[offset + 14],
		)
		device["trapped_peer_id"] = roundi(records[offset + 15])
		if device_type == "robot":
			device["stunned_until"] = records[offset + 9]
			device["alert_until"] = records[offset + 10]
			device["next_turn_at"] = records[offset + 11]
			device["next_alarm"] = records[offset + 12]
		device["collected"] = false
	for room_variant in rooms:
		var room: Dictionary = room_variant
		for item_variant in (room["items"] as Array).duplicate():
			var item: Dictionary = item_variant
			var item_id := str(item.get("id", ""))
			if (
				item_id.begins_with("network-device-")
				and not live_ids.has(item_id)
			):
				item["collected"] = true


func _device_snapshot() -> PackedFloat32Array:
	var result := PackedFloat32Array()
	for room_variant in rooms:
		var room: Dictionary = room_variant
		var room_coord: Vector2i = room["coord"]
		for item_variant in room["items"]:
			var item: Dictionary = item_variant
			if (
				bool(item.get("collected", false))
				or str(item.get("kind", "")) != "device"
			):
				continue
			var device_type := str(item.get("device_type", ""))
			if device_type not in ["decoy", "phonograph", "trap", "robot"]:
				continue
			var position: Vector2 = item["pos"]
			var direction: Vector2 = item.get("move_direction", Vector2.ZERO)
			var timed_value_1 := float(item.get("armed_at", INF))
			var timed_value_2 := float(item.get("expires", INF))
			var timed_value_3 := float(item.get("starts_at", INF))
			var timed_value_4 := float(item.get("next_noise", INF))
			if device_type == "robot":
				timed_value_1 = float(item.get("stunned_until", 0.0))
				timed_value_2 = float(item.get("alert_until", 0.0))
				timed_value_3 = float(item.get("next_turn_at", 0.0))
				timed_value_4 = float(item.get("next_alarm", 0.0))
			for value in [
				int(item.get("serial", 0)),
				room_coord.x,
				room_coord.y,
				position.x,
				position.y,
				NETWORK_TOOL_CATALOG.type_index(device_type),
				_device_state_index(device_type, str(item.get("state", "active"))),
				int(item.get("owner_peer_id", 0)),
				float(item.get("created", 0.0)),
				timed_value_1,
				timed_value_2,
				timed_value_3,
				timed_value_4,
				direction.x,
				direction.y,
				int(item.get("trapped_peer_id", 0)),
			]:
				result.append(float(value))
	return result


func _update_tool_states(delta: float) -> void:
	for room_variant in rooms:
		var room: Dictionary = room_variant
		for furniture_variant in room["furniture"]:
			(furniture_variant as Dictionary)["detector_active"] = false
	for peer_id_variant in actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = actors[peer_id_variant]
		for tool_variant in actor.get("tools", []):
			var tool: Dictionary = tool_variant
			if (
				str(tool.get("tool_type", "")) != "detector"
				or not bool(tool.get("active", false))
			):
				continue
			tool["charge"] = maxf(
				float(tool.get("charge", 0.0)) - delta,
				0.0,
			)
			if float(tool["charge"]) <= 0.0:
				tool["active"] = false
				pending_world_events.append(_tool_event(
					peer_id,
					"detector_empty",
					actor,
					[],
					"藏品探测器电量耗尽。",
				))
				continue
			for furniture_variant in room_at(actor["room"])["furniture"]:
				(furniture_variant as Dictionary)["detector_active"] = true
			if elapsed >= float(tool.get("next_noise", 0.0)):
				tool["next_noise"] = elapsed + DETECTOR_NOISE_INTERVAL
				_add_noise(peer_id, "探测器脉冲", 2.0)
		var teleport_ends := float(actor.get("teleport_ends", -1.0))
		if (
			teleport_ends > 0.0
			and elapsed >= teleport_ends
			and not bool(actor.get("extracted", false))
		):
			_complete_teleport_extraction(peer_id, actor)
		actors[peer_id] = actor


func _complete_teleport_extraction(peer_id: int, actor: Dictionary) -> void:
	actor["teleport_started"] = -1.0
	actor["teleport_ends"] = -1.0
	var carried_loot: Array = actor.get("carried_loot", [])
	actor["extracted_loot"] = carried_loot.duplicate(true)
	carried_loot.clear()
	actor["extracted_value"] = int(actor.get("carried_value", 0))
	actor["carried_value"] = 0
	actor["extracted"] = true
	actor["moving"] = false
	pending_world_events.append(_tool_event(
		peer_id,
		"teleporter_complete",
		actor,
		[],
		"传送完成，已携带全部财物撤离。",
	))


func _update_devices(delta: float) -> void:
	var devices: Array = []
	for room_variant in rooms:
		var room: Dictionary = room_variant
		for item_variant in room["items"]:
			var item: Dictionary = item_variant
			if (
				not bool(item.get("collected", false))
				and str(item.get("kind", "")) == "device"
			):
				devices.append(item)
	for item_variant in devices:
		var item: Dictionary = item_variant
		var found := _find_device_entry(str(item.get("id", "")))
		if found.is_empty():
			continue
		var room: Dictionary = found["room"]
		match str(item.get("device_type", "")):
			"decoy":
				if elapsed >= float(item.get("expires", INF)):
					item["collected"] = true
					continue
				var direction: Vector2 = item.get("move_direction", Vector2.ZERO)
				if direction.is_zero_approx() or delta <= 0.0:
					continue
				var old_room: Dictionary = room
				var character_role := str(item.get("character_role", "thief"))
				_move_actor(
					-int(item.get("serial", 1)),
					item,
					character_role,
					direction,
					delta,
					DECOY_SPEED / ACTOR_SPEED,
					false,
				)
				var next_room_coord: Vector2i = item["room"]
				if next_room_coord != old_room["coord"]:
					(old_room["items"] as Array).erase(item)
					room_at(next_room_coord)["items"].append(item)
			"trap":
				if (
					str(item.get("state", "")) != "active"
					or elapsed < float(item.get("armed_at", INF))
				):
					continue
				for peer_id_variant in actors:
					var peer_id := int(peer_id_variant)
					var actor: Dictionary = actors[peer_id_variant]
					if (
						bool(actor.get("extracted", false))
						or bool(actor.get("downed", false))
						or bool(actor.get("trapped", false))
						or actor["room"] != room["coord"]
						or (actor["pos"] as Vector2).distance_to(item["pos"])
						> TRAP_TRIGGER_RADIUS
					):
						continue
					item["state"] = "sprung"
					item["sprung_at"] = elapsed
					item["trapped_peer_id"] = peer_id
					item["next_noise"] = elapsed + 1.0
					actor["trapped"] = true
					actor["trapped_by"] = str(item["id"])
					actor["trapped_started_at"] = elapsed
					actor["trap_escape_progress"] = 0
					actor["trap_expected_left"] = true
					actor["trap_prompt"] = "A"
					actor["moving"] = false
					_cancel_teleporter(actor)
					actors[peer_id] = actor
					_add_noise_at(
						peer_id,
						"捕兽夹触发",
						room["coord"],
						item["pos"],
						3.0,
					)
					pending_world_events.append(_tool_event(
						int(item.get("owner_peer_id", 0)),
						"trap_triggered",
						actor,
						[_device_mutation(room, item)],
						"%s踩中了捕兽夹。" % str(actor.get("name", "玩家")),
						peer_id,
					))
					break
			"phonograph":
				if str(item.get("state", "")) != "playing":
					continue
				if elapsed >= float(item.get("expires", INF)):
					item["collected"] = true
					pending_world_events.append({
						"accepted": true,
						"kind": "tool",
						"tool_action": "phonograph_expired",
						"requester_peer_id": int(item.get("owner_peer_id", 0)),
						"devices": [_device_mutation(room, item)],
						"message": "留声机播放完毕并自动损毁。",
					})
				elif (
					elapsed >= float(item.get("starts_at", INF))
					and elapsed >= float(item.get("next_noise", INF))
				):
					item["next_noise"] = elapsed + 0.9
					_add_noise_at(
						int(item.get("owner_peer_id", 0)),
						"留声机撞击",
						room["coord"],
						item["pos"],
						2.0,
					)
			"robot":
				_update_robot(item, room, delta)


func _update_robot(robot: Dictionary, room: Dictionary, delta: float) -> void:
	var owner_peer_id := int(robot.get("owner_peer_id", 0))
	if elapsed < float(robot.get("stunned_until", 0.0)):
		robot["state"] = "stunned"
		_sync_robot_tool(robot)
		return
	if str(robot.get("state", "")) == "stunned":
		robot["state"] = "active"
		robot["next_turn_at"] = elapsed
		robot["move_direction"] = _random_cardinal_direction()
		_sync_robot_tool(robot)
	var owner_role := str(robot.get("owner", "monster"))
	if elapsed >= float(robot.get("next_alarm", 0.0)):
		for peer_id_variant in actors:
			var peer_id := int(peer_id_variant)
			var actor: Dictionary = actors[peer_id_variant]
			if (
				_role_for_slot(str(actor.get("slot", ""))) == owner_role
				or bool(actor.get("extracted", false))
				or actor["room"] != room["coord"]
			):
				continue
			robot["next_alarm"] = elapsed + ROBOT_ALARM_COOLDOWN
			robot["alert_until"] = elapsed + ROBOT_ALARM_SECONDS
			_add_noise_at(
				owner_peer_id,
				"巡夜偶警报",
				room["coord"],
				robot["pos"],
				ROBOT_ALARM_SECONDS,
			)
			break
	if delta <= 0.0:
		return
	if elapsed >= float(robot.get("next_turn_at", 0.0)):
		robot["next_turn_at"] = elapsed + ROBOT_TURN_SECONDS
		robot["move_direction"] = _random_cardinal_direction()
	var direction: Vector2 = robot.get("move_direction", Vector2.RIGHT)
	var old_room: Dictionary = room
	var old_room_coord: Vector2i = room["coord"]
	var old_pos: Vector2 = robot["pos"]
	_move_actor(
		-int(robot.get("serial", 1)),
		robot,
		owner_role,
		direction,
		delta,
		ROBOT_SPEED / ACTOR_SPEED,
		false,
	)
	var next_room_coord: Vector2i = robot["room"]
	var origin_room: Vector2i = robot.get("origin_room", old_room_coord)
	if (
		absi(next_room_coord.x - origin_room.x) > 1
		or absi(next_room_coord.y - origin_room.y) > 1
	):
		robot["room"] = old_room_coord
		robot["pos"] = old_pos
		robot["next_turn_at"] = elapsed
		return
	if (robot["pos"] as Vector2).is_equal_approx(old_pos):
		robot["next_turn_at"] = elapsed
	if next_room_coord != old_room_coord:
		(old_room["items"] as Array).erase(robot)
		room_at(next_room_coord)["items"].append(robot)


func _sync_robot_tool(robot: Dictionary) -> void:
	var owner_peer_id := int(robot.get("owner_peer_id", 0))
	if not actors.has(owner_peer_id):
		return
	var actor: Dictionary = actors[owner_peer_id]
	for tool_variant in actor.get("tools", []):
		var tool: Dictionary = tool_variant
		if str(tool.get("robot_id", "")) == str(robot.get("id", "")):
			tool["stunned_until"] = float(robot.get("stunned_until", 0.0))
			break
	actors[owner_peer_id] = actor


func _tool_event(
	requester_peer_id: int,
	action: String,
	actor: Dictionary,
	devices: Array,
	message: String,
	target_peer_id := 0,
) -> Dictionary:
	return {
		"accepted": true,
		"kind": "tool",
		"tool_action": action,
		"requester_peer_id": requester_peer_id,
		"target_peer_id": target_peer_id,
		"actor": _tool_actor_mutation(
			int(actor.get("peer_id", target_peer_id)),
			actor,
		),
		"devices": devices.duplicate(true),
		"message": message,
	}


func _tool_actor_mutation(peer_id: int, actor: Dictionary) -> Dictionary:
	return {
		"peer_id": peer_id,
		"tools": (actor.get("tools", []) as Array).duplicate(true),
		"tool_selected": int(actor.get("tool_selected", 0)),
		"adrenaline_until": float(actor.get("adrenaline_until", 0.0)),
		"fatigue_until": float(actor.get("fatigue_until", 0.0)),
		"teleport_started": float(actor.get("teleport_started", -1.0)),
		"teleport_ends": float(actor.get("teleport_ends", -1.0)),
		"room": actor.get("room", Vector2i.ZERO),
		"pos": actor.get("pos", Vector2.ZERO),
		"dir": str(actor.get("dir", "down")),
		"facing": actor.get("facing", Vector2.DOWN),
		"hit_stun_until": float(actor.get("hit_stun_until", 0.0)),
		"extracted": bool(actor.get("extracted", false)),
		"extracted_value": int(actor.get("extracted_value", 0)),
		"carried_value": int(actor.get("carried_value", 0)),
		"carried_loot": (actor.get("carried_loot", []) as Array).duplicate(true),
		"trapped": bool(actor.get("trapped", false)),
		"trapped_by": str(actor.get("trapped_by", "")),
		"trapped_started_at": float(actor.get("trapped_started_at", -10.0)),
		"trap_escape_progress": int(actor.get("trap_escape_progress", 0)),
		"trap_expected_left": bool(actor.get("trap_expected_left", true)),
		"trap_prompt": str(actor.get("trap_prompt", "")),
	}


func _apply_tool_event(event: Dictionary) -> bool:
	var mutation: Dictionary = event.get("actor", {})
	if not mutation.is_empty():
		_apply_tool_actor_mutation(mutation)
	for target_variant in event.get("target_actors", []):
		_apply_tool_actor_mutation(target_variant)
	var furniture_mutation: Dictionary = event.get("furniture", {})
	if not furniture_mutation.is_empty():
		var room_coord: Vector2i = event.get("room", Vector2i(-1, -1))
		if room_coord.x >= 0 and room_coord.y >= 0:
			var furniture := _find_furniture(
				room_at(room_coord),
				str(furniture_mutation.get("id", "")),
			)
			if not furniture.is_empty():
				for key in furniture_mutation:
					furniture[key] = (
						furniture_mutation[key].duplicate(true)
						if furniture_mutation[key] is Array
						else furniture_mutation[key]
					)
	for device_variant in event.get("devices", []):
		_apply_device_mutation(device_variant)
	return true


func _apply_tool_actor_mutation(mutation: Dictionary) -> void:
	var peer_id := int(mutation.get("peer_id", 0))
	if not actors.has(peer_id):
		return
	var actor: Dictionary = actors[peer_id]
	for key in [
		"tools",
		"tool_selected",
		"adrenaline_until",
		"fatigue_until",
		"teleport_started",
		"teleport_ends",
		"room",
		"pos",
		"dir",
		"facing",
		"hit_stun_until",
		"extracted",
		"extracted_value",
		"carried_value",
		"carried_loot",
		"trapped",
		"trapped_by",
		"trapped_started_at",
		"trap_escape_progress",
		"trap_expected_left",
		"trap_prompt",
	]:
		if mutation.has(key):
			actor[key] = (
				mutation[key].duplicate(true)
				if mutation[key] is Array
				else mutation[key]
			)
	actors[peer_id] = actor


func _apply_device_mutation(mutation: Dictionary) -> void:
	var device_id := str(mutation.get("id", ""))
	var device_type := str(mutation.get("device_type", ""))
	var target_room_coord: Vector2i = mutation.get("room", Vector2i(-1, -1))
	if (
		device_id.is_empty()
		or device_type.is_empty()
		or target_room_coord.x < 0
		or target_room_coord.y < 0
	):
		return
	var found := _find_device_entry(device_id, true)
	var device: Dictionary
	if found.is_empty():
		device = mutation.duplicate(true)
		room_at(target_room_coord)["items"].append(device)
	else:
		device = found["item"]
		var current_room: Dictionary = found["room"]
		if current_room["coord"] != target_room_coord:
			(current_room["items"] as Array).erase(device)
			room_at(target_room_coord)["items"].append(device)
		for key in mutation:
			device[key] = (
				mutation[key].duplicate(true)
				if mutation[key] is Array or mutation[key] is Dictionary
				else mutation[key]
			)


func _device_mutation(room: Dictionary, device: Dictionary) -> Dictionary:
	var mutation := device.duplicate(true)
	mutation["room"] = room["coord"]
	return mutation


func _spawn_device(
	peer_id: int,
	actor: Dictionary,
	device_type: String,
	position: Vector2,
) -> Dictionary:
	var serial := next_device_id
	var device_id := "network-device-%d" % serial
	next_device_id += 1
	var device := _make_device_dictionary(
		device_type,
		device_id,
		peer_id,
		position,
	)
	device["serial"] = serial
	device["room"] = actor["room"]
	room_at(actor["room"])["items"].append(device)
	return device


func _make_device_dictionary(
	device_type: String,
	device_id: String,
	owner_peer_id: int,
	position: Vector2,
) -> Dictionary:
	var owner_role := "monster"
	if actors.has(owner_peer_id):
		owner_role = _role_for_slot(str(actors[owner_peer_id].get("slot", "")))
	var device := GAMEPLAY_STATE_FACTORY.device(
		device_type,
		device_id,
		str(GAME_STATE_BASE.TOOL_DEFS[device_type]["label"]),
		owner_role,
		position,
		elapsed,
	)
	device["owner_peer_id"] = owner_peer_id
	device["room"] = (
		actors[owner_peer_id]["room"]
		if actors.has(owner_peer_id)
		else Vector2i.ZERO
	)
	return device


func _device_position(
	actor: Dictionary,
	role: String,
	forward_distance: float,
) -> Vector2:
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	if facing.is_zero_approx():
		facing = Vector2.RIGHT
	var target: Vector2 = actor["pos"] + facing.normalized() * forward_distance
	var room := room_at(actor["room"])
	if not MANSION_COLLISION.position_clears_room_walls(room, target, role):
		return actor["pos"]
	for furniture_variant in room["furniture"]:
		var furniture: Dictionary = furniture_variant
		if (
			not bool(furniture.get("destroyed", false))
			and MANSION_COLLISION.actor_overlaps_furniture(target, furniture, role)
		):
			return actor["pos"]
	return target


func _nearest_intact_furniture(actor: Dictionary) -> Dictionary:
	var room := room_at(actor["room"])
	var nearest: Dictionary = {}
	var nearest_distance := INF
	for furniture_variant in room["furniture"]:
		var furniture: Dictionary = furniture_variant
		if bool(furniture.get("destroyed", false)):
			continue
		var distance := (furniture["pos"] as Vector2).distance_to(actor["pos"])
		if distance <= 1.05 and distance < nearest_distance:
			nearest = furniture
			nearest_distance = distance
	if nearest.is_empty():
		return {}
	return {"room": room, "furniture": nearest}


func _furniture_replication(furniture: Dictionary) -> Dictionary:
	return {
		"id": str(furniture["id"]),
		"opened": bool(furniture.get("opened", false)),
		"destroyed": bool(furniture.get("destroyed", false)),
		"damage": int(furniture.get("damage", 0)),
		"durability": int(furniture.get("durability", 1)),
		"contents": (furniture.get("contents", []) as Array).duplicate(true),
		"last_hit_time": float(furniture.get("last_hit_time", elapsed)),
	}


func _trigger_furniture_alarm(room: Dictionary, furniture: Dictionary) -> bool:
	var contents: Array = furniture.get("contents", [])
	for index in range(contents.size() - 1, -1, -1):
		var content: Dictionary = contents[index]
		if str(content.get("kind", "")) != "alarm":
			continue
		var owner_peer_id := int(content.get("owner_peer_id", 0))
		contents.remove_at(index)
		_add_noise_at(
			owner_peer_id,
			"家具警报",
			room["coord"],
			furniture["pos"],
			5.0,
			true,
		)
		return true
	return false


func _enemy_actor_in_front(
	peer_id: int,
	actor: Dictionary,
	reach: float,
) -> int:
	var role := _role_for_slot(str(actor.get("slot", "")))
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var best_peer_id := 0
	var best_distance := INF
	for target_peer_id_variant in actors:
		var target_peer_id := int(target_peer_id_variant)
		if target_peer_id == peer_id:
			continue
		var target: Dictionary = actors[target_peer_id_variant]
		if (
			_role_for_slot(str(target.get("slot", ""))) == role
			or bool(target.get("extracted", false))
			or bool(target.get("downed", false))
			or target["room"] != actor["room"]
		):
			continue
		var offset: Vector2 = (target["pos"] as Vector2) - (actor["pos"] as Vector2)
		var distance := offset.length()
		if distance > reach or distance >= best_distance:
			continue
		if not offset.is_zero_approx() and offset.normalized().dot(facing) < 0.5:
			continue
		best_peer_id = target_peer_id
		best_distance = distance
	return best_peer_id


func _enemy_breakable_device_in_front(
	_peer_id: int,
	actor: Dictionary,
) -> Dictionary:
	var role := _role_for_slot(str(actor.get("slot", "")))
	var room := room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var best: Dictionary = {}
	var best_distance := INF
	for item_variant in room["items"]:
		var item: Dictionary = item_variant
		if (
			bool(item.get("collected", false))
			or str(item.get("kind", "")) != "device"
			or str(item.get("device_type", "")) not in ["decoy", "phonograph"]
			or str(item.get("owner", "")) == role
		):
			continue
		var offset: Vector2 = (item["pos"] as Vector2) - (actor["pos"] as Vector2)
		var distance := offset.length()
		if distance > SPRING_GLOVE_REACH or distance >= best_distance:
			continue
		if not offset.is_zero_approx() and offset.normalized().dot(facing) < 0.5:
			continue
		best = {"room": room, "item": item}
		best_distance = distance
	return best


func _enemy_robot_in_front(peer_id: int, actor: Dictionary) -> Dictionary:
	var role := _role_for_slot(str(actor.get("slot", "")))
	var room := room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var best: Dictionary = {}
	var best_distance := INF
	for item_variant in room["items"]:
		var item: Dictionary = item_variant
		if (
			bool(item.get("collected", false))
			or str(item.get("device_type", "")) != "robot"
			or str(item.get("owner", "")) == role
			or int(item.get("owner_peer_id", 0)) == peer_id
		):
			continue
		var offset: Vector2 = (item["pos"] as Vector2) - (actor["pos"] as Vector2)
		var distance := offset.length()
		if distance > FURNITURE_HIT_REACH or distance >= best_distance:
			continue
		if not offset.is_zero_approx() and offset.normalized().dot(facing) < FURNITURE_HIT_DOT:
			continue
		best = {"room": room, "item": item}
		best_distance = distance
	return best


func _stun_robot(
	peer_id: int,
	actor: Dictionary,
	entry: Dictionary,
) -> Dictionary:
	var robot: Dictionary = entry["item"]
	robot["stunned_until"] = elapsed + ROBOT_STUN_SECONDS
	robot["state"] = "stunned"
	robot["move_direction"] = Vector2.ZERO
	_sync_robot_tool(robot)
	last_furniture_action_at[peer_id] = elapsed
	_reveal_if_thief(actor)
	_add_noise(peer_id, "撞击巡夜偶")
	return _tool_event(
		peer_id,
		"robot_stunned",
		actor,
		[_device_mutation(entry["room"], robot)],
		"已撞停敌方巡夜偶，它将在 %.0f 秒后恢复。"
		% ROBOT_STUN_SECONDS,
	)


func _displace_actor(
	peer_id: int,
	actor: Dictionary,
	role: String,
	displacement: Vector2,
) -> void:
	if displacement.is_zero_approx():
		return
	var old_facing: Vector2 = actor.get("facing", Vector2.RIGHT)
	var old_dir := str(actor.get("dir", "right"))
	_move_actor(
		peer_id,
		actor,
		role,
		displacement.normalized(),
		displacement.length() / ACTOR_SPEED,
	)
	actor["facing"] = old_facing
	actor["dir"] = old_dir


func _cancel_teleporter(actor: Dictionary) -> void:
	if float(actor.get("teleport_ends", -1.0)) <= elapsed:
		return
	actor["teleport_started"] = -1.0
	actor["teleport_ends"] = -1.0


func _random_cardinal_direction() -> Vector2:
	return [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN][
		rng.randi_range(0, 3)
	]


func _nearby_owned_phonograph(peer_id: int, actor: Dictionary) -> Dictionary:
	var room := room_at(actor["room"])
	for item_variant in room["items"]:
		var item: Dictionary = item_variant
		if (
			not bool(item.get("collected", false))
			and str(item.get("device_type", "")) == "phonograph"
			and str(item.get("state", "")) == "idle"
			and int(item.get("owner_peer_id", 0)) == peer_id
			and (item["pos"] as Vector2).distance_to(actor["pos"])
			<= PHONOGRAPH_REACH
		):
			return {"room": room, "item": item}
	return {}


func _consume_selected_tool(actor: Dictionary) -> void:
	var tools: Array = actor.get("tools", [])
	if tools.is_empty():
		return
	var selected := clampi(int(actor.get("tool_selected", 0)), 0, tools.size() - 1)
	tools.remove_at(selected)
	actor["tool_selected"] = clampi(selected, 0, maxi(tools.size() - 1, 0))


func _make_network_tool(tool_type: String, tool_id: String) -> Dictionary:
	return NETWORK_TOOL_CATALOG.make_tool(tool_type, tool_id)


func _actor_speed_multiplier(actor: Dictionary) -> float:
	if elapsed < float(actor.get("adrenaline_until", 0.0)):
		return 2.0
	if elapsed < float(actor.get("fatigue_until", 0.0)):
		return 0.5
	return 1.0


func _reveal_if_thief(actor: Dictionary) -> void:
	if _role_for_slot(str(actor.get("slot", ""))) == "thief":
		_reveal_thief(actor)


func _actor_can_pick_up_item(actor: Dictionary, item: Dictionary) -> bool:
	if bool(item.get("collected", false)):
		return false
	var role := _role_for_slot(str(actor.get("slot", "")))
	var kind := str(item.get("kind", ""))
	if kind == "tool":
		var tool_type := str(item.get("tool_type", ""))
		return (
			NETWORK_TOOL_CATALOG.supports(tool_type)
			and not (role == "monster" and tool_type == "teleporter")
			and (actor.get("tools", []) as Array).size() < TOOL_INVENTORY_CAPACITY
		)
	if (
		kind == "device"
		and str(item.get("device_type", "")) == "trap"
		and str(item.get("state", "")) == "recoverable"
	):
		return (actor.get("tools", []) as Array).size() < TOOL_INVENTORY_CAPACITY
	return role == "thief" and kind in ["treasure", "trinket", "pill"]


func _find_device_entry(device_id: String, include_collected := false) -> Dictionary:
	if device_id.is_empty():
		return {}
	for room_variant in rooms:
		var room: Dictionary = room_variant
		for item_variant in room["items"]:
			var item: Dictionary = item_variant
			if (
				str(item.get("id", "")) == device_id
				and (include_collected or not bool(item.get("collected", false)))
			):
				return {"room": room, "item": item}
	return {}


func _add_noise_at(
	source_peer_id: int,
	label: String,
	room_coord: Vector2i,
	position: Vector2,
	duration: float,
	global := false,
) -> void:
	if phase != "hunt":
		return
	var source_role := "neutral"
	if actors.has(source_peer_id):
		source_role = _role_for_slot(str(actors[source_peer_id].get("slot", "")))
	var entry := {
		"id": next_noise_id,
		"source_peer_id": source_peer_id,
		"source_role": source_role,
		"label": label,
		"room": room_coord,
		"pos": position,
		"created": elapsed,
		"expires": elapsed + duration,
		"duration": duration,
		"global": global,
	}
	next_noise_id += 1
	noises.append(entry)
	pending_world_events.append({
		"accepted": true,
		"kind": "noise",
		"noise": _public_noise(entry),
	})


static func _device_state_index(device_type: String, state: String) -> int:
	match device_type:
		"trap":
			return ["active", "sprung", "recoverable"].find(state)
		"phonograph":
			return ["idle", "playing"].find(state)
		"robot":
			return ["active", "stunned"].find(state)
	return 0


static func _device_state_from_index(device_type: String, index: int) -> String:
	match device_type:
		"trap":
			return ["active", "sprung", "recoverable"][clampi(index, 0, 2)]
		"phonograph":
			return ["idle", "playing"][clampi(index, 0, 1)]
		"robot":
			return ["active", "stunned"][clampi(index, 0, 1)]
	return "active"


func _update_rescues(delta: float, rescue_inputs: Dictionary) -> void:
	var active_revivers: Dictionary = {}
	for peer_id_variant in actors:
		var peer_id := int(peer_id_variant)
		var rescuer: Dictionary = actors[peer_id_variant]
		if (
			not bool(rescue_inputs.get(peer_id, false))
			or _role_for_slot(str(rescuer.get("slot", ""))) != "thief"
			or bool(rescuer.get("extracted", false))
			or bool(rescuer.get("downed", false))
			or bool(rescuer.get("trapped", false))
			or elapsed < float(rescuer.get("hit_stun_until", 0.0))
			or phase != "hunt"
		):
			continue
		var nearest_target_id := 0
		var nearest_distance := INF
		for target_peer_id_variant in actors:
			var target_peer_id := int(target_peer_id_variant)
			if target_peer_id == peer_id:
				continue
			var target: Dictionary = actors[target_peer_id_variant]
			if (
				_role_for_slot(str(target.get("slot", ""))) != "thief"
				or not bool(target.get("downed", false))
				or bool(target.get("extracted", false))
				or target.get("room", Vector2i(-1, -1)) != rescuer["room"]
			):
				continue
			var distance := (
				(target["pos"] as Vector2).distance_to(rescuer["pos"])
			)
			if distance <= REVIVE_DISTANCE and distance < nearest_distance:
				nearest_target_id = target_peer_id
				nearest_distance = distance
		if nearest_target_id == 0:
			continue
		if (
			not active_revivers.has(nearest_target_id)
			or peer_id < int(active_revivers[nearest_target_id])
		):
			active_revivers[nearest_target_id] = peer_id

	for peer_id_variant in actors:
		var peer_id := int(peer_id_variant)
		var target: Dictionary = actors[peer_id_variant]
		if (
			_role_for_slot(str(target.get("slot", ""))) != "thief"
			or not bool(target.get("downed", false))
		):
			target["being_revived"] = false
			target["rescue_progress"] = 0.0
			actors[peer_id] = target
			continue
		if not active_revivers.has(peer_id):
			target["being_revived"] = false
			target["rescue_progress"] = 0.0
			actors[peer_id] = target
			continue
		var reviver_peer_id := int(active_revivers[peer_id])
		target["being_revived"] = true
		target["rescue_progress"] = (
			float(target.get("rescue_progress", 0.0)) + delta
		)
		if float(target["rescue_progress"]) < REVIVE_SECONDS:
			actors[peer_id] = target
			continue
		target["hp"] = 1
		target["downed"] = false
		target["being_revived"] = false
		target["rescue_progress"] = 0.0
		target["hit_stun_until"] = elapsed + REVIVE_HIT_STUN_SECONDS
		target["hit_invulnerable_until"] = elapsed + REVIVE_INVULNERABLE_SECONDS
		target["hit_reaction_started_at"] = -10.0
		target["hit_reaction_direction"] = Vector2.ZERO
		target["hidden_from_monster"] = false
		target["revealed_until"] = elapsed + THIEF_REVEAL_SECONDS
		actors[peer_id] = target
		pending_world_events.append({
			"accepted": true,
			"kind": "combat",
			"combat_type": "revive",
			"requester_peer_id": reviver_peer_id,
			"target_peer_id": peer_id,
			"targets": [_combat_actor_mutation(peer_id, target)],
			"message": "%s完成了救援。" % str(target.get("name", "盗贼")),
		})


func _combat_actor_mutation(peer_id: int, actor: Dictionary) -> Dictionary:
	return {
		"peer_id": peer_id,
		"hp": int(actor.get("hp", MAX_HP)),
		"downed": bool(actor.get("downed", false)),
		"hit_stun_until": float(actor.get("hit_stun_until", 0.0)),
		"hit_invulnerable_until": float(actor.get("hit_invulnerable_until", 0.0)),
		"hit_reaction_started_at": float(actor.get("hit_reaction_started_at", -10.0)),
		"hit_reaction_direction": actor.get("hit_reaction_direction", Vector2.ZERO),
		"rescue_progress": float(actor.get("rescue_progress", 0.0)),
		"being_revived": bool(actor.get("being_revived", false)),
	}


func _update_thief_stealth() -> void:
	for peer_id_variant in actors:
		var actor: Dictionary = actors[peer_id_variant]
		if _role_for_slot(str(actor.get("slot", ""))) != "thief":
			continue
		if (
			phase != "hunt"
			or bool(actor.get("extracted", false))
			or bool(actor.get("downed", false))
		):
			actor["hidden_from_monster"] = false
			actors[peer_id_variant] = actor
			continue
		if bool(actor.get("moving", false)):
			actor["hidden_from_monster"] = false
		var can_hide_at := maxf(
			float(actor.get("last_moved_at", elapsed)) + THIEF_HIDE_DELAY,
			float(actor.get("revealed_until", 0.0)),
		)
		actor["hidden_from_monster"] = elapsed >= can_hide_at
		actors[peer_id_variant] = actor


func _reveal_thief(actor: Dictionary) -> void:
	if phase != "hunt":
		return
	actor["hidden_from_monster"] = false
	actor["revealed_until"] = maxf(
		float(actor.get("revealed_until", 0.0)),
		elapsed + THIEF_REVEAL_SECONDS,
	)
	if bool(actor.get("moving", false)):
		actor["last_moved_at"] = elapsed


func _add_noise(
	peer_id: int,
	label: String,
	duration := DEFAULT_NOISE_SECONDS,
	throttle := 0.0,
) -> void:
	if phase != "hunt" or not actors.has(peer_id):
		return
	if throttle > 0.0:
		for existing_variant in noises:
			var existing: Dictionary = existing_variant
			if (
				int(existing.get("source_peer_id", 0)) == peer_id
				and str(existing.get("label", "")) == label
				and elapsed - float(existing.get("created", -100.0)) < throttle
			):
				return
	var actor: Dictionary = actors[peer_id]
	var entry := {
		"id": next_noise_id,
		"source_peer_id": peer_id,
		"source_role": _role_for_slot(str(actor.get("slot", ""))),
		"label": label,
		"room": actor["room"],
		"pos": actor["pos"],
		"created": elapsed,
		"expires": elapsed + duration,
		"duration": duration,
	}
	next_noise_id += 1
	noises.append(entry)
	pending_world_events.append({
		"accepted": true,
		"kind": "noise",
		"noise": _public_noise(entry),
	})


func _public_noise(noise: Dictionary) -> Dictionary:
	return {
		"id": int(noise["id"]),
		"source_role": str(noise["source_role"]),
		"label": str(noise["label"]),
		"room": noise["room"],
		"pos": noise["pos"],
		"created": float(noise["created"]),
		"expires": float(noise["expires"]),
		"duration": float(noise["duration"]),
		"global": bool(noise.get("global", false)),
	}


func _apply_noise_event(event: Dictionary) -> bool:
	var incoming: Dictionary = event.get("noise", {})
	if incoming.is_empty():
		return false
	var noise_id := int(incoming.get("id", 0))
	for noise_variant in noises:
		var noise: Dictionary = noise_variant
		if int(noise.get("id", 0)) == noise_id:
			return true
	noises.append(incoming.duplicate(true))
	return true


func _update_phase(delta: float) -> void:
	if phase not in ["hide", "ready", "hunt"]:
		return
	if phase == "hunt" and seconds_left <= 0:
		return
	phase_clock += delta
	if phase_clock < 1.0:
		return
	var ticks := int(phase_clock)
	phase_clock -= float(ticks)
	for _tick in range(ticks):
		seconds_left = maxi(seconds_left - 1, 0)
		if seconds_left > 0:
			continue
		if phase == "hide":
			begin_hunt_countdown()
		elif phase == "ready":
			phase = "hunt"
			seconds_left = HUNT_SECONDS
			phase_clock = 0.0
			_respawn_all()
		break


func _make_actor(peer_id: int, player: Dictionary) -> Dictionary:
	var slot := str(player.get("slot", "spectator"))
	var role := _role_for_slot(slot)
	var spawn := (
		combat_test_spawn_for_slot(slot)
		if debug_combat_spawns
		else spawn_for_slot(slot)
	)
	var direction := "left" if role == "monster" else "right"
	var facing := Vector2.LEFT if role == "monster" else Vector2.RIGHT
	var actor := GAMEPLAY_STATE_FACTORY.actor(
		spawn["room"],
		spawn["pos"],
		direction,
		facing,
	)
	actor["peer_id"] = peer_id
	actor["name"] = str(player.get("name", "玩家"))
	actor["slot"] = slot
	actor["carried_loot"] = []
	actor["carried_value"] = 0
	actor["pills"] = 0
	actor["extracted"] = false
	actor["extracted_value"] = 0
	actor["extracted_loot"] = []
	actor["hp"] = MAX_HP
	actor["downed"] = false
	actor["hit_stun_until"] = 0.0
	actor["hit_invulnerable_until"] = 0.0
	actor["attack_ready_at"] = 0.0
	actor["rescue_progress"] = 0.0
	actor["being_revived"] = false
	actor["tools"] = []
	actor["tool_selected"] = 0
	if debug_tool_loadouts:
		var tool_serial := 0
		for tool_type in NETWORK_TOOL_CATALOG.test_loadout_for_slot(slot):
			(actor["tools"] as Array).append(_make_network_tool(
				tool_type,
				"debug-tool-%s-%d" % [slot, tool_serial],
			))
			tool_serial += 1
	return actor


func _respawn_all() -> void:
	for peer_id_variant in actors:
		var actor: Dictionary = actors[peer_id_variant]
		var slot := str(actor.get("slot", ""))
		var spawn := (
			combat_test_spawn_for_slot(slot)
			if debug_combat_spawns
			else spawn_for_slot(slot)
		)
		actor["room"] = spawn["room"]
		actor["pos"] = spawn["pos"]
		if debug_combat_spawns:
			var role := _role_for_slot(slot)
			actor["dir"] = "left" if role == "monster" else "right"
			actor["facing"] = Vector2.LEFT if role == "monster" else Vector2.RIGHT
		actor["moving"] = false
		actor["impact_visual_offset"] = Vector2.ZERO
		actor["hidden_from_monster"] = false
		actor["last_moved_at"] = elapsed
		actor["revealed_until"] = elapsed + THIEF_HIDE_DELAY
		actor["hp"] = MAX_HP
		actor["downed"] = false
		actor["hit_stun_until"] = 0.0
		actor["hit_invulnerable_until"] = 0.0
		actor["attack_ready_at"] = 0.0
		actor["attack_started_at"] = -10.0
		actor["rescue_progress"] = 0.0
		actor["being_revived"] = false
		actor["trapped"] = false
		actor["trapped_by"] = ""
		actor["trap_escape_progress"] = 0
		actor["trap_expected_left"] = true
		actor["trap_prompt"] = ""
		actor["adrenaline_until"] = 0.0
		actor["fatigue_until"] = 0.0
		actor["teleport_started"] = -1.0
		actor["teleport_ends"] = -1.0
		actors[peer_id_variant] = actor


func _move_actor(
	peer_id: int,
	actor: Dictionary,
	role: String,
	input_vector: Vector2,
	delta: float,
	speed_multiplier := 1.0,
	collide_with_actors := true,
) -> void:
	if input_vector.is_zero_approx():
		return
	var intended_direction := input_vector.limit_length(1.0).normalized()
	actor["facing"] = intended_direction
	actor["dir"] = _direction_name(intended_direction)
	var motion := intended_direction * ACTOR_SPEED * speed_multiplier * delta
	var subdivisions := maxi(1, int(ceil(motion.length() / 0.05)))
	var movement_step := motion / float(subdivisions)
	for _index in range(subdivisions):
		if not is_zero_approx(movement_step.x):
			_move_actor_axis(
				peer_id,
				actor,
				role,
				Vector2(movement_step.x, 0),
				collide_with_actors,
			)
		if not is_zero_approx(movement_step.y):
			_move_actor_axis(
				peer_id,
				actor,
				role,
				Vector2(0, movement_step.y),
				collide_with_actors,
			)
	actor["facing"] = intended_direction
	actor["dir"] = _direction_name(intended_direction)


func _move_actor_axis(
	peer_id: int,
	actor: Dictionary,
	role: String,
	motion: Vector2,
	collide_with_actors := true,
) -> void:
	var room_coord: Vector2i = actor["room"]
	var room := room_at(room_coord)
	var target_room := room_coord
	var target_position: Vector2 = actor["pos"] + motion
	if (
		target_position.x < 0.0
		or target_position.x >= ROOM_SIZE
		or target_position.y < 0.0
		or target_position.y >= ROOM_SIZE
	):
		var room_delta := Vector2i(
			int(signf(motion.x)) if not is_zero_approx(motion.x) else 0,
			int(signf(motion.y)) if not is_zero_approx(motion.y) else 0,
		)
		var aligned := (
			absf((actor["pos"] as Vector2).y - ROOM_SIZE * 0.5) <= 0.72
			if room_delta.x != 0
			else absf((actor["pos"] as Vector2).x - ROOM_SIZE * 0.5) <= 0.72
		)
		if not room["doors"].has(_direction_name(motion)) or not aligned:
			return
		target_room += room_delta
		if (
			target_room.x < 0
			or target_room.y < 0
			or target_room.x >= MAP_SIZE
			or target_room.y >= MAP_SIZE
		):
			return
		if target_position.x < 0.0:
			target_position.x += ROOM_SIZE
		if target_position.x >= ROOM_SIZE:
			target_position.x -= ROOM_SIZE
		if target_position.y < 0.0:
			target_position.y += ROOM_SIZE
		if target_position.y >= ROOM_SIZE:
			target_position.y -= ROOM_SIZE

	var target_room_data := room_at(target_room)
	if not MANSION_COLLISION.position_clears_room_walls(
		target_room_data,
		target_position,
		role,
	):
		return
	for furniture_variant in target_room_data["furniture"]:
		var furniture: Dictionary = furniture_variant
		if bool(furniture.get("destroyed", false)):
			continue
		if MANSION_COLLISION.actor_overlaps_furniture(target_position, furniture, role):
			return
	if collide_with_actors:
		for other_peer_id_variant in actors:
			var other_peer_id := int(other_peer_id_variant)
			if other_peer_id == peer_id:
				continue
			var other: Dictionary = actors[other_peer_id_variant]
			if bool(other.get("extracted", false)):
				continue
			if other["room"] != target_room:
				continue
			var other_role := _role_for_slot(str(other.get("slot", "")))
			var minimum_distance := (
				MANSION_COLLISION.actor_radius(role)
				+ MANSION_COLLISION.actor_radius(other_role)
			)
			if (other["pos"] as Vector2).distance_to(target_position) < minimum_distance:
				return
	actor["room"] = target_room
	actor["pos"] = target_position
	actor["moving"] = true


func room_at(room_coord: Vector2i) -> Dictionary:
	return rooms[room_coord.y * MAP_SIZE + room_coord.x]


func _furniture_in_front(actor: Dictionary) -> Dictionary:
	var room := room_at(actor["room"])
	var facing: Vector2 = actor.get("facing", Vector2.DOWN)
	var best: Dictionary = {}
	var best_distance := INF
	for furniture_variant in room["furniture"]:
		var furniture: Dictionary = furniture_variant
		if bool(furniture.get("destroyed", false)):
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


func _active_storage_furniture(peer_id: int) -> Dictionary:
	var storage_id := str(active_storage_by_peer.get(peer_id, ""))
	if storage_id.is_empty() or not actors.has(peer_id):
		return {}
	var actor: Dictionary = actors[peer_id]
	var room := room_at(actor["room"])
	var furniture := _find_furniture(room, storage_id)
	if (
		furniture.is_empty()
		or not bool(furniture.get("opened", false))
		or bool(furniture.get("destroyed", false))
	):
		return {}
	if (furniture["pos"] as Vector2).distance_to(actor["pos"]) > STORAGE_REACH:
		return {}
	return furniture


func _refresh_furniture_durability(furniture: Dictionary) -> void:
	var durability := int(furniture.get("base_durability", furniture.get("durability", 1)))
	for content_variant in furniture.get("contents", []):
		var content: Dictionary = content_variant
		if str(content.get("kind", "")) in ["treasure", "trinket"]:
			durability += int(content.get("value", 0))
	furniture["durability"] = maxi(durability, 1)


func _furniture_has_primary_content(furniture: Dictionary) -> bool:
	for content_variant in furniture.get("contents", []):
		var content: Dictionary = content_variant
		if str(content.get("kind", "")) in ["treasure", "alarm"]:
			return true
	return false


func _treasure_is_deployed(treasure_id: String) -> bool:
	for room_variant in rooms:
		var room: Dictionary = room_variant
		for furniture_variant in room["furniture"]:
			var furniture: Dictionary = furniture_variant
			for content_variant in furniture.get("contents", []):
				var content: Dictionary = content_variant
				if str(content.get("id", "")) == treasure_id:
					return true
		for item_variant in room["items"]:
			var item: Dictionary = item_variant
			if (
				str(item.get("id", "")) == treasure_id
				and not bool(item.get("collected", false))
			):
				return true
	return false


func _release_furniture_contents(room: Dictionary, furniture: Dictionary) -> Array:
	var released_items: Array = []
	var contents: Array = furniture["contents"]
	for index in range(contents.size()):
		var item: Dictionary = (contents[index] as Dictionary).duplicate(true)
		var angle := TAU * float(index) / float(maxi(contents.size(), 1))
		var offset := Vector2.RIGHT.rotated(angle) * (0.28 + 0.08 * float(index))
		item["pos"] = (furniture["pos"] as Vector2) + offset
		item["collected"] = false
		room["items"].append(item)
		released_items.append(item.duplicate(true))
	contents.clear()
	return released_items


func _find_furniture(room: Dictionary, furniture_id: String) -> Dictionary:
	for furniture_variant in room["furniture"]:
		var furniture: Dictionary = furniture_variant
		if str(furniture.get("id", "")) == furniture_id:
			return furniture
	return {}


func _room_has_item(room: Dictionary, item_id: String) -> bool:
	for item_variant in room["items"]:
		var item: Dictionary = item_variant
		if str(item.get("id", "")) == item_id:
			return true
	return false


func _find_item(room: Dictionary, item_id: String) -> Dictionary:
	for item_variant in room["items"]:
		var item: Dictionary = item_variant
		if str(item.get("id", "")) == item_id:
			return item
	return {}


func _furniture_event(
	peer_id: int,
	room_coord: Vector2i,
	furniture: Dictionary,
	released_items: Array,
	message: String,
	storage_id: String,
	play_hit_animation := false,
) -> Dictionary:
	var actor: Dictionary = actors.get(peer_id, {})
	return {
		"accepted": true,
		"kind": "furniture",
		"requester_peer_id": peer_id,
		"room": room_coord,
		"furniture": {
			"id": str(furniture["id"]),
			"opened": bool(furniture.get("opened", false)),
			"destroyed": bool(furniture.get("destroyed", false)),
			"damage": int(furniture.get("damage", 0)),
			"durability": int(furniture.get("durability", 1)),
			"contents": (furniture.get("contents", []) as Array).duplicate(true),
			"last_hit_time": float(furniture.get("last_hit_time", elapsed)),
		},
		"released_items": released_items.duplicate(true),
		"message": message,
		"storage_id": storage_id,
		"play_hit_animation": play_hit_animation,
		"action_started_at": elapsed,
		"action_facing": actor.get("facing", Vector2.DOWN),
	}


func _rejected_event(peer_id: int, message: String) -> Dictionary:
	return {
		"accepted": false,
		"kind": "feedback",
		"requester_peer_id": peer_id,
		"message": message,
	}


static func spawn_for_slot(slot: String) -> Dictionary:
	match slot:
		"monster":
			return {"room": MONSTER_SPAWN_ROOM, "pos": MONSTER_SPAWN_POS}
		"thief-1":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(0.55, 4.45)}
		"thief-2":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(1.10, 4.40)}
		"thief-3":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(0.60, 3.85)}
	return {"room": ENTRANCE_ROOM, "pos": Vector2(1.20, 3.80)}


static func combat_test_spawn_for_slot(slot: String) -> Dictionary:
	match slot:
		"monster":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(2.0, 3.8)}
		"thief-1":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(1.0, 3.8)}
		"thief-2":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(1.4, 3.1)}
		"thief-3":
			return {"room": ENTRANCE_ROOM, "pos": Vector2(1.4, 4.5)}
	return {"room": ENTRANCE_ROOM, "pos": Vector2(1.20, 3.80)}


static func _role_for_slot(slot: String) -> String:
	return "monster" if slot == "monster" else "thief"


static func _direction_name(motion: Vector2) -> String:
	if absf(motion.x) > absf(motion.y):
		return "right" if motion.x > 0.0 else "left"
	return "down" if motion.y > 0.0 else "up"


static func _direction_index(direction: String) -> int:
	match direction:
		"up": return 0
		"right": return 1
		"down": return 2
	return 3


static func _phase_index(phase_name: String) -> int:
	match phase_name:
		"hide": return 0
		"ready": return 1
		"hunt": return 2
	return 3
