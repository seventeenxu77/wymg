@tool
class_name World25D
extends Node

const CELL_SIZE := 2.10
const ROOM_EXTENT := 5.25
const ROOM_SPACING := ROOM_EXTENT * 2.0
const VIEWPORT_SIZE := Vector2i(768, 768)
const CAMERA_HEIGHT := 10.0
const CAMERA_DISTANCE := 15.0
const CAMERA_FOV := 50.0
const INVALID_ROOM := Vector2i(-999, -999)

const LAYER_MONSTER_WORLD := 1
const LAYER_MONSTER := 2
const LAYER_THIEF := 4
const LAYER_AFTERIMAGE := 8
const LAYER_MONSTER_EFFECT := 16
const LAYER_THIEF_WORLD := 32

var initialized := false
var world_root: Node3D
var level_root: Node3D
var monster_viewport: SubViewport
var thief_viewport: SubViewport
var monster_camera: Camera3D
var thief_camera: Camera3D
var monster_node: Node3D
var thief_node: Node3D
var attack_cone: MeshInstance3D

var furniture_nodes: Dictionary = {}
var item_nodes: Dictionary = {}
var trace_nodes: Dictionary = {}
var stroke_nodes: Dictionary = {}
var afterimage_nodes: Dictionary = {}
var room_visuals: Dictionary = {}
var active_monster_room := INVALID_ROOM
var active_thief_room := INVALID_ROOM
var camera_yaw_degrees := {
	"monster": 0.0,
	"thief": 0.0,
}

var floor_material: StandardMaterial3D
var floor_alt_material: StandardMaterial3D
var wall_material: StandardMaterial3D
var wall_front_material: StandardMaterial3D
var dark_material: StandardMaterial3D
var trace_monster_material: StandardMaterial3D
var trace_thief_material: StandardMaterial3D


func setup(shared_world: World3D) -> void:
	if initialized:
		return
	initialized = true
	world_root = Node3D.new()
	world_root.name = "World25D"
	add_child(world_root)
	level_root = Node3D.new()
	level_root.name = "GeneratedMansion"
	world_root.add_child(level_root)
	_create_materials()
	_create_environment()
	monster_viewport = _create_viewport("MonsterViewport", shared_world)
	thief_viewport = _create_viewport("ThiefViewport", shared_world)
	monster_camera = _create_camera(monster_viewport, "MonsterCamera", LAYER_MONSTER_WORLD | LAYER_MONSTER | LAYER_AFTERIMAGE | LAYER_MONSTER_EFFECT)
	thief_camera = _create_camera(thief_viewport, "ThiefCamera", LAYER_THIEF_WORLD | LAYER_MONSTER | LAYER_THIEF)
	monster_node = _create_actor("monster", LAYER_MONSTER)
	thief_node = _create_actor("thief", LAYER_THIEF)
	attack_cone = _create_attack_cone()


func _create_materials() -> void:
	floor_material = _material(Color("#514f45"), 0.96)
	floor_alt_material = _material(Color("#5a584b"), 0.96)
	wall_material = _material(Color("#34342f"), 0.92)
	wall_front_material = _material(Color("#292a27"), 0.95)
	dark_material = _material(Color(0.035, 0.035, 0.03, 0.62), 1.0, true)
	trace_monster_material = _material(Color("#5e2922"), 1.0)
	trace_thief_material = _material(Color("#245a50"), 1.0)


func _material(color: Color, roughness: float, transparent := false, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _create_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "GothicEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#171814")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9f9a84")
	environment.ambient_light_energy = 0.88
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	world_root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"
	sun.rotation_degrees = Vector3(-58, -38, 0)
	sun.light_color = Color("#d8d3ba")
	sun.light_energy = 1.28
	sun.shadow_enabled = false
	world_root.add_child(sun)


func _create_viewport(viewport_name: String, shared_world: World3D) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.name = viewport_name
	viewport.size = VIEWPORT_SIZE
	viewport.world_3d = shared_world
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.use_taa = true
	viewport.positional_shadow_atlas_size = 2048
	add_child(viewport)
	return viewport


