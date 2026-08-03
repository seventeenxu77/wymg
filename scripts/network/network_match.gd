class_name NetworkMatch
extends Control

signal leave_requested

const MAIN_MENU_STYLE := preload("res://scripts/presentation/main_menu_overlay_style.gd")
const NETWORK_LAUNCH_OPTIONS := preload("res://scripts/network/network_launch_options.gd")
const NETWORK_MANSION_STATE_SCRIPT := preload("res://scripts/network/network_mansion_state.gd")
const NETWORK_TOOL_CATALOG := preload("res://scripts/network/network_tool_catalog.gd")
const PROFESSION_CATALOG := preload(
	"res://scripts/professions/profession_catalog.gd"
)
const WORLD_25D_SCRIPT := preload("res://scripts/world_25d.gd")
const GAME_STATE_BASE := preload("res://scripts/systems/game_state_base.gd")
const UI_FONT: Font = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const MODAL_PANEL_TEXTURE: Texture2D = preload("res://assets/ui/modal_panel.png")
const HEADER_PLAQUE_TEXTURE: Texture2D = preload("res://assets/ui/header_plaque.png")
const INVENTORY_SLOT_TEXTURE: Texture2D = preload("res://assets/ui/inventory_slot.png")
const VIEWPORT_FRAME_TEXTURE: Texture2D = preload(
	"res://assets/ui/viewport_frame_handdrawn.png"
)
const ALARM_ICON_TEXTURE: Texture2D = preload("res://assets/ui/icons/alarm.png")
const TOOL_ICON_TEXTURES := {
	"adrenaline": preload("res://assets/ui/icons/adrenaline.png"),
	"decoy": preload("res://assets/ui/icons/decoy.png"),
	"phonograph": preload("res://assets/ui/icons/phonograph.png"),
	"trap": preload("res://assets/ui/icons/trap.png"),
	"detector": preload("res://assets/ui/icons/detector.png"),
	"alarm": preload("res://assets/ui/icons/alarm.png"),
	"teleporter": preload("res://assets/ui/icons/teleporter.png"),
	"spring_glove": preload("res://assets/ui/icons/spring_glove.png"),
	"robot": preload("res://assets/ui/icons/robot.png"),
}
const ATTACK_SOUND: AudioStream = preload("res://GJGamejam素材/music/swordslashsound.mp3")
const HIT_SOUND: AudioStream = preload("res://GJGamejam素材/music/malehorrorscream.mp3")
const TREASURE_ICON_TEXTURES := {
	"treasure-1": preload("res://GJGamejam素材/2.5D物品/copper_coin.png"),
	"treasure-2": preload("res://assets/25d/items/silver_candlestick.png"),
	"treasure-3": preload("res://assets/25d/items/emerald_brooch.png"),
	"treasure-5": preload("res://assets/25d/items/monster_heart.png"),
}

const SNAPSHOT_INTERVAL := 1.0 / 20.0
const INPUT_INTERVAL := 1.0 / 30.0
const INTERPOLATION_SPEED := 14.0
const AFTERIMAGE_SAMPLE_INTERVAL := 0.16
const RESOURCE_WARMUP_FRAMES := 2
const MONSTER_COLOR := Color("#ff6b4a")
const THIEF_COLOR := Color("#66d9c3")

var session: NetworkSession
var mansion_state: NetworkMansionState
var world_renderer: World25D
var active := false
var world_initialized := false
var local_resources_ready := false
var match_live := false
var pending_live_start := false
var world_seed := 0
var initializing_world_seed := 0
var player_snapshot: Dictionary = {}
var resource_ready_peers: Dictionary = {}
var authoritative_positions: Dictionary = {}
var target_actors: Dictionary = {}
var display_actors: Dictionary = {}
var server_inputs: Dictionary = {}
var server_rescue_inputs: Dictionary = {}
var server_skill_inputs: Dictionary = {}
var last_input_sequences: Dictionary = {}
var snapshot_accumulator := 0.0
var input_accumulator := 0.0
var local_input_sequence := 0
var last_snapshot_tick := -1
var server_tick := 0
var phase := "loading"
var seconds_left := 0
var match_elapsed := 0.0
var winner := ""
var result_reason := ""
var extracted_core_count := 0
var team_wipe_started_at := -1.0
var total_extracted_value := 0
var escaped_thief_count := 0
var result_player_rows: Array = []
var movement_logged: Dictionary = {}
var snapshot_movement_logged: Dictionary = {}
var debug_input := ""
var debug_skip_hide := false
var debug_combat_test := false
var debug_tool_test := false
var pending_world_seed := 0
var pending_skip_hide := false
var pending_combat_test := false
var pending_tool_test := false
var active_storage_id := ""
var selected_treasure := 0
var carrying_panel_open := false
var selected_carried_loot := 0
var feedback_message := ""
var feedback_seconds := 0.0
var actor_hit_animations: Dictionary = {}
var network_afterimages: Array = []
var last_afterimage_at_by_peer: Dictionary = {}
var network_afterimage_serial := 0
var status_label: Label
var detail_label: Label
var instructions_label: Label
var leave_button: Button
var modal_panel_style: StyleBoxTexture
var header_plaque_style: StyleBoxTexture
var inventory_slot_style: StyleBoxTexture
var toolbelt_tray_style: StyleBoxTexture
var toolbelt_slot_style: StyleBoxTexture


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = Theme.new()
	theme.default_font = UI_FONT
	theme.default_font_size = 20
	modal_panel_style = _make_texture_style(MODAL_PANEL_TEXTURE, 66.0, 56.0)
	header_plaque_style = _make_texture_style(HEADER_PLAQUE_TEXTURE, 58.0, 30.0)
	inventory_slot_style = _make_texture_style(INVENTORY_SLOT_TEXTURE, 42.0, 26.0)
	toolbelt_tray_style = _make_texture_style(
		VIEWPORT_FRAME_TEXTURE,
		74.0,
		68.0,
	)
	toolbelt_slot_style = _make_texture_style(
		VIEWPORT_FRAME_TEXTURE,
		74.0,
		68.0,
	)
	var launch_options := NETWORK_LAUNCH_OPTIONS.parse(OS.get_cmdline_user_args())
	debug_input = str(launch_options.get("debug_input", ""))
	debug_skip_hide = bool(launch_options.get("debug_skip_hide", false))
	debug_combat_test = bool(launch_options.get("debug_combat_test", false))
	debug_tool_test = bool(launch_options.get("debug_tool_test", false))
	resized.connect(_sync_world_viewport_size)
	_build_ui()
	set_physics_process(true)
	hide()


func _sync_world_viewport_size() -> void:
	if not world_renderer:
		return
	world_renderer.set_network_viewport_size(Vector2i(
		maxi(roundi(size.x), 320),
		maxi(roundi(size.y), 180),
	))


func _create_network_world_renderer() -> void:
	if world_renderer or DisplayServer.get_name() == "headless":
		return
	world_renderer = WORLD_25D_SCRIPT.new()
	world_renderer.name = "NetworkWorld25D"
	add_child(world_renderer)
	world_renderer.setup(null, true, _local_role())
	_sync_world_viewport_size()


func _dispose_network_world_renderer() -> void:
	if not world_renderer:
		return
	var stale_renderer := world_renderer
	world_renderer = null
	if stale_renderer.get_parent():
		stale_renderer.get_parent().remove_child(stale_renderer)
	stale_renderer.free()


func _make_texture_style(
	texture: Texture2D,
	horizontal_margin: float,
	vertical_margin: float,
) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = horizontal_margin
	style.texture_margin_top = vertical_margin
	style.texture_margin_right = horizontal_margin
	style.texture_margin_bottom = vertical_margin
	return style


func setup(next_session: NetworkSession) -> void:
	session = next_session
	if not session.players_changed.is_connected(_on_players_changed):
		session.players_changed.connect(_on_players_changed)
	if not session.match_ended.is_connected(_on_match_ended):
		session.match_ended.connect(_on_match_ended)


func start_match(players: Dictionary) -> void:
	if not session:
		return
	active = true
	world_initialized = false
	local_resources_ready = false
	match_live = false
	pending_live_start = false
	initializing_world_seed = 0
	player_snapshot = players.duplicate(true)
	resource_ready_peers.clear()
	mansion_state = null
	authoritative_positions.clear()
	target_actors.clear()
	display_actors.clear()
	server_inputs.clear()
	server_rescue_inputs.clear()
	server_skill_inputs.clear()
	last_input_sequences.clear()
	snapshot_accumulator = 0.0
	input_accumulator = 0.0
	local_input_sequence = 0
	last_snapshot_tick = -1
	server_tick = 0
	phase = "loading"
	seconds_left = 0
	match_elapsed = 0.0
	winner = ""
	result_reason = ""
	extracted_core_count = 0
	team_wipe_started_at = -1.0
	total_extracted_value = 0
	escaped_thief_count = 0
	result_player_rows.clear()
	active_storage_id = ""
	selected_treasure = 0
	carrying_panel_open = false
	selected_carried_loot = 0
	feedback_message = ""
	feedback_seconds = 0.0
	actor_hit_animations.clear()
	network_afterimages.clear()
	last_afterimage_at_by_peer.clear()
	network_afterimage_serial = 0
	movement_logged.clear()
	snapshot_movement_logged.clear()
	for peer_id_variant in player_snapshot:
		server_inputs[int(peer_id_variant)] = Vector2.ZERO
		server_rescue_inputs[int(peer_id_variant)] = false
		server_skill_inputs[int(peer_id_variant)] = false
	show()
	if instructions_label:
		instructions_label.hide()
	_refresh_status()
	queue_redraw()
	print(
		"[NetworkMatch][%s] started peer=%d players=%d"
		% [session.local_name, session.local_peer_id(), player_snapshot.size()]
	)
	if session.is_server():
		var seed_value := absi(hash(
			"%d:%d:%s"
			% [
				int(Time.get_unix_time_from_system()),
				Time.get_ticks_usec(),
				session.local_name,
			]
		))
		_begin_world_initialization(
			seed_value,
			debug_skip_hide,
			debug_combat_test,
			debug_tool_test,
		)
		_receive_world.rpc(
			seed_value,
			debug_skip_hide,
			debug_combat_test,
			debug_tool_test,
		)
	elif pending_world_seed != 0:
		var seed_value := pending_world_seed
		var skip_hide := pending_skip_hide
		var combat_test := pending_combat_test
		var tool_test := pending_tool_test
		pending_world_seed = 0
		pending_skip_hide = false
		pending_combat_test = false
		pending_tool_test = false
		_begin_world_initialization(seed_value, skip_hide, combat_test, tool_test)


func stop_match() -> void:
	active = false
	world_initialized = false
	local_resources_ready = false
	match_live = false
	pending_live_start = false
	initializing_world_seed = 0
	player_snapshot.clear()
	resource_ready_peers.clear()
	authoritative_positions.clear()
	target_actors.clear()
	display_actors.clear()
	server_inputs.clear()
	server_rescue_inputs.clear()
	server_skill_inputs.clear()
	mansion_state = null
	pending_world_seed = 0
	pending_skip_hide = false
	pending_combat_test = false
	pending_tool_test = false
	winner = ""
	result_reason = ""
	extracted_core_count = 0
	team_wipe_started_at = -1.0
	total_extracted_value = 0
	escaped_thief_count = 0
	result_player_rows.clear()
	active_storage_id = ""
	selected_treasure = 0
	carrying_panel_open = false
	selected_carried_loot = 0
	feedback_message = ""
	feedback_seconds = 0.0
	actor_hit_animations.clear()
	network_afterimages.clear()
	last_afterimage_at_by_peer.clear()
	_dispose_network_world_renderer()
	hide()