func _create_camera(viewport: SubViewport, camera_name: String, mask: int) -> Camera3D:
	var camera := Camera3D.new()
	camera.name = camera_name
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = CAMERA_FOV
	camera.near = 0.1
	camera.far = 100.0
	camera.cull_mask = mask
	viewport.add_child(camera)
	camera.current = true
	return camera


func rebuild(rooms: Array) -> void:
	if not initialized:
		return
	for child in level_root.get_children():
		child.queue_free()
	furniture_nodes.clear()
	item_nodes.clear()
	trace_nodes.clear()
	stroke_nodes.clear()
	room_visuals.clear()
	active_monster_room = INVALID_ROOM
	active_thief_room = INVALID_ROOM
	for room in rooms:
		_create_room(room)
		for furniture in room["furniture"]:
			_create_furniture_node(room["coord"], furniture)
		for item in room["items"]:
			_create_item_node(room["coord"], item)


func _create_room(room: Dictionary) -> void:
	var coord: Vector2i = room["coord"]
	var origin := room_origin(coord)
	var floor := MeshInstance3D.new()
	floor.name = "Floor_%d_%d" % [coord.x, coord.y]
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(ROOM_EXTENT * 2.0, 0.12, ROOM_EXTENT * 2.0)
	floor.mesh = floor_mesh
	floor.material_override = floor_material if (coord.x + coord.y) % 2 == 0 else floor_alt_material
	floor.position = origin + Vector3(0, -0.08, 0)
	_register_room_visual(coord, floor)
	level_root.add_child(floor)

	var inset := MeshInstance3D.new()
	var inset_mesh := BoxMesh.new()
	inset_mesh.size = Vector3(ROOM_EXTENT * 2.0 - 0.7, 0.025, ROOM_EXTENT * 2.0 - 0.7)
	inset.mesh = inset_mesh
	inset.material_override = _material(Color(0.12, 0.115, 0.1, 0.13), 1.0, true)
	inset.position = origin + Vector3(0, 0.002, 0)
	_register_room_visual(coord, inset)
	level_root.add_child(inset)

	for side in ["up", "right", "down", "left"]:
		_create_wall(coord, origin, side, room["doors"].has(side))
	if coord == Vector2i(0, 5):
		_create_exit_marker(coord)


func _create_exit_marker(room: Vector2i) -> void:
	var marker := Node3D.new()
	marker.name = "ExitMarker"
	marker.position = world_position(room, Vector2(0.5, 4.5), 0.018)
	var disc := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.52
	mesh.bottom_radius = 0.52
	mesh.height = 0.025
	disc.mesh = mesh
	disc.material_override = _material(Color(0.16, 0.82, 0.5, 0.36), 0.9, true, true)
	_register_room_visual(room, disc)
	marker.add_child(disc)
	var label := Label3D.new()
	label.text = "撤"
	label.font_size = 48
	label.pixel_size = 0.008
	label.position.y = 0.16
	label.modulate = Color("#85f3b5")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_register_room_visual(room, label)
	marker.add_child(label)
	level_root.add_child(marker)


func _create_wall(room: Vector2i, origin: Vector3, side: String, has_door: bool) -> void:
	var height := 1.05
	var material := wall_material
	var total := ROOM_EXTENT * 2.0
	var gap := 2.65
	if not has_door:
		_add_wall_piece(room, origin, side, 0.0, total, height, material)
		return
	var segment := (total - gap) / 2.0
	var offset := gap / 2.0 + segment / 2.0
	_add_wall_piece(room, origin, side, -offset, segment, height, material)
	_add_wall_piece(room, origin, side, offset, segment, height, material)
	_add_door_post(room, origin, side, -gap / 2.0, height + 0.2)
	_add_door_post(room, origin, side, gap / 2.0, height + 0.2)


func _add_wall_piece(room: Vector2i, origin: Vector3, side: String, offset: float, length: float, height: float, material: Material) -> void:
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	if side == "up" or side == "down":
		mesh.size = Vector3(length, height, 0.18)
		wall.position = origin + Vector3(offset, height / 2.0, -ROOM_EXTENT if side == "up" else ROOM_EXTENT)
	else:
		mesh.size = Vector3(0.18, height, length)
		wall.position = origin + Vector3(-ROOM_EXTENT if side == "left" else ROOM_EXTENT, height / 2.0, offset)
	wall.mesh = mesh
	wall.material_override = material
	_register_room_visual(room, wall)
	level_root.add_child(wall)


func _add_door_post(room: Vector2i, origin: Vector3, side: String, offset: float, height: float) -> void:
	var post := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, height, 0.16)
	post.mesh = mesh
	post.material_override = dark_material
	if side == "up" or side == "down":
		post.position = origin + Vector3(offset, height / 2.0, -ROOM_EXTENT if side == "up" else ROOM_EXTENT)
	else:
		post.position = origin + Vector3(-ROOM_EXTENT if side == "left" else ROOM_EXTENT, height / 2.0, offset)
	_register_room_visual(room, post)
	level_root.add_child(post)


func _create_actor(role: String, layer: int) -> Node3D:
	var actor := Node3D.new()
	actor.name = "MonsterCutout" if role == "monster" else "ThiefCutout"
	world_root.add_child(actor)
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.42
	shadow_mesh.bottom_radius = 0.42
	shadow_mesh.height = 0.025
	shadow.mesh = shadow_mesh
	shadow.material_override = dark_material
	shadow.position.y = 0.02
	shadow.scale.z = 0.55
	shadow.layers = layer
	actor.add_child(shadow)
	var sprite := Sprite3D.new()
	sprite.name = "PaperSprite"
	sprite.texture = load("res://assets/25d/monster.svg" if role == "monster" else "res://assets/25d/thief.svg")
	sprite.pixel_size = 0.0092
	sprite.position.y = 0.86
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.layers = layer
	actor.add_child(sprite)
	return actor


func _create_furniture_node(room: Vector2i, furniture: Dictionary) -> void:
	var node := Node3D.new()
	node.name = str(furniture["id"])
	level_root.add_child(node)
	var base := MeshInstance3D.new()
	base.name = "Base"
	var mesh := BoxMesh.new()
	var kind: String = furniture["kind"]
	if kind == "沙发":
		mesh.size = Vector3(1.35, 0.32, 0.72)
	elif kind == "柜子":
		mesh.size = Vector3(0.82, 0.72, 0.68)
	else:
		mesh.size = Vector3(1.15, 0.38, 0.82)
	base.mesh = mesh
	base.material_override = _material(Color("#4a4338"), 0.94)
	base.position.y = mesh.size.y / 2.0
	_register_room_visual(room, base)
	node.add_child(base)
	var selection := MeshInstance3D.new()
	selection.name = "SelectionRing"
	var selection_mesh := CylinderMesh.new()
	selection_mesh.top_radius = 0.78
	selection_mesh.bottom_radius = 0.78
	selection_mesh.height = 0.022
	selection.mesh = selection_mesh
	selection.material_override = _material(Color(1.0, 0.79, 0.18, 0.38), 0.9, true, true)
	selection.position.y = 0.015
	_register_room_visual(room, selection)
	selection.visible = false
	node.add_child(selection)
	var sprite := Sprite3D.new()
	sprite.name = "PaperSprite"
	var path := "res://assets/25d/sofa.svg"
	if kind == "柜子":
		path = "res://assets/25d/cabinet.svg"
	elif kind == "桌子":
		path = "res://assets/25d/table.svg"
	sprite.texture = load(path)
	sprite.pixel_size = 0.0068
	sprite.position.y = 0.9
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_register_room_visual(room, sprite)
	node.add_child(sprite)
	var state_label := Label3D.new()
	state_label.name = "StateLabel"
	state_label.font_size = 30
	state_label.pixel_size = 0.005
	state_label.position = Vector3(0, 1.42, 0)
	state_label.modulate = Color("#f0d773")
	state_label.outline_modulate = Color("#171814")
	state_label.outline_size = 5
	state_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	state_label.no_depth_test = true
	_register_room_visual(room, state_label)
	node.add_child(state_label)
	node.position = world_position(room, furniture["pos"])
	node.rotation.y = -deg_to_rad(float(furniture["rotation"]))
	furniture_nodes[furniture["id"]] = node