func handle_input(event: InputEvent) -> bool:
	if not active:
		return false
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return false
	if event.keycode == KEY_ESCAPE:
		if carrying_panel_open:
			carrying_panel_open = false
			queue_redraw()
			return true
		if not active_storage_id.is_empty():
			active_storage_id = ""
			queue_redraw()
			return true
		leave_requested.emit()
		return true
	if not match_live:
		return true
	if phase == "finished":
		return true
	var local_actor := _local_display_actor()
	if bool(local_actor.get("trapped", false)):
		carrying_panel_open = false
		var pressed_left: bool = (
			event.physical_keycode == KEY_A
			or event.keycode == KEY_LEFT
		)
		var pressed_right: bool = (
			event.physical_keycode == KEY_D
			or event.keycode == KEY_RIGHT
		)
		if pressed_left or pressed_right:
			_request_action("trap_escape", {"left": pressed_left})
			return true
	if carrying_panel_open and _handle_carrying_panel_input(event):
		return true
	var pressed_key: int = int(
		event.physical_keycode
		if event.physical_keycode != 0
		else event.keycode
	)
	match pressed_key:
		KEY_Q:
			if world_renderer:
				world_renderer.rotate_camera(_local_role(), -1)
			return true
		KEY_E:
			if world_renderer:
				world_renderer.rotate_camera(_local_role(), 1)
			return true
		KEY_H:
			_request_action("end_hide")
			return true
		KEY_SHIFT:
			if (
				not str(local_actor.get("profession_id", "")).is_empty()
				and str(local_actor.get("profession_id", "")) != "support"
			):
				_request_action("use_active_skill")
			return true
		KEY_SPACE:
			if _local_role() == "monster":
				_request_action("attack")
			return true
		KEY_F:
			return true
		KEY_Z:
			_request_action("cycle_tool", {"direction": -1})
			return true
		KEY_X:
			_request_action("cycle_tool", {"direction": 1})
			return true
		KEY_C:
			_request_action("use_tool")
			return true
		KEY_G:
			_request_action("interact_furniture")
			return true
		KEY_A:
			if not active_storage_id.is_empty():
				selected_treasure = (
					selected_treasure - 1 + GAME_STATE_BASE.TREASURES.size()
				) % GAME_STATE_BASE.TREASURES.size()
				queue_redraw()
				return true
		KEY_D:
			if not active_storage_id.is_empty():
				selected_treasure = (
					selected_treasure + 1
				) % GAME_STATE_BASE.TREASURES.size()
				queue_redraw()
				return true
		KEY_R:
			if not active_storage_id.is_empty():
				_request_action("toggle_treasure", {"treasure_index": selected_treasure})
				return true
			if _local_role() == "thief":
				_request_action("pickup_item")
				return true
		KEY_B:
			if _local_role() == "thief":
				var carried_loot: Array = local_actor.get("carried_loot", [])
				if not carried_loot.is_empty():
					carrying_panel_open = true
					selected_carried_loot = clampi(
						selected_carried_loot,
						0,
						carried_loot.size() - 1,
					)
					queue_redraw()
				return true
		KEY_T:
			if _local_role() == "thief":
				_request_action("quick_drop_loot")
				return true
		KEY_V:
			if _local_role() == "thief":
				_request_action("extract")
				return true
	return false


func _handle_carrying_panel_input(event: InputEventKey) -> bool:
	var carried_loot: Array = _local_display_actor().get("carried_loot", [])
	if carried_loot.is_empty():
		carrying_panel_open = false
		selected_carried_loot = 0
		queue_redraw()
		return true
	var key: int = int(
		event.physical_keycode
		if event.physical_keycode != 0
		else event.keycode
	)
	match key:
		KEY_W, KEY_UP:
			selected_carried_loot = posmod(
				selected_carried_loot - 1,
				carried_loot.size(),
			)
			queue_redraw()
			return true
		KEY_S, KEY_DOWN:
			selected_carried_loot = posmod(
				selected_carried_loot + 1,
				carried_loot.size(),
			)
			queue_redraw()
			return true
		KEY_R:
			var selected: Dictionary = carried_loot[clampi(
				selected_carried_loot,
				0,
				carried_loot.size() - 1,
			)]
			_request_action("drop_loot", {
				"loot_id": str(selected.get("id", "")),
			})
			return true
		KEY_T:
			_request_action("quick_drop_loot")
			return true
		KEY_B:
			carrying_panel_open = false
			queue_redraw()
			return true
	return key in [KEY_A, KEY_D, KEY_LEFT, KEY_RIGHT]


func _physics_process(delta: float) -> void:
	if (
		not active
		or not session
		or not session.is_online()
		or not world_initialized
		or not match_live
	):
		return
	feedback_seconds = maxf(feedback_seconds - delta, 0.0)
	if phase != "hide":
		active_storage_id = ""

	var local_input := _read_local_input()
	if world_renderer:
		local_input = world_renderer.camera_relative_vector(_local_role(), local_input)
	if session.is_server():
		var peer_id := session.local_peer_id()
		if player_snapshot.has(peer_id):
			server_inputs[peer_id] = local_input
			server_rescue_inputs[peer_id] = _read_local_rescue_input()
			server_skill_inputs[peer_id] = _read_local_skill_input()
	else:
		input_accumulator += delta
		if input_accumulator >= INPUT_INTERVAL:
			input_accumulator = fmod(input_accumulator, INPUT_INTERVAL)
			local_input_sequence += 1
			_submit_input.rpc_id(
				1,
				local_input,
				_read_local_rescue_input(),
				_read_local_skill_input(),
				local_input_sequence,
			)

	if session.is_server():
		_server_step(delta)
		snapshot_accumulator += delta
		if snapshot_accumulator >= SNAPSHOT_INTERVAL:
			snapshot_accumulator = fmod(snapshot_accumulator, SNAPSHOT_INTERVAL)
			server_tick += 1
			var snapshot := mansion_state.snapshot()
			_apply_snapshot(snapshot, server_tick)
			_receive_snapshot.rpc(snapshot, server_tick)
	else:
		_interpolate_display_actors(delta)
	_apply_actor_hit_animations()
	_update_network_afterimages()
	mansion_state.prune_noises(match_elapsed)

	if world_renderer and not display_actors.is_empty():
		world_renderer.sync_network(
			mansion_state.rooms,
			display_actors,
			session.local_peer_id(),
			match_elapsed,
			network_afterimages,
		)
	_refresh_status()
	queue_redraw()


@rpc("authority", "call_remote", "reliable")
func _receive_world(
	seed_value: int,
	skip_hide: bool,
	combat_test: bool,
	tool_test: bool,
) -> void:
	if not active or player_snapshot.is_empty():
		pending_world_seed = seed_value
		pending_skip_hide = skip_hide
		pending_combat_test = combat_test
		pending_tool_test = tool_test
		return
	_begin_world_initialization(seed_value, skip_hide, combat_test, tool_test)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func _submit_input(
	input_vector: Vector2,
	rescue_held: bool,
	skill_held: bool,
	sequence: int,
) -> void:
	if (
		not session
		or not session.is_server()
		or not active
		or not world_initialized
		or not match_live
	):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	_set_server_input(peer_id, input_vector, sequence)
	server_rescue_inputs[peer_id] = rescue_held
	server_skill_inputs[peer_id] = skill_held


@rpc("any_peer", "call_remote", "reliable")
func _submit_action(action: String, payload: Dictionary) -> void:
	if (
		not session
		or not session.is_server()
		or not active
		or not world_initialized
		or not match_live
	):
		return
	_apply_server_action(multiplayer.get_remote_sender_id(), action, payload)


@rpc("authority", "call_remote", "unreliable_ordered")
func _receive_snapshot(snapshot: Dictionary, tick: int) -> void:
	if not active or not world_initialized or tick <= last_snapshot_tick:
		return
	_apply_snapshot(snapshot, tick)


@rpc("authority", "call_remote", "reliable")
func _receive_world_event(event: Dictionary) -> void:
	if not active or not world_initialized or not mansion_state:
		return
	mansion_state.apply_world_event(event)
	_present_world_event(event)


func _begin_world_initialization(
	seed_value: int,
	skip_hide: bool,
	combat_test: bool = false,
	tool_test: bool = false,
) -> void:
	if (
		not active
		or (world_initialized and world_seed == seed_value)
		or initializing_world_seed == seed_value
	):
		return
	initializing_world_seed = seed_value
	queue_redraw()
	# Let the lightweight loading page reach the screen before the expensive
	# room/node build begins.
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	else:
		await get_tree().process_frame
	if not active or initializing_world_seed != seed_value:
		return
	var build_started_usec := Time.get_ticks_usec()
	_create_network_world_renderer()
	_initialize_world(seed_value, combat_test, tool_test)
	if world_renderer:
		var viewport_count := (
			int(is_instance_valid(world_renderer.monster_viewport))
			+ int(is_instance_valid(world_renderer.thief_viewport))
		)
		print(
			(
				"[NetworkMatch][%s] renderer ready role=%s viewports=%d "
				+ "floor_materials=%d build_ms=%.1f"
			) % [
				session.local_name,
				_local_role(),
				viewport_count,
				world_renderer.floor_texture_materials.size(),
				float(Time.get_ticks_usec() - build_started_usec) / 1000.0,
			]
		)
	initializing_world_seed = 0
	if skip_hide and mansion_state:
		mansion_state.begin_hunt_countdown()


func _initialize_world(
	seed_value: int,
	combat_test: bool = false,
	tool_test: bool = false,
) -> void:
	if world_initialized and world_seed == seed_value:
		return
	world_seed = seed_value
	mansion_state = NETWORK_MANSION_STATE_SCRIPT.new()
	mansion_state.debug_combat_spawns = combat_test or tool_test
	mansion_state.debug_tool_loadouts = tool_test
	mansion_state.initialize(world_seed, player_snapshot)
	target_actors = mansion_state.actors.duplicate(true)
	display_actors = mansion_state.actors.duplicate(true)
	phase = mansion_state.phase
	seconds_left = mansion_state.seconds_left
	match_elapsed = mansion_state.elapsed
	_sync_authoritative_positions()
	if world_renderer:
		world_renderer.rebuild(mansion_state.rooms)
	world_initialized = true
	call_deferred("_finish_local_resource_warmup", seed_value)
	print(
		"[NetworkMatch][%s] mansion seed=%d rooms=%d actors=%d"
		% [session.local_name, world_seed, mansion_state.rooms.size(), mansion_state.actors.size()]
	)


func _finish_local_resource_warmup(seed_value: int) -> void:
	if not active or not world_initialized or world_seed != seed_value:
		return
	if world_renderer and not display_actors.is_empty():
		# Build actor sprites, room visibility and render pipelines while the
		# loading page is still covering the formal match.
		world_renderer.sync_network(
			mansion_state.rooms,
			display_actors,
			session.local_peer_id(),
			match_elapsed,
			network_afterimages,
		)
		for _frame in range(RESOURCE_WARMUP_FRAMES):
			await RenderingServer.frame_post_draw
			if not active or world_seed != seed_value:
				return
	local_resources_ready = true
	var local_peer_id := session.local_peer_id()
	if player_snapshot.has(local_peer_id):
		resource_ready_peers[local_peer_id] = true
	if session.is_server():
		_mark_peer_resources_ready(local_peer_id, seed_value)
	else:
		_submit_resources_ready.rpc_id(1, seed_value)
	if pending_live_start:
		_activate_live_match(seed_value)
	_refresh_status()
	queue_redraw()


@rpc("any_peer", "call_remote", "reliable")
func _submit_resources_ready(seed_value: int) -> void:
	if not session or not session.is_server() or not active:
		return
	_mark_peer_resources_ready(multiplayer.get_remote_sender_id(), seed_value)


func _mark_peer_resources_ready(peer_id: int, seed_value: int) -> void:
	if (
		not session
		or not session.is_server()
		or not world_initialized
		or seed_value != world_seed
		or not player_snapshot.has(peer_id)
	):
		return
	resource_ready_peers[peer_id] = true
	_broadcast_resource_ready_peers()
	_try_begin_live_match()


func _broadcast_resource_ready_peers() -> void:
	if not session or not session.is_server():
		return
	var ids := PackedInt32Array()
	for peer_id_variant in resource_ready_peers:
		var peer_id := int(peer_id_variant)
		if player_snapshot.has(peer_id):
			ids.append(peer_id)
	ids.sort()
	_receive_resource_ready_peers.rpc(world_seed, ids)


@rpc("authority", "call_remote", "reliable")
func _receive_resource_ready_peers(seed_value: int, peer_ids: PackedInt32Array) -> void:
	if not active or not world_initialized or seed_value != world_seed:
		return
	resource_ready_peers.clear()
	for peer_id in peer_ids:
		resource_ready_peers[int(peer_id)] = true
	_refresh_status()
	queue_redraw()


func _try_begin_live_match() -> void:
	if (
		not session
		or not session.is_server()
		or not active
		or not world_initialized
		or match_live
	):
		return
	var required_peer_ids: Array[int] = []
	for peer_id_variant in player_snapshot:
		var peer_id := int(peer_id_variant)
		var player: Dictionary = player_snapshot[peer_id_variant]
		if str(player.get("slot", "spectator")) == "spectator":
			continue
		if not mansion_state.actors.has(peer_id):
			continue
		required_peer_ids.append(peer_id)
	for peer_id in required_peer_ids:
		if not resource_ready_peers.has(peer_id):
			return
	if required_peer_ids.is_empty():
		return
	_begin_live_match.rpc(world_seed)
	_activate_live_match(world_seed)