func _create_item_node(room: Vector2i, item: Dictionary) -> void:
	var node := Node3D.new()
	node.name = str(item["id"])
	level_root.add_child(node)
	var sprite := Sprite3D.new()
	sprite.texture = load("res://assets/25d/pill.svg" if item["kind"] == "pill" else "res://assets/25d/treasure.svg")
	sprite.pixel_size = 0.0048 if item["kind"] == "pill" else (0.0046 if item["kind"] == "trinket" else 0.0055)
	sprite.position.y = 0.42
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_register_room_visual(room, sprite)
	node.add_child(sprite)
	if item["kind"] == "treasure" or item["kind"] == "trinket":
		var value_label := Label3D.new()
		value_label.text = str(item["value"])
		value_label.font_size = 36
		value_label.pixel_size = 0.0055
		value_label.position = Vector3(0, 0.82, 0)
		value_label.modulate = Color("#201d16")
		value_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_register_room_visual(room, value_label)
		node.add_child(value_label)
	node.position = world_position(room, item["pos"])
	item_nodes[item["id"]] = node


func _create_attack_cone() -> MeshInstance3D:
	var cone := MeshInstance3D.new()
	cone.name = "AttackCone"
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		Vector3(0, 0, 0),
		Vector3(-2.35, 0, -2.35),
		Vector3(2.35, 0, -2.35),
	])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	cone.mesh = mesh
	cone.material_override = _material(Color(0.95, 0.19, 0.09, 0.3), 1.0, true, true)
	cone.layers = LAYER_MONSTER_EFFECT
	cone.visible = false
	world_root.add_child(cone)
	return cone


func sync(rooms: Array, monster: Dictionary, thief: Dictionary, afterimages: Array, selected: Dictionary, attack_active: bool, time: float) -> void:
	if not initialized:
		return
	_sync_actor(monster_node, monster, time, false)
	_sync_actor(thief_node, thief, time, true)
	_follow_camera(monster_camera, monster, "monster")
	_follow_camera(thief_camera, thief, "thief")
	for room in rooms:
		var coord: Vector2i = room["coord"]
		for furniture in room["furniture"]:
			var furniture_id: String = furniture["id"]
			if not furniture_nodes.has(furniture_id):
				_create_furniture_node(coord, furniture)
			var furniture_node: Node3D = furniture_nodes[furniture_id]
			furniture_node.position = world_position(coord, furniture["pos"])
			var content_value := _furniture_content_value(furniture)
			var shake_degrees := 0.0
			if not bool(furniture.get("destroyed", false)) and content_value > 0:
				shake_degrees = minf(1.2 + float(content_value) * 1.25, 11.0)
			if time - float(furniture.get("last_hit_time", -10.0)) < 0.48:
				shake_degrees = maxf(shake_degrees, 13.0)
			var phase := float(abs(str(furniture_id).hash()) % 628) / 100.0
			furniture_node.rotation.y = -deg_to_rad(float(furniture["rotation"])) + deg_to_rad(sin(time * 5.2 + phase) * shake_degrees)
			furniture_node.scale = Vector3(1.0, 0.5, 1.0) if bool(furniture.get("destroyed", false)) else Vector3.ONE
			var ring: MeshInstance3D = furniture_node.get_node("SelectionRing")
			ring.visible = selected["monster"] == furniture_id or selected["thief"] == furniture_id
			var state_label: Label3D = furniture_node.get_node("StateLabel")
			if bool(furniture.get("destroyed", false)):
				state_label.text = "已损毁"
				state_label.modulate = Color("#c97868")
			elif int(furniture.get("damage", 0)) > 0:
				state_label.text = "%d / %d" % [furniture["damage"], furniture["durability"]]
				state_label.modulate = Color("#e99a66")
			elif bool(furniture.get("opened", false)):
				state_label.text = "可存取"
				state_label.modulate = Color("#f0d773")
			else:
				state_label.text = ""
		for item in room["items"]:
			var item_id: String = item["id"]
			if not item_nodes.has(item_id):
				_create_item_node(coord, item)
			var item_node: Node3D = item_nodes[item_id]
			item_node.position = world_position(coord, item["pos"])
			item_node.visible = not bool(item["collected"]) and not _item_hidden(room, item)
		_sync_room_marks(room)
	_sync_afterimages(afterimages)
	_sync_attack(monster, attack_active)
	_sync_room_layers(monster["room"], thief["room"])