@rpc("authority", "call_remote", "reliable")
func _begin_live_match(seed_value: int) -> void:
	if not active or not world_initialized or seed_value != world_seed:
		return
	if not local_resources_ready:
		pending_live_start = true
		return
	_activate_live_match(seed_value)


func _activate_live_match(seed_value: int) -> void:
	if not active or not world_initialized or seed_value != world_seed or match_live:
		return
	pending_live_start = false
	match_live = true
	print(
		"[NetworkMatch][%s] all players ready; live match started seed=%d"
		% [session.local_name, world_seed]
	)
	_refresh_status()
	queue_redraw()


func _set_server_input(peer_id: int, input_vector: Vector2, sequence: int) -> void:
	if not mansion_state or not mansion_state.actors.has(peer_id):
		return
	if sequence <= int(last_input_sequences.get(peer_id, -1)):
		return
	last_input_sequences[peer_id] = sequence
	server_inputs[peer_id] = input_vector.limit_length(1.0)


func _server_step(delta: float) -> void:
	if not mansion_state:
		return
	mansion_state.step(
		delta,
		server_inputs,
		server_rescue_inputs,
		server_skill_inputs,
	)
	_flush_state_events()
	phase = mansion_state.phase
	seconds_left = mansion_state.seconds_left
	match_elapsed = mansion_state.elapsed
	_sync_authoritative_positions()
	for peer_id_variant in mansion_state.actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = mansion_state.actors[peer_id_variant]
		if movement_logged.has(peer_id):
			continue
		var spawn := NETWORK_MANSION_STATE_SCRIPT.spawn_for_slot(str(actor.get("slot", "")))
		var spawn_global := _logical_global_position(spawn["room"], spawn["pos"])
		var actor_global := _logical_global_position(actor["room"], actor["pos"])
		if actor_global.distance_to(spawn_global) <= 0.08:
			continue
		movement_logged[peer_id] = true
		print(
			"[NetworkMatch][server] mansion movement peer=%d room=%s pos=(%.2f, %.2f)"
			% [peer_id, str(actor["room"]), actor["pos"].x, actor["pos"].y]
		)


func _sync_authoritative_positions() -> void:
	authoritative_positions.clear()
	if not mansion_state:
		return
	for peer_id_variant in mansion_state.actors:
		var peer_id := int(peer_id_variant)
		authoritative_positions[peer_id] = (
			mansion_state.actors[peer_id_variant] as Dictionary
		)["pos"]


func _apply_snapshot(snapshot: Dictionary, tick: int) -> void:
	last_snapshot_tick = tick
	phase = _phase_from_index(int(snapshot.get("p", 3)))
	seconds_left = int(snapshot.get("t", seconds_left))
	match_elapsed = float(snapshot.get("e", match_elapsed))
	var match_record: PackedFloat32Array = snapshot.get(
		"m",
		PackedFloat32Array([0.0, 0.0, 0.0, -1.0, 0.0, 0.0]),
	)
	winner = NETWORK_MANSION_STATE_SCRIPT.winner_from_index(
		roundi(match_record[0]) if match_record.size() > 0 else 0,
	)
	result_reason = NETWORK_MANSION_STATE_SCRIPT.result_reason_from_index(
		roundi(match_record[1]) if match_record.size() > 1 else 0,
	)
	extracted_core_count = (
		roundi(match_record[2])
		if match_record.size() > 2
		else extracted_core_count
	)
	team_wipe_started_at = match_record[3] if match_record.size() > 3 else -1.0
	total_extracted_value = (
		roundi(match_record[4])
		if match_record.size() > 4
		else total_extracted_value
	)
	escaped_thief_count = (
		roundi(match_record[5])
		if match_record.size() > 5
		else escaped_thief_count
	)
	if mansion_state:
		mansion_state.apply_device_snapshot(
			snapshot.get("d", PackedFloat32Array()),
		)
	var actors: Dictionary = {}
	var actor_records: Dictionary = snapshot.get("a", {})
	var inventory_records: Dictionary = snapshot.get("i", {})
	for peer_id_variant in actor_records:
		var peer_id := int(peer_id_variant)
		var record: PackedFloat32Array = actor_records[peer_id_variant]
		if record.size() < 30:
			continue
		var player: Dictionary = player_snapshot.get(peer_id, {})
		var previous_actor: Dictionary = target_actors.get(peer_id, {})
		var state_actor: Dictionary = (
			mansion_state.actors.get(peer_id, {})
			if mansion_state
			else {}
		)
		var known_carried_loot: Array = state_actor.get(
			"carried_loot",
			previous_actor.get("carried_loot", []),
		)
		var direction := _direction_from_index(roundi(record[4]))
		var tools: Array = []
		var inventory_record: PackedFloat32Array = inventory_records.get(
			peer_id_variant,
			PackedFloat32Array([0]),
		)
		for inventory_index in range(
			1,
			inventory_record.size(),
			NETWORK_MANSION_STATE_SCRIPT.TOOL_INVENTORY_RECORD_STRIDE,
		):
			var tool_type := NETWORK_TOOL_CATALOG.type_from_index(
				roundi(inventory_record[inventory_index]),
			)
			if not tool_type.is_empty():
				var tool := NETWORK_TOOL_CATALOG.make_tool(
					tool_type,
					"snapshot-tool-%d-%d" % [peer_id, inventory_index],
				)
				if inventory_index + 4 < inventory_record.size():
					if tool_type == "detector":
						tool["charge"] = inventory_record[inventory_index + 1]
						tool["active"] = inventory_record[inventory_index + 2] > 0.5
					if tool_type == "robot":
						var robot_serial := roundi(
							inventory_record[inventory_index + 3]
						)
						tool["robot_serial"] = robot_serial
						tool["robot_id"] = (
							"network-device-%d" % robot_serial
							if robot_serial > 0
							else ""
						)
						tool["deployed"] = robot_serial > 0
						tool["stunned_until"] = inventory_record[inventory_index + 4]
				tools.append(tool)
		var expected_left := record[27] > 0.5
		actors[peer_id] = {
			"peer_id": peer_id,
			"name": str(player.get("name", "玩家")),
			"slot": str(player.get("slot", "spectator")),
			"profession_id": str(player.get("profession_id", "")),
			"room": Vector2i(roundi(record[0]), roundi(record[1])),
			"pos": Vector2(record[2], record[3]),
			"dir": direction,
			"facing": _direction_vector(direction),
			"moving": record[5] > 0.5,
			"hidden_from_monster": record[6] > 0.5,
			"carried_value": roundi(record[7]),
			"carried_count": roundi(record[8]),
			"carried_loot": known_carried_loot.duplicate(true),
			"carried_weight": roundi(record[30]) if record.size() > 30 else 0,
			"speed_multiplier": record[31] if record.size() > 31 else 1.0,
			"pills": roundi(record[9]),
			"extracted": record[10] > 0.5,
			"extracted_value": roundi(record[11]),
			"hp": roundi(record[12]),
			"downed": record[13] > 0.5,
			"hit_stun_until": record[14],
			"hit_invulnerable_until": record[15],
			"attack_started_at": record[16],
			"attack_ready_at": record[17],
			"hit_reaction_started_at": record[18],
			"hit_reaction_direction": Vector2(record[19], record[20]),
			"rescue_progress": record[21],
			"being_revived": record[22] > 0.5,
			"adrenaline_until": record[23],
			"fatigue_until": record[24],
			"trapped": record[25] > 0.5,
			"trap_escape_progress": roundi(record[26]),
			"trap_expected_left": expected_left,
			"trap_prompt": "A" if expected_left else "D",
			"tools": tools,
			"tool_selected": (
				clampi(
					roundi(inventory_record[0]),
					0,
					maxi(tools.size() - 1, 0),
				)
				if not inventory_record.is_empty()
				else 0
			),
			"teleport_started": record[28],
			"teleport_ends": record[29],
			"active_skill_ready_at": (
				record[32] if record.size() > 32 else 0.0
			),
			"active_skill_trap_count": (
				roundi(record[33]) if record.size() > 33 else 0
			),
			"scout_scan_until": (
				record[34]
				if (
					record.size() > 34
					and str(player.get("profession_id", "")) == "scout"
				)
				else 0.0
			),
			"scout_last_known_room": (
				NETWORK_MANSION_STATE_SCRIPT.unpacked_room_coord(roundi(record[35]))
				if record.size() > 35
				else Vector2i(-1, -1)
			),
			"scout_last_known_until": (
				record[36] if record.size() > 36 else 0.0
			),
			"support_heal_progress": (
				record[37] if record.size() > 37 else 0.0
			),
			"hauler_sprint_until": (
				record[34]
				if (
					record.size() > 34
					and str(player.get("profession_id", "")) == "hauler"
				)
				else 0.0
			),
			"rescue_required_seconds": (
				record[38]
				if record.size() > 38
				else NETWORK_MANSION_STATE_SCRIPT.REVIVE_SECONDS
			),
		}
	target_actors = actors.duplicate(true)
	if session.is_server():
		display_actors = target_actors.duplicate(true)
	for peer_id_variant in target_actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = target_actors[peer_id_variant]
		if display_actors.has(peer_id):
			continue
		display_actors[peer_id] = actor.duplicate(true)
	for peer_id_variant in display_actors.keys():
		if not target_actors.has(peer_id_variant):
			display_actors.erase(peer_id_variant)
	if phase == "finished" and result_player_rows.is_empty():
		result_player_rows = _fallback_result_rows()
	_sync_carrying_panel_state()
	_sync_local_detector_visuals()
	if session.is_server():
		return
	for peer_id_variant in target_actors:
		var peer_id := int(peer_id_variant)
		if snapshot_movement_logged.has(peer_id):
			continue
		var actor: Dictionary = target_actors[peer_id_variant]
		var spawn := NETWORK_MANSION_STATE_SCRIPT.spawn_for_slot(str(actor.get("slot", "")))
		var spawn_global := _logical_global_position(spawn["room"], spawn["pos"])
		var actor_global := _logical_global_position(actor["room"], actor["pos"])
		if actor_global.distance_to(spawn_global) <= 0.08:
			continue
		snapshot_movement_logged[peer_id] = true
		print(
			"[NetworkMatch][client] mansion snapshot peer=%d room=%s pos=(%.2f, %.2f)"
			% [peer_id, str(actor["room"]), actor["pos"].x, actor["pos"].y]
		)


func _sync_local_detector_visuals() -> void:
	if not mansion_state or not session:
		return
	for room_variant in mansion_state.rooms:
		var room: Dictionary = room_variant
		for furniture_variant in room["furniture"]:
			(furniture_variant as Dictionary)["detector_active"] = false
	var local_actor: Dictionary = target_actors.get(session.local_peer_id(), {})
	if local_actor.is_empty():
		return
	var detector_active := false
	for tool_variant in local_actor.get("tools", []):
		var tool: Dictionary = tool_variant
		if (
			str(tool.get("tool_type", "")) == "detector"
			and bool(tool.get("active", false))
		):
			detector_active = true
			break
	if not detector_active:
		return
	for furniture_variant in mansion_state.room_at(local_actor["room"])["furniture"]:
		(furniture_variant as Dictionary)["detector_active"] = true


func _interpolate_display_actors(delta: float) -> void:
	var weight := 1.0 - exp(-INTERPOLATION_SPEED * delta)
	for peer_id_variant in target_actors:
		var peer_id := int(peer_id_variant)
		var target: Dictionary = target_actors[peer_id_variant]
		var current: Dictionary = display_actors.get(peer_id, target).duplicate(true)
		var next_display := target.duplicate(true)
		if current.get("room", Vector2i(-1, -1)) == target.get("room", Vector2i(-2, -2)):
			next_display["pos"] = (current["pos"] as Vector2).lerp(target["pos"], weight)
		display_actors[peer_id] = next_display


func _update_network_afterimages() -> void:
	for index in range(network_afterimages.size() - 1, -1, -1):
		var image: Dictionary = network_afterimages[index]
		if match_elapsed >= float(image.get("expires", 0.0)):
			network_afterimages.remove_at(index)
	if not session or _local_role() != "monster":
		return
	for peer_id_variant in display_actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = display_actors[peer_id_variant]
		if (
			str(actor.get("slot", "")).begins_with("thief")
			and bool(actor.get("moving", false))
			and not bool(actor.get("extracted", false))
			and (
				not last_afterimage_at_by_peer.has(peer_id)
				or match_elapsed - float(last_afterimage_at_by_peer[peer_id])
				>= AFTERIMAGE_SAMPLE_INTERVAL
			)
		):
			last_afterimage_at_by_peer[peer_id] = match_elapsed
			network_afterimage_serial += 1
			network_afterimages.append({
				"id": "%d:%d" % [peer_id, network_afterimage_serial],
				"peer_id": peer_id,
				"room": actor["room"],
				"pos": actor["pos"],
				"created": match_elapsed,
				"expires": match_elapsed + GAME_STATE_BASE.AFTERIMAGE_LINGER_SECONDS,
			})


func _request_action(action: String, payload: Dictionary = {}) -> void:
	if not session or not world_initialized or not match_live:
		return
	if session.is_server():
		_apply_server_action(session.local_peer_id(), action, payload)
	else:
		_submit_action.rpc_id(1, action, payload)


func _apply_server_action(peer_id: int, action: String, payload: Dictionary = {}) -> void:
	if not mansion_state:
		return
	if action == "end_hide" and mansion_state.begin_hunt_countdown(peer_id):
		if session and peer_id == session.local_peer_id():
			active_storage_id = ""
		print("[NetworkMatch][server] monster ended hide phase.")
		return
	var event: Dictionary = {}
	match action:
		"interact_furniture":
			event = mansion_state.interact_furniture(peer_id)
		"toggle_treasure":
			event = mansion_state.toggle_treasure(
				peer_id,
				int(payload.get("treasure_index", -1)),
			)
		"pickup_item":
			event = mansion_state.pick_up_item(peer_id)
		"drop_loot":
			event = mansion_state.drop_carried_loot(
				peer_id,
				str(payload.get("loot_id", "")),
			)
		"quick_drop_loot":
			event = mansion_state.quick_drop_lowest_loot(peer_id)
		"extract":
			event = mansion_state.extract_thief(peer_id)
		"attack":
			event = mansion_state.attack(peer_id)
		"cycle_tool":
			event = mansion_state.cycle_tool(
				peer_id,
				int(payload.get("direction", 1)),
			)
		"use_tool":
			event = mansion_state.use_selected_tool(peer_id)
		"use_active_skill":
			event = mansion_state.use_active_skill(peer_id)
		"trap_escape":
			event = mansion_state.escape_trap(
				peer_id,
				bool(payload.get("left", true)),
			)
	if event.is_empty():
		_flush_state_events()
		return
	_broadcast_world_event(event)
	_flush_state_events()


func _broadcast_world_event(event: Dictionary) -> void:
	_present_world_event(event)
	if (
		session
		and session.is_server()
		and mansion_state
		and str(event.get("kind", "")) == "noise"
	):
		var noise: Dictionary = event.get("noise", {})
		var connected_peer_ids := multiplayer.get_peers()
		for peer_id_variant in mansion_state.actors:
			var peer_id := int(peer_id_variant)
			if peer_id == session.local_peer_id():
				continue
			if not connected_peer_ids.has(peer_id):
				continue
			if mansion_state.peer_can_hear_noise(peer_id, noise):
				_receive_world_event.rpc_id(peer_id, event)
		return
	_receive_world_event.rpc(event)


func _flush_state_events() -> void:
	if not mansion_state:
		return
	for event_variant in mansion_state.drain_world_events():
		var event: Dictionary = event_variant
		_broadcast_world_event(event)


func _present_world_event(event: Dictionary) -> void:
	if not session:
		return
	if (
		bool(event.get("accepted", false))
		and str(event.get("kind", "")) == "match_result"
	):
		_present_match_result(event)
	if (
		bool(event.get("accepted", false))
		and str(event.get("kind", "")) == "combat"
	):
		_present_combat_event(event)
	if (
		bool(event.get("accepted", false))
		and (
			str(event.get("kind", "")) == "tool"
			or str(event.get("kind", "")) == "skill"
			or (
				str(event.get("kind", "")) == "item"
				and event.has("actor")
			)
		)
	):
		_present_tool_event(event)
	if (
		bool(event.get("accepted", false))
		and str(event.get("kind", "")) == "furniture"
		and bool(event.get("play_hit_animation", false))
	):
		var actor_peer_id := int(event.get("requester_peer_id", 0))
		var facing: Vector2 = event.get("action_facing", Vector2.DOWN)
		actor_hit_animations[actor_peer_id] = {
			"started_at": float(event.get("action_started_at", match_elapsed)),
			"facing": facing.normalized() if not facing.is_zero_approx() else Vector2.DOWN,
		}
	if int(event.get("requester_peer_id", 0)) != session.local_peer_id():
		return
	feedback_message = str(event.get("message", ""))
	feedback_seconds = 3.0
	if bool(event.get("accepted", false)):
		active_storage_id = str(event.get("storage_id", active_storage_id))
	elif str(event.get("kind", "")) == "feedback" and phase != "hide":
		active_storage_id = ""
	queue_redraw()


func _present_match_result(event: Dictionary) -> void:
	winner = str(event.get("winner", ""))
	result_reason = str(event.get("reason", ""))
	extracted_core_count = int(event.get("extracted_core_count", 0))
	total_extracted_value = int(event.get("extracted_value", 0))
	escaped_thief_count = int(event.get("escaped_count", 0))
	result_player_rows = (event.get("player_results", []) as Array).duplicate(true)
	team_wipe_started_at = -1.0
	phase = "finished"
	seconds_left = 0
	active_storage_id = ""
	carrying_panel_open = false
	feedback_message = ""
	feedback_seconds = 0.0
	if leave_button:
		leave_button.text = "返回模式选择"
	_refresh_status()
	queue_redraw()


func _present_tool_event(event: Dictionary) -> void:
	var mutation: Dictionary = event.get("actor", {})
	if not mutation.is_empty():
		_present_tool_actor_mutation(mutation)
	for target_variant in event.get("target_actors", []):
		_present_tool_actor_mutation(target_variant)
	var local_peer_id := session.local_peer_id()
	var target_peer_id := int(event.get("target_peer_id", 0))
	if (
		target_peer_id == local_peer_id
		and str(event.get("tool_action", "")) == "trap_triggered"
	):
		feedback_message = "你踩中了捕兽夹！严格交替按 A / D 挣脱。"
		feedback_seconds = 4.0
	elif (
		target_peer_id == local_peer_id
		and str(event.get("tool_action", "")) == "spring_glove"
	):
		feedback_message = "你被弹簧拳套击退并眩晕。"
		feedback_seconds = 3.0
	elif (
		target_peer_id == local_peer_id
		and str(event.get("skill_action", "")) == "support_first_aid"
	):
		feedback_message = "支援者为你完成包扎，恢复了 1 点生命。"
		feedback_seconds = 3.0
	queue_redraw()


func _present_tool_actor_mutation(mutation: Dictionary) -> void:
	var peer_id := int(mutation.get("peer_id", 0))
	for actor_set in [target_actors, display_actors]:
		if not actor_set.has(peer_id):
			continue
		var actor: Dictionary = actor_set[peer_id]
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
			"carried_weight",
			"carried_loot",
			"active_skill_ready_at",
			"scout_scan_until",
			"scout_last_known_room",
			"scout_last_known_until",
			"support_heal_progress",
			"support_heal_target_peer_id",
			"medical_fatigue_until",
			"hauler_sprint_until",
			"hp",
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
			actor_set[peer_id] = actor
	_sync_carrying_panel_state()


func _present_combat_event(event: Dictionary) -> void:
	var combat_type := str(event.get("combat_type", ""))
	var attacker_peer_id := int(event.get("attacker_peer_id", 0))
	if combat_type == "attack":
		var attack_started_at := float(event.get("attack_started_at", match_elapsed))
		for actor_set in [target_actors, display_actors]:
			if actor_set.has(attacker_peer_id):
				var attacker: Dictionary = actor_set[attacker_peer_id]
				attacker["attack_started_at"] = attack_started_at
				actor_set[attacker_peer_id] = attacker
		_play_combat_sound(ATTACK_SOUND, -7.0)
	var local_peer_id := session.local_peer_id()
	for mutation_variant in event.get("targets", []):
		var mutation: Dictionary = mutation_variant
		var target_peer_id := int(mutation.get("peer_id", 0))
		for actor_set in [target_actors, display_actors]:
			if not actor_set.has(target_peer_id):
				continue
			var actor: Dictionary = actor_set[target_peer_id]
			for key in [
				"hp",
				"downed",
				"hit_stun_until",
				"hit_invulnerable_until",
				"hit_reaction_started_at",
				"hit_reaction_direction",
				"rescue_progress",
				"being_revived",
				"rescue_required_seconds",
			]:
				if mutation.has(key):
					actor[key] = mutation[key]
			actor_set[target_peer_id] = actor
		if target_peer_id != local_peer_id:
			continue
		if combat_type == "attack":
			feedback_message = (
				"你已倒地，等待队友靠近并按住 F 救援。"
				if bool(mutation.get("downed", false))
				else "你被怪物横扫命中，生命剩余 %d。"
				% int(mutation.get("hp", 0))
			)
			feedback_seconds = 3.0
			_play_combat_sound(HIT_SOUND, -5.0)
		elif combat_type == "revive":
			feedback_message = "队友完成救援，你恢复了 1 点生命。"
			feedback_seconds = 3.0
	queue_redraw()


func _play_combat_sound(stream: AudioStream, volume_db: float) -> void:
	if DisplayServer.get_name() == "headless" or not stream:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _apply_actor_hit_animations() -> void:
	var impact_time := GAME_STATE_BASE.HIT_WINDUP_TIME + GAME_STATE_BASE.HIT_LUNGE_TIME
	var total_time := impact_time + GAME_STATE_BASE.HIT_RECOVER_TIME
	for peer_id_variant in display_actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = display_actors[peer_id_variant]
		actor["impact_visual_offset"] = Vector2.ZERO
		if not actor_hit_animations.has(peer_id):
			display_actors[peer_id] = actor
			continue
		var animation: Dictionary = actor_hit_animations[peer_id]
		var action_time := maxf(
			match_elapsed - float(animation.get("started_at", match_elapsed)),
			0.0,
		)
		var facing: Vector2 = animation.get("facing", Vector2.DOWN)
		if action_time < GAME_STATE_BASE.HIT_WINDUP_TIME:
			var windup_t := smoothstep(
				0.0,
				1.0,
				action_time / GAME_STATE_BASE.HIT_WINDUP_TIME,
			)
			actor["impact_visual_offset"] = (
				-facing * GAME_STATE_BASE.HIT_WINDUP_DISTANCE * windup_t
			)
		elif action_time < impact_time:
			var lunge_t := smoothstep(
				0.0,
				1.0,
				(action_time - GAME_STATE_BASE.HIT_WINDUP_TIME)
				/ GAME_STATE_BASE.HIT_LUNGE_TIME,
			)
			actor["impact_visual_offset"] = facing * lerpf(
				-GAME_STATE_BASE.HIT_WINDUP_DISTANCE,
				GAME_STATE_BASE.HIT_LUNGE_DISTANCE,
				lunge_t,
			)
		elif action_time < total_time:
			var recover_t := clampf(
				(action_time - impact_time) / GAME_STATE_BASE.HIT_RECOVER_TIME,
				0.0,
				1.0,
			)
			actor["impact_visual_offset"] = (
				facing
				* GAME_STATE_BASE.HIT_LUNGE_DISTANCE
				* (1.0 - smoothstep(0.0, 1.0, recover_t))
			)
		else:
			actor_hit_animations.erase(peer_id)
		display_actors[peer_id] = actor


func _read_local_input() -> Vector2:
	if not active_storage_id.is_empty() or carrying_panel_open:
		return Vector2.ZERO
	var local_actor := _local_display_actor()
	if (
		bool(local_actor.get("downed", false))
		or bool(local_actor.get("trapped", false))
		or match_elapsed < float(local_actor.get("hit_stun_until", 0.0))
		or _read_local_rescue_input()
	):
		return Vector2.ZERO
	match debug_input:
		"left": return Vector2.LEFT
		"right": return Vector2.RIGHT
		"up": return Vector2.UP
		"down": return Vector2.DOWN
	var horizontal := (
		int(Input.is_physical_key_pressed(KEY_D))
		- int(Input.is_physical_key_pressed(KEY_A))
		+ int(Input.is_key_pressed(KEY_RIGHT))
		- int(Input.is_key_pressed(KEY_LEFT))
	)
	var vertical := (
		int(Input.is_physical_key_pressed(KEY_S))
		- int(Input.is_physical_key_pressed(KEY_W))
		+ int(Input.is_key_pressed(KEY_DOWN))
		- int(Input.is_key_pressed(KEY_UP))
	)
	return Vector2(horizontal, vertical).limit_length(1.0)