func _furniture_content_value(furniture: Dictionary) -> int:
	var total := 0
	for content in furniture.get("contents", []):
		total += int(content.get("value", 0))
	return total


func _sync_actor(node: Node3D, actor: Dictionary, time: float, is_thief: bool) -> void:
	var visual_pos: Vector2 = actor["pos"] + actor.get("impact_visual_offset", Vector2.ZERO)
	node.position = world_position(actor["room"], visual_pos)
	var sprite: Sprite3D = node.get_node("PaperSprite")
	var dir: String = actor["dir"]
	sprite.flip_h = dir == "left"
	var phase_offset := 1.6 if is_thief else 0.0
	sprite.rotation.z = sin(time * 3.2 + phase_offset) * 0.018
	sprite.position.y = 0.86 + sin(time * 4.0 + phase_offset) * 0.018


func _follow_camera(camera: Camera3D, actor: Dictionary, role: String) -> void:
	var target := world_position(actor["room"], actor["pos"], 0.38)
	# Zero degrees is deliberately aligned with the room axes:
	# screen right = world +X, screen up = world -Z.
	# Follow the actor at a fixed offset so movement never changes actor scale.
	var offset := Vector3(0.0, CAMERA_HEIGHT, CAMERA_DISTANCE)
	offset = offset.rotated(Vector3.UP, deg_to_rad(float(camera_yaw_degrees[role])))
	camera.position = target + offset
	camera.look_at(target, Vector3.UP)


func rotate_camera(role: String, direction: int) -> void:
	camera_yaw_degrees[role] = fmod(float(camera_yaw_degrees[role]) + float(direction) * 45.0 + 360.0, 360.0)


func camera_relative_vector(role: String, screen_input: Vector2) -> Vector2:
	if screen_input.is_zero_approx():
		return Vector2.ZERO
	var angle := -deg_to_rad(float(camera_yaw_degrees[role]))
	return screen_input.normalized().rotated(angle)


func _sync_attack(monster: Dictionary, active: bool) -> void:
	attack_cone.visible = active
	if not active:
		return
	attack_cone.position = world_position(monster["room"], monster["pos"], 0.055)
	match monster["dir"]:
		"up": attack_cone.rotation.y = 0.0
		"right": attack_cone.rotation.y = -PI / 2.0
		"down": attack_cone.rotation.y = PI
		"left": attack_cone.rotation.y = PI / 2.0


func _sync_afterimages(images: Array) -> void:
	var live: Dictionary = {}
	for image in images:
		var key := "%.4f" % float(image["created"])
		live[key] = true
		if not afterimage_nodes.has(key):
			var node := Node3D.new()
			var sprite := Sprite3D.new()
			sprite.texture = load("res://assets/25d/thief.svg")
			sprite.pixel_size = 0.0092
			sprite.position.y = 0.86
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.no_depth_test = true
			sprite.modulate = Color(1.0, 0.13, 0.1, 0.58)
			sprite.layers = LAYER_AFTERIMAGE
			node.add_child(sprite)
			world_root.add_child(node)
			afterimage_nodes[key] = node
		var image_node: Node3D = afterimage_nodes[key]
		image_node.position = world_position(image["room"], image["pos"])
	for key in afterimage_nodes.keys():
		if not live.has(key):
			var stale: Node3D = afterimage_nodes[key]
			stale.queue_free()
			afterimage_nodes.erase(key)


func _sync_room_marks(room: Dictionary) -> void:
	var coord: Vector2i = room["coord"]
	for index in range(room["traces"].size()):
		var trace_key := "%d_%d_trace_%d" % [coord.x, coord.y, index]
		if not trace_nodes.has(trace_key):
			var trace: Dictionary = room["traces"][index]
			trace_nodes[trace_key] = _create_cross_mark(
				coord,
				world_position(coord, trace["pos"], 0.025),
				trace_thief_material if trace["role"] == "thief" else trace_monster_material
			)
	for index in range(room["strokes"].size()):
		var stroke_key := "%d_%d_stroke_%d" % [coord.x, coord.y, index]
		if not stroke_nodes.has(stroke_key):
			var stroke: Dictionary = room["strokes"][index]
			stroke_nodes[stroke_key] = _create_stroke(
				coord,
				world_position(coord, stroke["from"], 0.018),
				world_position(coord, stroke["to"], 0.018)
			)