func _read_local_rescue_input() -> bool:
	return (
		match_live
		and active_storage_id.is_empty()
		and not carrying_panel_open
		and _local_role() == "thief"
		and not bool(_local_display_actor().get("trapped", false))
		and Input.is_physical_key_pressed(KEY_F)
	)


func _read_local_skill_input() -> bool:
	return (
		match_live
		and active_storage_id.is_empty()
		and not carrying_panel_open
		and str(_local_display_actor().get("profession_id", "")) == "support"
		and not bool(_local_display_actor().get("trapped", false))
		and Input.is_key_pressed(KEY_SHIFT)
	)


func _on_players_changed(players: Dictionary) -> void:
	if not active:
		return
	player_snapshot = players.duplicate(true)
	if mansion_state and session.is_server():
		mansion_state.sync_players(player_snapshot)
		for peer_id_variant in mansion_state.actors:
			var peer_id := int(peer_id_variant)
			if not server_inputs.has(peer_id):
				server_inputs[peer_id] = Vector2.ZERO
			if not server_rescue_inputs.has(peer_id):
				server_rescue_inputs[peer_id] = false
			if not server_skill_inputs.has(peer_id):
				server_skill_inputs[peer_id] = false
	for peer_id_variant in server_inputs.keys():
		if not player_snapshot.has(peer_id_variant):
			server_inputs.erase(peer_id_variant)
			server_rescue_inputs.erase(peer_id_variant)
			server_skill_inputs.erase(peer_id_variant)
			last_input_sequences.erase(peer_id_variant)
	for peer_id_variant in resource_ready_peers.keys():
		if not player_snapshot.has(peer_id_variant):
			resource_ready_peers.erase(peer_id_variant)
	if session.is_server() and world_initialized and not match_live:
		_broadcast_resource_ready_peers()
		_try_begin_live_match()
	_refresh_status()
	queue_redraw()


func _on_match_ended(reason: String) -> void:
	status_label.text = reason
	stop_match()
	leave_requested.emit()


func _build_ui() -> void:
	status_label = Label.new()
	status_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	status_label.offset_left = 430
	status_label.offset_top = 108
	status_label.offset_right = -430
	status_label.offset_bottom = 150
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 28)
	status_label.add_theme_color_override("font_color", MAIN_MENU_STYLE.TEXT)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_label)

	detail_label = Label.new()
	detail_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	detail_label.offset_left = 430
	detail_label.offset_top = 150
	detail_label.offset_right = -430
	detail_label.offset_bottom = 184
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.add_theme_color_override("font_color", MAIN_MENU_STYLE.MUTED)
	detail_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(detail_label)

	leave_button = Button.new()
	leave_button.text = "离开对局"
	leave_button.custom_minimum_size = Vector2(220, 48)
	leave_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	leave_button.position = Vector2(-286, -190)
	leave_button.z_index = 90
	leave_button.pressed.connect(func(): leave_requested.emit())
	MAIN_MENU_STYLE.apply_button(leave_button)
	add_child(leave_button)


func _refresh_status() -> void:
	if not status_label or not session:
		return
	if not match_live:
		status_label.text = "正在准备联机宅邸"
		if not world_initialized:
			detail_label.text = "正在生成地图与载入资源……"
		elif not local_resources_ready:
			detail_label.text = "正在预热本机渲染资源……"
		else:
			detail_label.text = "本机已就绪，等待其他玩家（%d / %d）" % [
				resource_ready_peers.size(),
				player_snapshot.size(),
			]
		return
	var local_entry: Dictionary = player_snapshot.get(session.local_peer_id(), {})
	var phase_text := _phase_label()
	status_label.text = "%s · %s · %s" % [
		_slot_label(str(local_entry.get("slot", "spectator"))),
		_profession_title(str(local_entry.get("profession_id", ""))),
		phase_text,
	]
	detail_label.text = ""
	if leave_button:
		leave_button.text = (
			"返回模式选择" if phase == "finished" else "离开对局"
		)


func _draw() -> void:
	if not active:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("#080b0a"))
	if not match_live:
		_draw_loading_screen()
		return
	var world_rect := Rect2(Vector2.ZERO, size)
	draw_rect(world_rect, Color("#141713"))
	if world_initialized and world_renderer:
		var texture := world_renderer.texture_for(_local_role())
		if texture:
			draw_texture_rect(texture, world_rect, false)
	_draw_noise_waves()
	draw_rect(
		Rect2(Vector2(size.x * 0.30, 98), Vector2(size.x * 0.40, 58)),
		Color(0.015, 0.018, 0.015, 0.76),
	)
	_draw_objective_status()
	_draw_player_roster()
	_draw_minimap()
	_draw_noise_alert()
	_draw_storage_panel()
	_draw_carry_status()
	_draw_network_toolbelt()
	_draw_carrying_panel()
	_draw_feedback()
	if phase == "finished":
		_draw_match_result()


func _draw_objective_status() -> void:
	var objective_rect := Rect2(
		Vector2(size.x * 0.30, 98),
		Vector2(size.x * 0.40, 58),
	)
	var text := "核心藏品 %d / %d" % [
		extracted_core_count,
		NETWORK_MANSION_STATE_SCRIPT.THIEF_CORE_TARGET,
	]
	var color := MAIN_MENU_STYLE.GOLD
	if phase == "hunt" and team_wipe_started_at >= 0.0:
		var wipe_left := maxf(
			NETWORK_MANSION_STATE_SCRIPT.TEAM_WIPE_SECONDS
			- (match_elapsed - team_wipe_started_at),
			0.0,
		)
		text = "全员倒地 · %.1f 秒后收藏家胜利" % wipe_left
		color = MONSTER_COLOR
	draw_string(
		UI_FONT,
		objective_rect.position + Vector2(12, 37),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		objective_rect.size.x - 24,
		22,
		color,
	)


func _draw_match_result() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.0, 0.0, 0.0, 0.78))
	var panel_size := Vector2(
		minf(760.0, size.x - 70.0),
		minf(390.0, size.y - 50.0),
	)
	var panel_rect := Rect2((size - panel_size) * 0.5, panel_size)
	draw_style_box(MAIN_MENU_STYLE.panel_style(), panel_rect)
	draw_rect(panel_rect.grow(-10.0), Color(MAIN_MENU_STYLE.GOLD, 0.42), false, 1.2)
	var title := (
		"盗贼阵营胜利" if winner == "thief" else "收藏家胜利"
	)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(36, 58),
		title,
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x - 72,
		34,
		THIEF_COLOR if winner == "thief" else MONSTER_COLOR,
	)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(36, 92),
		_result_reason_text(),
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x - 72,
		18,
		MAIN_MENU_STYLE.MUTED,
	)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(54, 132),
		"核心藏品 %d / %d　·　撤离总价值 %d　·　撤离人数 %d / 3"
		% [
			extracted_core_count,
			GAME_STATE_BASE.TREASURES.size(),
			total_extracted_value,
			escaped_thief_count,
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		panel_rect.size.x - 108,
		20,
		MAIN_MENU_STYLE.TEXT,
	)
	var row_y := panel_rect.position.y + 170.0
	for row_variant in result_player_rows:
		var row: Dictionary = row_variant
		var row_text := "%s　%s　带出价值 %d　核心藏品 %d" % [
			str(row.get("name", "盗贼")),
			"已撤离" if bool(row.get("escaped", false)) else "未撤离",
			int(row.get("extracted_value", 0)),
			int(row.get("core_count", 0)),
		]
		draw_string(
			UI_FONT,
			Vector2(panel_rect.position.x + 58, row_y),
			row_text,
			HORIZONTAL_ALIGNMENT_LEFT,
			minf(panel_rect.size.x - 360.0, 420.0),
			18,
			MAIN_MENU_STYLE.TEXT
			if bool(row.get("escaped", false))
			else MAIN_MENU_STYLE.MUTED,
		)
		row_y += 34.0


func _result_reason_text() -> String:
	match result_reason:
		"core_target":
			return "盗贼成功带出两件核心藏品。"
		"team_wipe":
			return "剩余盗贼全员倒地超过 8 秒。"
		"time":
			return "狩猎时间耗尽，核心藏品目标未完成。"
		"no_active_thieves":
			return "已无盗贼能够继续完成核心藏品目标。"
	return "本局已经结束。"


func _fallback_result_rows() -> Array:
	var rows: Array = []
	for peer_id_variant in target_actors:
		var peer_id := int(peer_id_variant)
		var actor: Dictionary = target_actors[peer_id_variant]
		if not str(actor.get("slot", "")).begins_with("thief"):
			continue
		rows.append({
			"peer_id": peer_id,
			"slot": str(actor.get("slot", "")),
			"name": str(actor.get("name", "盗贼")),
			"escaped": bool(actor.get("extracted", false)),
			"extracted_value": int(actor.get("extracted_value", 0)),
			"core_count": 0,
		})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return str(a.get("slot", "")) < str(b.get("slot", ""))
	)
	return rows


func _draw_loading_screen() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#11140f"))
	var panel_size := Vector2(minf(760.0, size.x - 100.0), minf(520.0, size.y - 100.0))
	var panel_rect := Rect2((size - panel_size) * 0.5, panel_size)
	draw_style_box(MAIN_MENU_STYLE.panel_style(), panel_rect)
	draw_rect(panel_rect.grow(-12.0), Color(MAIN_MENU_STYLE.GOLD, 0.45), false, 1.2)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(40, 74),
		"联机宅邸初始化",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x - 80,
		40,
		MAIN_MENU_STYLE.TEXT,
	)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(40, 116),
		"地图、材质与角色渲染全部完成后，服务器才会统一开场。",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x - 80,
		19,
		MAIN_MENU_STYLE.MUTED,
	)
	var y := panel_rect.position.y + 172.0
	var peer_ids := player_snapshot.keys()
	peer_ids.sort()
	for peer_id_variant in peer_ids:
		var peer_id := int(peer_id_variant)
		var player: Dictionary = player_snapshot[peer_id_variant]
		var ready := resource_ready_peers.has(peer_id)
		var row_rect := Rect2(
			Vector2(panel_rect.position.x + 74, y),
			Vector2(panel_rect.size.x - 148, 46),
		)
		draw_rect(row_rect, Color("#0b0d0b"))
		draw_rect(
			row_rect,
			Color("#587b68") if ready else Color("#5b5140"),
			false,
			1.0,
		)
		draw_string(
			UI_FONT,
			row_rect.position + Vector2(18, 30),
			"%s · %s　%s" % [
				_slot_label(str(player.get("slot", "spectator"))),
				_profession_title(str(player.get("profession_id", ""))),
				str(player.get("name", "玩家")),
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			row_rect.size.x - 150,
			19,
			MAIN_MENU_STYLE.TEXT,
		)
		draw_string(
			UI_FONT,
			Vector2(row_rect.end.x - 120, row_rect.position.y + 30),
			"资源已就绪" if ready else "载入中……",
			HORIZONTAL_ALIGNMENT_RIGHT,
			102,
			17,
			Color("#7bc39a") if ready else MAIN_MENU_STYLE.GOLD,
		)
		y += 54.0


func _draw_storage_panel() -> void:
	if active_storage_id.is_empty() or _local_role() != "monster" or phase != "hide":
		return
	var furniture := _local_active_storage_furniture()
	if furniture.is_empty():
		return
	var panel_width := minf(size.x - 220.0, 920.0)
	var panel_height := minf(280.0, size.y * 0.38)
	var panel_rect := Rect2(
		Vector2(110, size.y - panel_height - 220.0),
		Vector2(panel_width, panel_height),
	)
	draw_style_box(modal_panel_style, panel_rect)
	draw_rect(panel_rect.grow(-12.0), Color(MAIN_MENU_STYLE.GOLD, 0.62), false, 1.2)

	var title_rect := Rect2(
		panel_rect.position + Vector2(18, 12),
		Vector2(panel_rect.size.x - 36, 38),
	)
	draw_style_box(header_plaque_style, title_rect)
	draw_string(
		UI_FONT,
		title_rect.position + Vector2(14, 25),
		"家具已打开 · A / D 选择 · R 存取 · Esc 关闭",
		HORIZONTAL_ALIGNMENT_LEFT,
		title_rect.size.x - 28,
		18,
		MAIN_MENU_STYLE.GOLD,
	)

	var selected: Dictionary = GAME_STATE_BASE.TREASURES[selected_treasure]
	var info_rect := Rect2(
		panel_rect.position + Vector2(20, 56),
		Vector2(panel_rect.size.x - 40, 58),
	)
	draw_rect(info_rect, Color("#0b0d0b"))
	draw_rect(info_rect, Color(MAIN_MENU_STYLE.GOLD, 0.46), false, 1.0)
	draw_string(
		UI_FONT,
		info_rect.position + Vector2(14, 23),
		"%s · 价值 %d" % [selected["label"], int(selected["value"])],
		HORIZONTAL_ALIGNMENT_LEFT,
		info_rect.size.x - 28,
		18,
		MAIN_MENU_STYLE.GOLD,
	)
	draw_string(
		UI_FONT,
		info_rect.position + Vector2(14, 47),
		str(selected.get("description", "")),
		HORIZONTAL_ALIGNMENT_LEFT,
		info_rect.size.x - 28,
		15,
		MAIN_MENU_STYLE.TEXT,
	)

	var gap := 12.0
	var content_top := info_rect.end.y + 8.0
	var content_height := panel_rect.end.y - content_top - 16.0
	var left_width := (panel_rect.size.x - 52.0 - gap) * 0.64
	var left := Rect2(
		Vector2(panel_rect.position.x + 20.0, content_top),
		Vector2(left_width, content_height),
	)
	var right := Rect2(
		Vector2(left.end.x + gap, content_top),
		Vector2(panel_rect.end.x - 20.0 - left.end.x - gap, content_height),
	)
	draw_style_box(inventory_slot_style, left)
	draw_style_box(inventory_slot_style, right)
	draw_string(
		UI_FONT,
		left.position + Vector2(12, 24),
		"怪物藏品",
		HORIZONTAL_ALIGNMENT_LEFT,
		left.size.x - 24,
		17,
		MAIN_MENU_STYLE.TEXT,
	)
	draw_string(
		UI_FONT,
		right.position + Vector2(12, 24),
		"家具柜 · %s" % str(furniture.get("kind", "家具")),
		HORIZONTAL_ALIGNMENT_LEFT,
		right.size.x - 24,
		17,
		MAIN_MENU_STYLE.TEXT,
	)

	var slot_gap := 10.0
	var slot_size := minf(92.0, minf(
		(left.size.x - 24.0 - slot_gap * float(GAME_STATE_BASE.TREASURES.size() - 1))
		/ float(GAME_STATE_BASE.TREASURES.size()),
		content_height - 58.0,
	))
	var slots_width := (
		slot_size * float(GAME_STATE_BASE.TREASURES.size())
		+ slot_gap * float(GAME_STATE_BASE.TREASURES.size() - 1)
	)
	var slots_x := left.get_center().x - slots_width * 0.5
	var slot_y := left.position.y + 32.0
	for index in range(GAME_STATE_BASE.TREASURES.size()):
		var treasure: Dictionary = GAME_STATE_BASE.TREASURES[index]
		var status := _network_treasure_status(
			str(treasure["id"]),
			str(furniture["id"]),
		)
		var slot_rect := Rect2(
			Vector2(slots_x + float(index) * (slot_size + slot_gap), slot_y),
			Vector2(slot_size, slot_size),
		)
		_draw_network_treasure_slot(
			slot_rect,
			treasure,
			status == "随身",
			index == selected_treasure,
		)
		draw_string(
			UI_FONT,
			Vector2(slot_rect.position.x - 4, slot_rect.end.y + 19),
			status,
			HORIZONTAL_ALIGNMENT_CENTER,
			slot_rect.size.x + 8,
			14,
			MAIN_MENU_STYLE.GOLD if status == "随身" else MAIN_MENU_STYLE.MUTED,
		)

	var stored_primary: Dictionary = {}
	var other_names: Array[String] = []
	for content_variant in furniture.get("contents", []):
		var content: Dictionary = content_variant
		if str(content.get("kind", "")) in ["treasure", "alarm"]:
			stored_primary = content
		elif str(content.get("kind", "")) == "tool":
			other_names.append("道具：%s" % str(content.get("label", "未知")))
		elif str(content.get("kind", "")) == "trinket":
			other_names.append(
				"%s · %d" % [str(content.get("label", "小财物")), int(content.get("value", 0))]
			)
	var furniture_slot_size := minf(
		92.0,
		minf(right.size.x - 28.0, content_height - 58.0),
	)
	var furniture_slot := Rect2(
		Vector2(right.get_center().x - furniture_slot_size * 0.5, slot_y),
		Vector2(furniture_slot_size, furniture_slot_size),
	)
	_draw_network_furniture_slot(furniture_slot, stored_primary)
	draw_string(
		UI_FONT,
		Vector2(furniture_slot.position.x - 8, furniture_slot.end.y + 19),
		"空槽" if stored_primary.is_empty() else "已存放",
		HORIZONTAL_ALIGNMENT_CENTER,
		furniture_slot.size.x + 16,
		14,
		MAIN_MENU_STYLE.MUTED if stored_primary.is_empty() else MAIN_MENU_STYLE.GOLD,
	)
	var other_text := "无" if other_names.is_empty() else "、".join(other_names)
	draw_string(
		UI_FONT,
		right.position + Vector2(12, right.size.y - 10),
		"其他：%s" % other_text,
		HORIZONTAL_ALIGNMENT_LEFT,
		right.size.x - 24,
		13,
		MAIN_MENU_STYLE.MUTED,
	)


func _draw_network_treasure_slot(
	rect: Rect2,
	treasure: Dictionary,
	present: bool,
	is_selected: bool,
) -> void:
	draw_rect(rect, Color("#090b09"))
	draw_rect(rect, Color("#4d5048"), false, 1.0)
	if is_selected:
		draw_rect(rect.grow(3.0), Color(MAIN_MENU_STYLE.GOLD, 0.16))
		draw_rect(rect.grow(2.0), MAIN_MENU_STYLE.GOLD, false, 2.0)
	if present:
		_draw_network_treasure_icon(str(treasure["id"]), rect.grow(-9.0))
	else:
		var empty_rect := rect.grow(-13.0)
		draw_rect(empty_rect, Color("#20231f"), false, 1.0)
		draw_line(empty_rect.position, empty_rect.end, Color("#343831"), 1.0)
		draw_line(
			Vector2(empty_rect.end.x, empty_rect.position.y),
			Vector2(empty_rect.position.x, empty_rect.end.y),
			Color("#343831"),
			1.0,
		)


func _draw_network_furniture_slot(rect: Rect2, content: Dictionary) -> void:
	draw_rect(rect, Color("#090b09"))
	draw_rect(rect, Color("#4d5048"), false, 1.0)
	if content.is_empty():
		draw_rect(rect.grow(-13.0), Color("#20231f"), false, 1.0)
		return
	if str(content.get("kind", "")) == "treasure":
		_draw_network_treasure_icon(str(content["id"]), rect.grow(-9.0))
	elif str(content.get("kind", "")) == "alarm":
		draw_texture_rect(ALARM_ICON_TEXTURE, rect.grow(-8.0), false)


func _draw_network_treasure_icon(treasure_id: String, rect: Rect2) -> void:
	var icon_id := "treasure-1" if treasure_id.begins_with("wild-treasure-") else treasure_id
	var icon: Texture2D = TREASURE_ICON_TEXTURES.get(icon_id)
	if icon:
		draw_texture_rect(icon, rect, false)


func _network_treasure_status(treasure_id: String, current_furniture_id: String) -> String:
	if not mansion_state:
		return "随身"
	for room_variant in mansion_state.rooms:
		var room: Dictionary = room_variant
		for furniture_variant in room["furniture"]:
			var furniture: Dictionary = furniture_variant
			for content_variant in furniture.get("contents", []):
				var content: Dictionary = content_variant
				if str(content.get("id", "")) != treasure_id:
					continue
				return (
					"当前家具"
					if str(furniture.get("id", "")) == current_furniture_id
					else "其他家具"
				)
		for item_variant in room["items"]:
			var item: Dictionary = item_variant
			if (
				str(item.get("id", "")) == treasure_id
				and not bool(item.get("collected", false))
			):
				return "已掉落"
	return "随身"


func _draw_feedback() -> void:
	if feedback_seconds <= 0.0 or feedback_message.is_empty():
		return
	var feedback_rect := Rect2(
		Vector2(size.x * 0.5 - 230, 194),
		Vector2(460, 44),
	)
	draw_rect(feedback_rect, Color(0.02, 0.025, 0.02, 0.88))
	draw_rect(feedback_rect, _local_accent(), false, 1.5)
	draw_string(
		UI_FONT,
		feedback_rect.position + Vector2(14, 29),
		feedback_message,
		HORIZONTAL_ALIGNMENT_CENTER,
		feedback_rect.size.x - 28,
		18,
		MAIN_MENU_STYLE.TEXT,
	)


func _draw_carry_status() -> void:
	var actor := _local_display_actor()
	if actor.is_empty():
		return
	var status_height := 76.0 if _local_role() == "monster" else 102.0
	var status_rect := Rect2(
		Vector2(110, size.y - 288 - (status_height - 76.0)),
		Vector2(420, status_height),
	)
	draw_style_box(MAIN_MENU_STYLE.panel_style(), status_rect)
	if _local_role() == "monster":
		var cooldown := maxf(
			float(actor.get("attack_ready_at", 0.0)) - match_elapsed,
			0.0,
		)
		draw_string(
			UI_FONT,
			status_rect.position + Vector2(18, 34),
			"横扫 · %s" % (
				"冷却 %.1f 秒" % cooldown
				if cooldown > 0.0
				else "可以攻击"
			),
			HORIZONTAL_ALIGNMENT_LEFT,
			status_rect.size.x - 36,
			20,
			MAIN_MENU_STYLE.GOLD if cooldown <= 0.0 else MAIN_MENU_STYLE.MUTED,
		)
		var skill_cooldown := maxf(
			float(actor.get("active_skill_ready_at", 0.0)) - match_elapsed,
			0.0,
		)
		draw_string(
			UI_FONT,
			status_rect.position + Vector2(18, 61),
			"Shift 机关 · %d / 3 · %s" % [
				int(actor.get("active_skill_trap_count", 0)),
				"冷却 %.1f 秒" % skill_cooldown
				if skill_cooldown > 0.0
				else "可以布置",
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			status_rect.size.x - 36,
			17,
			MAIN_MENU_STYLE.GOLD
			if skill_cooldown <= 0.0
			else MAIN_MENU_STYLE.MUTED,
		)
		return
	var extracted := bool(actor.get("extracted", false))
	var hidden := bool(actor.get("hidden_from_monster", false))
	var downed := bool(actor.get("downed", false))
	var hp := int(actor.get("hp", NETWORK_MANSION_STATE_SCRIPT.MAX_HP))
	var title := (
		"已撤离 · 带出价值 %d" % int(actor.get("extracted_value", 0))
		if extracted
		else "已倒地 · 生命 0 / %d" % NETWORK_MANSION_STATE_SCRIPT.MAX_HP
		if downed
		else "生命 %d / %d · %s · 价值 %d · 财物 %d 件"
		% [
			hp,
			NETWORK_MANSION_STATE_SCRIPT.MAX_HP,
			"潜行中" if hidden else "暴露中",
			int(actor.get("carried_value", 0)),
			int(actor.get("carried_count", 0)),
		]
	)
	draw_string(
		UI_FONT,
		status_rect.position + Vector2(18, 34),
		title,
		HORIZONTAL_ALIGNMENT_LEFT,
		status_rect.size.x - 36,
		20,
		Color("#e56a5c")
		if downed
		else MAIN_MENU_STYLE.GOLD if extracted
		else _local_accent() if hidden
		else MAIN_MENU_STYLE.TEXT,
	)
	if not extracted and not downed:
		draw_string(
			UI_FONT,
			status_rect.position + Vector2(18, 61),
			"负重 %d · 当前速度 %.0f%%" % [
				int(actor.get("carried_weight", 0)),
				float(actor.get("speed_multiplier", 1.0)) * 100.0,
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			status_rect.size.x - 36,
			17,
			MAIN_MENU_STYLE.MUTED,
		)
		var skill_status := _thief_skill_status(actor)
		draw_string(
			UI_FONT,
			status_rect.position + Vector2(18, 87),
			skill_status,
			HORIZONTAL_ALIGNMENT_LEFT,
			status_rect.size.x - 36,
			17,
			MAIN_MENU_STYLE.GOLD
			if float(actor.get("active_skill_ready_at", 0.0)) <= match_elapsed
			else MAIN_MENU_STYLE.MUTED,
		)


func _thief_skill_status(actor: Dictionary) -> String:
	var profession_id := str(actor.get("profession_id", ""))
	var cooldown := maxf(
		float(actor.get("active_skill_ready_at", 0.0)) - match_elapsed,
		0.0,
	)
	match profession_id:
		"scout":
			var active_seconds := maxf(
				float(actor.get("scout_scan_until", 0.0)) - match_elapsed,
				0.0,
			)
			if active_seconds > 0.0:
				return "Shift 回声勘察 · 扫描 %.1f 秒" % active_seconds
			return (
				"Shift 回声勘察 · 冷却 %.1f 秒" % cooldown
				if cooldown > 0.0
				else "Shift 回声勘察 · 可以使用"
			)
		"support":
			var progress := float(actor.get("support_heal_progress", 0.0))
			if progress > 0.0:
				return "按住 Shift 包扎 · %.1f / 1.2 秒" % progress
			return (
				"按住 Shift 包扎 · 冷却 %.1f 秒" % cooldown
				if cooldown > 0.0
				else "按住 Shift 为附近受伤队友包扎"
			)
		"hauler":
			var sprint_seconds := maxf(
				float(actor.get("hauler_sprint_until", 0.0)) - match_elapsed,
				0.0,
			)
			if sprint_seconds > 0.0:
				return "Shift 卸重疾行 · 剩余 %.1f 秒" % sprint_seconds
			return (
				"Shift 卸重疾行 · 冷却 %.1f 秒" % cooldown
				if cooldown > 0.0
				else "Shift 卸重疾行 · 可以使用"
			)
	return "当前职业尚无主动技能"


func _draw_carrying_panel() -> void:
	if not carrying_panel_open or _local_role() != "thief":
		return
	var actor := _local_display_actor()
	var carried_loot: Array = actor.get("carried_loot", [])
	if carried_loot.is_empty():
		return
	var visible_rows := mini(carried_loot.size(), 6)
	var panel_size := Vector2(560, 126 + visible_rows * 52)
	var panel_rect := Rect2((size - panel_size) * 0.5, panel_size)
	draw_style_box(modal_panel_style, panel_rect)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(34, 46),
		"携带藏品",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x - 68,
		30,
		MAIN_MENU_STYLE.TEXT,
	)
	var first_index := clampi(
		selected_carried_loot - visible_rows + 1,
		0,
		maxi(carried_loot.size() - visible_rows, 0),
	)
	for row_index in range(visible_rows):
		var loot_index := first_index + row_index
		var loot: Dictionary = carried_loot[loot_index]
		var row_rect := Rect2(
			panel_rect.position + Vector2(38, 68 + row_index * 52),
			Vector2(panel_rect.size.x - 76, 46),
		)
		draw_style_box(inventory_slot_style, row_rect)
		if loot_index == selected_carried_loot:
			draw_rect(row_rect.grow(-5.0), _local_accent(), false, 1.8)
		draw_string(
			UI_FONT,
			row_rect.position + Vector2(18, 30),
			"%s　价值 %d　重量 %d" % [
				str(loot.get("label", "藏品")),
				int(loot.get("value", 0)),
				NETWORK_MANSION_STATE_SCRIPT.loot_weight(loot),
			],
			HORIZONTAL_ALIGNMENT_LEFT,
			row_rect.size.x - 36,
			19,
			MAIN_MENU_STYLE.TEXT,
		)
	draw_string(
		UI_FONT,
		panel_rect.position + Vector2(28, panel_rect.size.y - 24),
		"W / S 选择 · R 丢弃 · T 快速丢弃最低价值 · B / Esc 关闭",
		HORIZONTAL_ALIGNMENT_CENTER,
		panel_rect.size.x - 56,
		16,
		MAIN_MENU_STYLE.MUTED,
	)


func _draw_network_toolbelt() -> void:
	var actor := _local_display_actor()
	if actor.is_empty():
		return
	var tools: Array = actor.get("tools", [])
	var slot_count := NETWORK_MANSION_STATE_SCRIPT.TOOL_INVENTORY_CAPACITY
	var tray_size := Vector2(600, 126)
	var tray := Rect2(
		Vector2((size.x - tray_size.x) * 0.5, size.y - tray_size.y - 130),
		tray_size,
	)
	draw_style_box(toolbelt_tray_style, tray)
	draw_string(
		UI_FONT,
		tray.position + Vector2(22, 20),
		"背包",
		HORIZONTAL_ALIGNMENT_LEFT,
		tray.size.x - 44,
		15,
		Color("#c5b79e"),
	)
	var gap := 6.0
	var slot_start := tray.position + Vector2(18, 27)
	var slot_size := Vector2(
		(tray.size.x - 36.0 - gap * 2.0) / 3.0,
		68,
	)
	var selected := int(actor.get("tool_selected", 0))
	for index in range(slot_count):
		var slot := Rect2(
			slot_start + Vector2(index * (slot_size.x + gap), 0),
			slot_size,
		)
		draw_style_box(toolbelt_slot_style, slot)
		if index == selected and index < tools.size():
			draw_rect(slot.grow(-5.0), _local_accent(), false, 1.8)
		if index >= tools.size():
			draw_string(
				UI_FONT,
				slot.position + Vector2(8, 38),
				"%d · 空" % (index + 1),
				HORIZONTAL_ALIGNMENT_CENTER,
				slot.size.x - 16,
				15,
				MAIN_MENU_STYLE.MUTED,
			)
			continue
		var tool: Dictionary = tools[index]
		var tool_type := str(tool.get("tool_type", ""))
		var icon: Texture2D = TOOL_ICON_TEXTURES.get(tool_type)
		var icon_size := minf(slot.size.y - 14.0, 46.0)
		var icon_rect := Rect2(
			slot.position + Vector2(10, (slot.size.y - icon_size) * 0.5),
			Vector2.ONE * icon_size,
		)
		if icon:
			draw_texture_rect(icon, icon_rect, false)
		draw_string(
			UI_FONT,
			Vector2(icon_rect.end.x + 4, slot.position.y + 39),
			"%d · %s" % [
				index + 1,
				str(GAME_STATE_BASE.TOOL_DEFS.get(tool_type, {}).get(
					"short",
					"",
				)),
			],
			HORIZONTAL_ALIGNMENT_CENTER,
			slot.end.x - icon_rect.end.x - 12,
			15,
			MAIN_MENU_STYLE.TEXT,
		)
	var selected_tool: Dictionary = {}
	if not tools.is_empty() and selected < tools.size():
		selected_tool = tools[selected]
	var hint := ""
	if bool(actor.get("trapped", false)):
		hint = "捕兽夹 %d / %d · 下一键 %s" % [
			int(actor.get("trap_escape_progress", 0)),
			NETWORK_MANSION_STATE_SCRIPT.TRAP_ESCAPE_PRESSES,
			str(actor.get("trap_prompt", "A")),
		]
	elif float(actor.get("teleport_ends", -1.0)) > match_elapsed:
		hint = "传送器轰鸣充能 %.1f 秒" % (
			float(actor["teleport_ends"]) - match_elapsed
		)
	elif match_elapsed < float(actor.get("adrenaline_until", 0.0)):
		hint = "肾上腺素双速 %.1f 秒" % (
			float(actor["adrenaline_until"]) - match_elapsed
		)
	elif match_elapsed < float(actor.get("fatigue_until", 0.0)):
		hint = "肾上腺素疲劳 %.1f 秒" % (
			float(actor["fatigue_until"]) - match_elapsed
		)
	elif str(selected_tool.get("tool_type", "")) == "detector":
		hint = "探测器%s · 电量 %.1f 秒" % [
			"开启" if bool(selected_tool.get("active", false)) else "关闭",
			float(selected_tool.get("charge", 0.0)),
		]
	elif (
		str(selected_tool.get("tool_type", "")) == "robot"
		and bool(selected_tool.get("deployed", false))
	):
		var robot_stun := maxf(
			float(selected_tool.get("stunned_until", 0.0)) - match_elapsed,
			0.0,
		)
		hint = (
			"巡夜偶停机 %.1f 秒" % robot_stun
			if robot_stun > 0.0
			else "巡夜偶工作中 · C 换位"
		)
	if not hint.is_empty():
		draw_string(
			UI_FONT,
			tray.position + Vector2(10, tray.size.y - 8),
			hint,
			HORIZONTAL_ALIGNMENT_CENTER,
			tray.size.x - 20,
			14,
			MAIN_MENU_STYLE.GOLD
			if bool(actor.get("trapped", false))
			else MAIN_MENU_STYLE.MUTED,
		)


func _local_display_actor() -> Dictionary:
	if not session:
		return {}
	var peer_id := session.local_peer_id()
	if target_actors.has(peer_id):
		return target_actors[peer_id]
	if display_actors.has(peer_id):
		return display_actors[peer_id]
	return {}


func _sync_carrying_panel_state() -> void:
	if not carrying_panel_open:
		return
	var carried_loot: Array = _local_display_actor().get("carried_loot", [])
	if carried_loot.is_empty():
		carrying_panel_open = false
		selected_carried_loot = 0
		return
	selected_carried_loot = clampi(
		selected_carried_loot,
		0,
		carried_loot.size() - 1,
	)


func _local_active_storage_furniture() -> Dictionary:
	if not mansion_state:
		return {}
	for room_variant in mansion_state.rooms:
		var room: Dictionary = room_variant
		for furniture_variant in room["furniture"]:
			var furniture: Dictionary = furniture_variant
			if str(furniture.get("id", "")) == active_storage_id:
				return furniture
	return {}


func _furniture_contains(furniture: Dictionary, content_id: String) -> bool:
	for content_variant in furniture.get("contents", []):
		var content: Dictionary = content_variant
		if str(content.get("id", "")) == content_id:
			return true
	return false


func _draw_player_roster() -> void:
	var ids := player_snapshot.keys()
	ids.sort()
	var roster_rect := Rect2(Vector2(size.x - 415, 100), Vector2(340, 174))
	draw_style_box(MAIN_MENU_STYLE.panel_style(), roster_rect)
	var y := roster_rect.position.y + 35
	for peer_id_variant in ids:
		var peer_id := int(peer_id_variant)
		var player: Dictionary = player_snapshot[peer_id_variant]
		var slot := str(player.get("slot", "spectator"))
		var local_marker := "▶ " if session and peer_id == session.local_peer_id() else "　"
		var text := "%s%s·%s　%s" % [
			local_marker,
			_slot_label(slot),
			_profession_title(str(player.get("profession_id", ""))),
			str(player.get("name", "玩家")),
		]
		var actor: Dictionary = target_actors.get(peer_id, {})
		if bool(actor.get("extracted", false)):
			text += "　已撤离 %d" % int(actor.get("extracted_value", 0))
		elif slot.begins_with("thief"):
			text += (
				"　倒地 %.0f%%"
				% (
					float(actor.get("rescue_progress", 0.0))
					/ maxf(
						float(actor.get(
							"rescue_required_seconds",
							NETWORK_MANSION_STATE_SCRIPT.REVIVE_SECONDS,
						)),
						0.01,
					)
					* 100.0
				)
				if bool(actor.get("downed", false))
				else "　HP %d/%d"
				% [
					int(actor.get("hp", NETWORK_MANSION_STATE_SCRIPT.MAX_HP)),
					NETWORK_MANSION_STATE_SCRIPT.MAX_HP,
				]
			)
		if bool(actor.get("trapped", false)):
			text += "　被捕"
		draw_string(
			UI_FONT,
			Vector2(roster_rect.position.x + 24, y),
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			roster_rect.size.x - 48,
			21,
			_slot_color(slot) if local_marker != "　" else MAIN_MENU_STYLE.TEXT,
		)
		y += 32


func _draw_minimap() -> void:
	if not mansion_state or mansion_state.rooms.is_empty():
		return
	var map_size := clampf(size.y * 0.285, 185.0, 245.0)
	var map_rect := Rect2(
		Vector2(76, 96),
		Vector2(map_size, map_size),
	)
	var cell_size := map_size / float(NETWORK_MANSION_STATE_SCRIPT.MAP_SIZE)
	draw_rect(map_rect.grow(12), Color(0.025, 0.03, 0.025, 0.86))
	draw_rect(map_rect.grow(12), _local_accent(), false, 2.0)
	for room_variant in mansion_state.rooms:
		var room: Dictionary = room_variant
		var coord: Vector2i = room["coord"]
		var cell := Rect2(
			map_rect.position + Vector2(coord) * cell_size + Vector2(3, 3),
			Vector2(cell_size - 6, cell_size - 6),
		)
		draw_rect(cell, Color("#242820"))
		draw_rect(cell, Color("#5a594b"), false, 1.5)
	_draw_scout_scan_markers(map_rect, cell_size)
	for peer_id_variant in display_actors:
		var actor: Dictionary = display_actors[peer_id_variant]
		if bool(actor.get("extracted", false)):
			continue
		if not _actor_visible_on_local_minimap(int(peer_id_variant), actor):
			continue
		var coord: Vector2i = actor["room"]
		var center := (
			map_rect.position
			+ (Vector2(coord) + Vector2(0.5, 0.5)) * cell_size
		)
		var slot := str(actor.get("slot", "spectator"))
		var radius := 8.0 if slot == "monster" else 5.5
		draw_circle(center, radius, _slot_color(slot))
		if session and int(peer_id_variant) == session.local_peer_id():
			draw_arc(center, radius + 4.0, 0, TAU, 24, MAIN_MENU_STYLE.GOLD, 2.0)
	for noise_variant in _visible_noises():
		var noise: Dictionary = noise_variant
		var coord: Vector2i = noise["room"]
		var center := (
			map_rect.position
			+ (Vector2(coord) + Vector2(0.5, 0.5)) * cell_size
		)
		var duration := _noise_visual_duration(noise)
		var age := maxf(match_elapsed - float(noise.get("created", match_elapsed)), 0.0)
		var progress := clampf(age / duration, 0.0, 1.0)
		var fade := 1.0 - progress
		var color := (
			Color("#d7624f")
			if str(noise.get("source_role", "")) == "monster"
			else Color("#e0ba63")
		)
		draw_circle(center, 5.0 + progress * 12.0, Color(color, 0.10 * fade))
		draw_arc(
			center,
			7.0 + progress * 13.0,
			0,
			TAU,
			24,
			Color(color, 0.92 * fade),
			2.0,
		)


func _draw_scout_scan_markers(map_rect: Rect2, cell_size: float) -> void:
	var local_actor := _local_display_actor()
	if (
		str(local_actor.get("profession_id", "")) != "scout"
		or match_elapsed >= float(local_actor.get("scout_scan_until", 0.0))
	):
		return
	var local_room: Vector2i = local_actor.get("room", Vector2i(-10, -10))
	for room_variant in mansion_state.rooms:
		var room: Dictionary = room_variant
		var coord: Vector2i = room["coord"]
		var distance := (
			absi(coord.x - local_room.x)
			+ absi(coord.y - local_room.y)
		)
		if distance > 1:
			continue
		var center := (
			map_rect.position
			+ (Vector2(coord) + Vector2(0.5, 0.5)) * cell_size
		)
		var has_unopened := false
		var has_damaged := false
		for furniture_variant in room.get("furniture", []):
			var furniture: Dictionary = furniture_variant
			has_unopened = (
				has_unopened
				or not bool(furniture.get("opened", false))
			)
			has_damaged = (
				has_damaged
				or int(furniture.get("damage", 0)) > 0
			)
		if has_unopened:
			draw_circle(center + Vector2(-7, 7), 3.5, Color("#d7b264"))
		if has_damaged:
			draw_rect(
				Rect2(center + Vector2(3, 3), Vector2(7, 7)),
				Color("#e68a55"),
				false,
				2.0,
			)
		var has_hostile_device := false
		for item_variant in room.get("items", []):
			var item: Dictionary = item_variant
			if (
				not bool(item.get("collected", false))
				and str(item.get("kind", "")) == "device"
				and str(item.get("owner", "")) == "monster"
			):
				has_hostile_device = true
				break
		if has_hostile_device:
			draw_line(
				center + Vector2(-5, -5),
				center + Vector2(5, 5),
				Color("#e85f52"),
				2.5,
			)
			draw_line(
				center + Vector2(5, -5),
				center + Vector2(-5, 5),
				Color("#e85f52"),
				2.5,
			)
	var last_known_room: Vector2i = local_actor.get(
		"scout_last_known_room",
		Vector2i(-1, -1),
	)
	if (
		match_elapsed < float(local_actor.get("scout_last_known_until", 0.0))
		and last_known_room.x >= 0
		and last_known_room.y >= 0
	):
		var last_known_center := (
			map_rect.position
			+ (Vector2(last_known_room) + Vector2(0.5, 0.5)) * cell_size
		)
		draw_arc(
			last_known_center,
			10.0,
			0.0,
			TAU,
			24,
			Color("#e85f52"),
			2.5,
		)


func _draw_noise_waves() -> void:
	var visible_noises := _visible_noises()
	if visible_noises.is_empty() or not world_renderer:
		return
	var local_actor := _local_display_actor()
	if local_actor.is_empty():
		return
	var normalized := world_renderer.project_normalized(
		_local_role(),
		local_actor["room"],
		local_actor["pos"],
		0.55,
	)
	var origin := normalized * size
	for noise_variant in visible_noises:
		var noise: Dictionary = noise_variant
		var direction := _noise_screen_direction(noise, local_actor)
		if direction.is_zero_approx():
			continue
		var right_side := direction.x >= 0.0
		var center_angle := 0.0 if right_side else PI
		var color := (
			Color("#d7624f")
			if str(noise.get("source_role", "")) == "monster"
			else Color("#e0ba63")
		)
		var duration := _noise_visual_duration(noise)
		var age := maxf(match_elapsed - float(noise.get("created", match_elapsed)), 0.0)
		var life_fade := clampf(
			(_noise_visual_expires(noise) - match_elapsed) / duration,
			0.0,
			1.0,
		)
		for wave_index in range(3):
			var wave_progress := fmod(
				age * 1.85 + float(wave_index) / 3.0,
				1.0,
			)
			var radius := lerpf(34.0, 112.0, wave_progress)
			var alpha := life_fade * (1.0 - wave_progress) * 0.92
			draw_arc(
				origin,
				radius,
				center_angle - 0.72,
				center_angle + 0.72,
				18,
				Color(color, alpha),
				3.0,
			)


func _noise_screen_direction(noise: Dictionary, local_actor: Dictionary) -> Vector2:
	var listener_global := _logical_global_position(
		local_actor.get("room", Vector2i.ZERO),
		local_actor.get("pos", Vector2.ZERO),
	)
	var source_global := _logical_global_position(
		noise.get("room", Vector2i.ZERO),
		noise.get("pos", Vector2.ZERO),
	)
	if source_global.is_equal_approx(listener_global):
		return Vector2.ZERO
	if world_renderer:
		return world_renderer.project_logical_direction(
			_local_role(),
			listener_global,
			source_global,
		)
	return (source_global - listener_global).normalized()


func _draw_noise_alert() -> void:
	var visible_noises := _visible_noises()
	if visible_noises.is_empty():
		return
	var latest: Dictionary = visible_noises[0]
	for noise_variant in visible_noises:
		var noise: Dictionary = noise_variant
		if float(noise.get("created", 0.0)) > float(latest.get("created", 0.0)):
			latest = noise
	var local_actor := _local_display_actor()
	if local_actor.is_empty():
		return
	var local_room: Vector2i = local_actor["room"]
	var noise_room: Vector2i = latest["room"]
	var room_delta := noise_room - local_room
	var distance: int = absi(room_delta.x) + absi(room_delta.y)
	var direction := _noise_direction_label(room_delta)
	var distance_label := "距离 %d 个房间" % distance
	if str(local_actor.get("profession_id", "")) == "scout":
		distance_label = "敏锐听觉：%s（%d 个房间）" % [
			"同房" if distance == 0 else "邻近" if distance == 1 else "较远",
			distance,
		]
	var alert_rect := Rect2(Vector2(110, 365), Vector2(430, 68))
	draw_style_box(MAIN_MENU_STYLE.panel_style(), alert_rect)
	draw_string(
		UI_FONT,
		alert_rect.position + Vector2(18, 28),
		"声响：%s" % str(latest.get("label", "未知动静")),
		HORIZONTAL_ALIGNMENT_LEFT,
		alert_rect.size.x - 36,
		19,
		MAIN_MENU_STYLE.GOLD,
	)
	draw_string(
		UI_FONT,
		alert_rect.position + Vector2(18, 53),
		"%s · %s · %s" % [
			direction,
			distance_label,
			"制造者未知" if _local_role() == "monster" else "怪物动静",
		],
		HORIZONTAL_ALIGNMENT_LEFT,
		alert_rect.size.x - 36,
		15,
		MAIN_MENU_STYLE.MUTED,
	)


func _visible_noises() -> Array:
	var result: Array = []
	if not mansion_state:
		return result
	var local_actor := _local_display_actor()
	if local_actor.is_empty():
		return result
	var local_role := _local_role()
	var local_room: Vector2i = local_actor["room"]
	var scout_listener := str(local_actor.get("profession_id", "")) == "scout"
	for noise_variant in mansion_state.noises:
		var noise: Dictionary = noise_variant
		var expires := float(noise.get(
			"scout_expires" if scout_listener else "expires",
			noise.get("expires", 0.0),
		))
		if match_elapsed >= expires:
			continue
		if str(noise.get("source_role", "")) == local_role:
			continue
		var noise_room: Vector2i = noise.get("room", Vector2i.ZERO)
		var distance: int = (
			absi(noise_room.x - local_room.x)
			+ absi(noise_room.y - local_room.y)
		)
		if distance >= 3:
			continue
		result.append(noise)
	return result


func _noise_visual_expires(noise: Dictionary) -> float:
	var local_actor := _local_display_actor()
	var scout_listener := str(local_actor.get("profession_id", "")) == "scout"
	return float(noise.get(
		"scout_expires" if scout_listener else "expires",
		noise.get("expires", match_elapsed),
	))


func _noise_visual_duration(noise: Dictionary) -> float:
	return maxf(
		_noise_visual_expires(noise)
		- float(noise.get("created", match_elapsed)),
		0.01,
	)


func _actor_visible_on_local_minimap(peer_id: int, actor: Dictionary) -> bool:
	if not session:
		return false
	if peer_id == session.local_peer_id():
		return true
	var local_actor := _local_display_actor()
	if local_actor.is_empty():
		return false
	var local_role := _local_role()
	var actor_role := (
		"monster"
		if str(actor.get("slot", "")) == "monster"
		else "thief"
	)
	if local_role == "thief" and actor_role == "thief":
		return true
	if actor.get("room", Vector2i(-1, -1)) != local_actor.get("room", Vector2i(-2, -2)):
		return false
	return not (
		local_role == "monster"
		and actor_role == "thief"
		and bool(actor.get("hidden_from_monster", false))
	)


func _noise_direction_label(delta: Vector2i) -> String:
	if delta == Vector2i.ZERO:
		return "同一房间"
	var vertical := "北" if delta.y < 0 else "南" if delta.y > 0 else ""
	var horizontal := "西" if delta.x < 0 else "东" if delta.x > 0 else ""
	return "%s%s方向" % [vertical, horizontal]


func _phase_label() -> String:
	if phase == "loading":
		return "载入中"
	var minutes := seconds_left / 60
	var remainder := seconds_left % 60
	match phase:
		"hide": return "藏宝 %d:%02d" % [minutes, remainder]
		"ready": return "狩猎倒计时 %d" % seconds_left
		"hunt": return "狩猎 %d:%02d" % [minutes, remainder]
		"finished": return "比赛结束"
	return phase


func _phase_from_index(index: int) -> String:
	match index:
		0: return "hide"
		1: return "ready"
		2: return "hunt"
		3: return "finished"
	return phase


func _direction_from_index(index: int) -> String:
	match index:
		0: return "up"
		1: return "right"
		2: return "down"
	return "left"


func _direction_vector(direction: String) -> Vector2:
	match direction:
		"up": return Vector2.UP
		"right": return Vector2.RIGHT
		"down": return Vector2.DOWN
	return Vector2.LEFT


func _local_role() -> String:
	if not session:
		return "thief"
	var entry: Dictionary = player_snapshot.get(session.local_peer_id(), {})
	return "monster" if str(entry.get("slot", "")) == "monster" else "thief"


func _local_accent() -> Color:
	return MONSTER_COLOR if _local_role() == "monster" else THIEF_COLOR


func _logical_global_position(room: Vector2i, position: Vector2) -> Vector2:
	return Vector2(room) * NETWORK_MANSION_STATE_SCRIPT.ROOM_SIZE + position


func _slot_color(slot: String) -> Color:
	match slot:
		"monster": return Color("#d7624f")
		"thief-1": return Color("#59bdab")
		"thief-2": return Color("#6d9dd5")
		"thief-3": return Color("#b38bcf")
	return Color("#777777")


func _slot_label(slot: String) -> String:
	match slot:
		"monster": return "怪物"
		"thief-1": return "盗贼 1"
		"thief-2": return "盗贼 2"
		"thief-3": return "盗贼 3"
	return "观战"


func _profession_title(profession_id: String) -> String:
	return PROFESSION_CATALOG.title_for(profession_id)