func _create_cross_mark(room: Vector2i, position: Vector3, material: Material) -> Node3D:
	var root := Node3D.new()
	root.position = position
	for angle in [-PI / 4.0, PI / 4.0]:
		var bar := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.44, 0.022, 0.045)
		bar.mesh = mesh
		bar.material_override = material
		bar.rotation.y = angle
		_register_room_visual(room, bar)
		root.add_child(bar)
	level_root.add_child(root)
	return root


func _create_stroke(room: Vector2i, from: Vector3, to: Vector3) -> Node3D:
	var delta := to - from
	var root := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.032, 0.018, maxf(delta.length(), 0.015))
	root.mesh = mesh
	root.material_override = dark_material
	root.position = (from + to) / 2.0
	root.rotation.y = atan2(delta.x, delta.z)
	_register_room_visual(room, root)
	level_root.add_child(root)
	return root


func _room_key(room: Vector2i) -> String:
	return "%d:%d" % [room.x, room.y]


func _register_room_visual(room: Vector2i, visual: VisualInstance3D) -> void:
	var key := _room_key(room)
	if not room_visuals.has(key):
		room_visuals[key] = []
	room_visuals[key].append(visual)
	visual.layers = _layers_for_room_key(key)


func _sync_room_layers(monster_room: Vector2i, thief_room: Vector2i) -> void:
	if monster_room == active_monster_room and thief_room == active_thief_room:
		return
	# Enable the destination rooms first. The previous rooms remain visible until
	# every new layer has reached the renderer, preventing a transient black frame.
	_apply_room_layer(monster_room, LAYER_MONSTER_WORLD)
	_apply_room_layer(thief_room, LAYER_THIEF_WORLD)
	active_monster_room = monster_room
	active_thief_room = thief_room
	for key in room_visuals.keys():
		var desired_layers := _layers_for_room_key(key)
		for visual in room_visuals[key]:
			if is_instance_valid(visual):
				var instance := visual as VisualInstance3D
				if instance.layers != desired_layers:
					instance.layers = desired_layers


func _layers_for_room_key(key: String) -> int:
	var layers := 0
	if key == _room_key(active_monster_room):
		layers |= LAYER_MONSTER_WORLD
	if key == _room_key(active_thief_room):
		layers |= LAYER_THIEF_WORLD
	return layers


func _apply_room_layer(room: Vector2i, layer: int) -> void:
	var key := _room_key(room)
	if not room_visuals.has(key):
		return
	for visual in room_visuals[key]:
		if is_instance_valid(visual):
			var instance := visual as VisualInstance3D
			instance.layers = instance.layers | layer


func _item_hidden(room: Dictionary, item: Dictionary) -> bool:
	for furniture in room["furniture"]:
		if bool(furniture.get("destroyed", false)):
			continue
		var furniture_pos: Vector2 = furniture["pos"]
		var item_pos: Vector2 = item["pos"]
		if furniture_pos.distance_to(item_pos) < 0.44:
			return true
	return false


func room_origin(room: Vector2i) -> Vector3:
	return Vector3(room.x * ROOM_SPACING, 0, room.y * ROOM_SPACING)


func world_position(room: Vector2i, pos: Vector2, y := 0.0) -> Vector3:
	return room_origin(room) + Vector3((pos.x - 2.5) * CELL_SIZE, y, (pos.y - 2.5) * CELL_SIZE)


func texture_for(role: String) -> Texture2D:
	if role == "monster":
		return monster_viewport.get_texture()
	return thief_viewport.get_texture()


func project_normalized(role: String, room: Vector2i, pos: Vector2, y := 0.25) -> Vector2:
	var camera := monster_camera if role == "monster" else thief_camera
	var viewport := monster_viewport if role == "monster" else thief_viewport
	var pixel: Vector2 = camera.unproject_position(world_position(room, pos, y))
	return pixel / Vector2(viewport.size)
