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
const DOOR_GAP := 2.65
const ITEM_SHAKE_CYCLE := 2.35
const ITEM_SHAKE_BURST := 0.78
const ITEM_SHAKE_FREQUENCY := 31.0
const ITEM_SHAKE_DISTANCE := 0.11
const INVALID_ROOM := Vector2i(-999, -999)

const LAYER_MONSTER_WORLD := 1
const LAYER_MONSTER := 2
const LAYER_THIEF := 4
const LAYER_AFTERIMAGE := 8
const LAYER_MONSTER_EFFECT := 16
const LAYER_THIEF_WORLD := 32
const LAYER_SHARED_ACTORS := 64
const LAYER_MONSTER_GHOST := 128
const LAYER_THIEF_GHOST := 256

const FLOOR_TEXTURES := [
	"res://GJGamejam素材/地板/木色地板2.png",
	"res://GJGamejam素材/地板/木色地板3.png",
	"res://GJGamejam素材/地板/纯木色地板.png",
	"res://GJGamejam素材/地板/像素地板1.png",
	"res://GJGamejam素材/地板/像素地板2.png",
	"res://GJGamejam素材/地板/像素地板3.png",
	"res://GJGamejam素材/地板/像素地板4.png",
	"res://GJGamejam素材/地板/像素地板5.png",
	"res://GJGamejam素材/地板/像素地板6.png",
	"res://GJGamejam素材/地板/像素地板7.png",
	"res://GJGamejam素材/地板/像素地板8.png",
	"res://GJGamejam素材/地板/像素地板9.png",
]

const CRACK_TEXTURES := [
	"res://GJGamejam素材/地板/地板裂纹1.png",
	"res://GJGamejam素材/地板/地板裂纹2.png",
	"res://GJGamejam素材/地板/地板裂纹3.png",
	"res://GJGamejam素材/地板/地板裂纹4.png",
	"res://GJGamejam素材/地板/地板裂纹5.png",
	"res://GJGamejam素材/地板/地板裂纹6.png",
]

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
var monster_ghost_visuals: Dictionary = {}
var thief_ghost_visuals: Dictionary = {}
var monster_ghost_shader: ShaderMaterial
var thief_ghost_shader: ShaderMaterial
var room_lights: Dictionary = {}
const LIGHT_MAX_DIST := 4.8
const LIGHT_MIN_BRIGHT := 0.15
const LIGHT_MAX_BRIGHT := 1.0
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
var wall2_material: StandardMaterial3D
var wall_frame_material: ShaderMaterial
var wall_solid_material: ShaderMaterial
var original_walls: Dictionary = {}
var full_walls: Dictionary = {}
var monster_full_walls: Dictionary = {}
var thief_full_walls: Dictionary = {}
var wall_fades: Dictionary = {}
var room_pillars: Dictionary = {}
var furniture_bounces: Dictionary = {}
const WALL_FADE_DURATION := 0.4
const FURNITURE_BOUNCE_DURATION := 1.3
const FURNITURE_FALL_DURATION := 0.3
const FURNITURE_DROP_HEIGHT := 10.0

const FULL_WALL_HEIGHT := 8.5


func setup(shared_world: World3D) -> void:
	if initialized:
		return
	# The 2D editor viewport has no World3D even though @tool runs this setup.
	# Give the preview SubViewports their own world instead of leaving setup
	# half-finished and producing null-node errors every editor frame.
	var render_world: World3D = shared_world if shared_world != null else World3D.new()
	world_root = Node3D.new()
	world_root.name = "World25D"
	add_child(world_root)
	level_root = Node3D.new()
	level_root.name = "GeneratedMansion"
	world_root.add_child(level_root)
	_create_materials()
	_create_environment()
	# Ensure both SubViewports receive the same environment by setting it
	# directly on the shared World3D resource.
	var env_node: WorldEnvironment = world_root.get_node_or_null("GothicEnvironment")
	if env_node:
		render_world.environment = env_node.environment
	monster_viewport = _create_viewport("MonsterViewport", render_world)
	thief_viewport = _create_viewport("ThiefViewport", render_world)
	monster_camera = _create_camera(monster_viewport, "MonsterCamera", LAYER_MONSTER_WORLD | LAYER_MONSTER | LAYER_SHARED_ACTORS | LAYER_AFTERIMAGE | LAYER_MONSTER_EFFECT | LAYER_MONSTER_GHOST)
	thief_camera = _create_camera(thief_viewport, "ThiefCamera", LAYER_THIEF_WORLD | LAYER_THIEF | LAYER_SHARED_ACTORS | LAYER_THIEF_GHOST)
	monster_node = _create_actor("monster", LAYER_MONSTER)
	thief_node = _create_actor("thief", LAYER_THIEF)
	attack_cone = _create_attack_cone()
	initialized = true


func _create_materials() -> void:
	floor_material = _material(Color("#514f45"), 0.96)
	floor_alt_material = _material(Color("#5a584b"), 0.96)
	wall_material = _wall_texture_material()
	wall_front_material = wall_material
	dark_material = _material(Color(0.035, 0.035, 0.03, 0.62), 1.0, true)
	trace_monster_material = _material(Color("#5e2922"), 1.0)
	trace_thief_material = _material(Color("#245a50"), 1.0)
	wall2_material = StandardMaterial3D.new()
	wall2_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall2_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wall_shader := load("res://scripts/wall_light.gdshader") as Shader
	wall_frame_material = ShaderMaterial.new()
	wall_frame_material.shader = wall_shader
	wall_frame_material.set_shader_parameter("wall_tex", load("res://GJGamejam素材/wallHD_frame_256_prev.png"))
	wall_solid_material = ShaderMaterial.new()
	wall_solid_material.shader = wall_shader
	wall_solid_material.set_shader_parameter("wall_tex", load("res://GJGamejam素材/wallHD_solid_256_prev.png"))
	_create_ghost_materials()


func _material(color: Color, roughness: float, transparent := false, unshaded := false) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if unshaded:
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


func _floor_texture_material(path: String) -> ShaderMaterial:
	var shader := load("res://scripts/floor_light.gdshader") as Shader
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("floor_tex", load(path))
	return material


func _wall_texture_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://GJGamejam素材/墙壁.png")
	material.uv1_scale = Vector3(0.3, 0.3, 0.3)
	material.uv1_triplanar = true
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.35, 0.35, 0.33)  # match dimmed floor mid-brightness
	return material


func _create_environment() -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "GothicEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#171814")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#9f9a84")
	environment.ambient_light_energy = 0.25
	environment.ambient_light_sky_contribution = 0.0
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment_node.environment = environment
	world_root.add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"
	sun.rotation_degrees = Vector3(-58, -38, 0)
	sun.light_color = Color("#d8d3ba")
	sun.light_energy = 0.45
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
	monster_ghost_visuals.clear()
	thief_ghost_visuals.clear()
	room_lights.clear()
	original_walls.clear()
	full_walls.clear()
	monster_full_walls.clear()
	thief_full_walls.clear()
	wall_fades.clear()
	furniture_bounces.clear()
	room_pillars.clear()
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
	var floor_node: MeshInstance3D  # Saved for light-position update after light creation

	if room.has("floor_texture"):
		# PlaneMesh with whole texture covering the room — no tiling
		var floor := MeshInstance3D.new()
		floor.name = "Floor_%d_%d" % [coord.x, coord.y]
		var plane_mesh := PlaneMesh.new()
		var floor_size := (ROOM_EXTENT * 2.0 - 0.3) * 1.05
		plane_mesh.size = Vector2(floor_size, floor_size)
		plane_mesh.orientation = PlaneMesh.FACE_Y
		floor.mesh = plane_mesh
		floor.material_override = _floor_texture_material(room["floor_texture"])
		floor.position = origin + Vector3(0, -0.08, 0)
		_register_room_visual(coord, floor)
		level_root.add_child(floor)
		floor_node = floor
	else:
		var alt_floor := MeshInstance3D.new()
		alt_floor.name = "Floor_%d_%d" % [coord.x, coord.y]
		var alt_mesh := BoxMesh.new()
		var alt_size := (ROOM_EXTENT * 2.0 - 0.3) * 1.05
		alt_mesh.size = Vector3(alt_size, 0.12, alt_size)
		alt_floor.mesh = alt_mesh
		alt_floor.material_override = floor_material if (coord.x + coord.y) % 2 == 0 else floor_alt_material
		alt_floor.position = origin + Vector3(0, -0.08, 0)
		_register_room_visual(coord, alt_floor)
		level_root.add_child(alt_floor)
		floor_node = alt_floor

	# Black outline strips around floor perimeter
	var floor_tex: String = room.get("floor_texture", "")
	_add_floor_outline(coord, origin, floor_tex)

	# Random crack decals on floor
	_add_floor_cracks(coord, origin)

	var inset := MeshInstance3D.new()
	var inset_mesh := BoxMesh.new()
	inset_mesh.size = Vector3(ROOM_EXTENT * 2.0 - 0.7, 0.025, ROOM_EXTENT * 2.0 - 0.7)
	inset.mesh = inset_mesh
	inset.material_override = _material(Color(0.08, 0.075, 0.06, 0.18), 1.0, true)
	inset.position = origin + Vector3(0, 0.002, 0)
	_register_room_visual(coord, inset)
	level_root.add_child(inset)

	for side in ["up", "right", "down", "left"]:
		_create_wall(coord, origin, side, room["doors"].has(side))
	_create_full_walls(coord, origin, room["doors"])
	_create_room_pillars(coord, origin)
	_create_room_lights(coord, origin)
	# Update floor + wall shaders with the light position
	var rk := _room_key(coord)
	var lights: Array = room_lights.get(rk, [])
	if not lights.is_empty():
		var light_pos: Vector3 = lights[0]
		if floor_node and room.has("floor_texture"):
			var mat: ShaderMaterial = floor_node.material_override as ShaderMaterial
			if mat:
				mat.set_shader_parameter("light_position", light_pos)
		# Update wall shaders too
		for fw_dict in [monster_full_walls, thief_full_walls]:
			if fw_dict.has(rk):
				for side_node in fw_dict[rk].values():
					if is_instance_valid(side_node):
						var wmat: ShaderMaterial = side_node.material_override as ShaderMaterial
						if wmat:
							wmat.set_shader_parameter("light_position", light_pos)
	if coord == Vector2i(0, 5):
		_create_exit_marker(coord)
	_create_ghost_room(coord, origin, room["doors"])


func _create_ghost_materials() -> void:
	var shader := load("res://scripts/ghost_fade.gdshader") as Shader
	if not shader:
		push_error("Failed to load ghost_fade.gdshader")
		return
	monster_ghost_shader = ShaderMaterial.new()
	monster_ghost_shader.shader = shader
	thief_ghost_shader = ShaderMaterial.new()
	thief_ghost_shader.shader = shader


func _create_room_lights(coord: Vector2i, origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(coord.x * 997 + coord.y * 1013 + 777)
	# Invisible light source — random position within room
	var light_pos := origin + Vector3(
		rng.randf_range(-ROOM_EXTENT + 2.2, ROOM_EXTENT - 2.2),
		0.025,
		rng.randf_range(-ROOM_EXTENT + 2.2, ROOM_EXTENT - 2.2),
	)
	room_lights[_room_key(coord)] = [light_pos]


func _create_full_walls(coord: Vector2i, origin: Vector3, doors: Array) -> void:
	var room_key := _room_key(coord)
	var wall_width := ROOM_EXTENT * 2.0 + 0.5
	# PlaneMesh like the floor — UV 0-1 fills the wall, centre-aligned.
	var side_data := {
		"up":    {"pos": origin + Vector3(0, FULL_WALL_HEIGHT / 2.0, -ROOM_EXTENT), "rot_y": 0.0},
		"down":  {"pos": origin + Vector3(0, FULL_WALL_HEIGHT / 2.0,  ROOM_EXTENT), "rot_y": PI},
		"left":  {"pos": origin + Vector3(-ROOM_EXTENT, FULL_WALL_HEIGHT / 2.0, 0), "rot_y": PI / 2.0},
		"right": {"pos": origin + Vector3( ROOM_EXTENT, FULL_WALL_HEIGHT / 2.0, 0), "rot_y": -PI / 2.0},
	}
	for role_info in [{"role": "monster", "dict": monster_full_walls, "layer": LAYER_MONSTER_WORLD}, {"role": "thief", "dict": thief_full_walls, "layer": LAYER_THIEF_WORLD}]:
		var role_nodes: Dictionary = {}
		for side in ["up", "right", "down", "left"]:
			var wall := MeshInstance3D.new()
			wall.name = "FullWall_%s_%s_%d_%d" % [role_info["role"], side, coord.x, coord.y]
			var plane := PlaneMesh.new()
			plane.size = Vector2(wall_width, FULL_WALL_HEIGHT)
			plane.orientation = PlaneMesh.FACE_Z
			wall.mesh = plane
			wall.material_override = (wall_frame_material if doors.has(side) else wall_solid_material).duplicate()
			wall.material_override.set_shader_parameter("fade_alpha", 0.0)
			wall.position = side_data[side]["pos"]
			wall.rotation.y = side_data[side]["rot_y"]
			wall.layers = 0
			level_root.add_child(wall)
			# Black outline strips around full wall edges
			var outline_mat := StandardMaterial3D.new()
			outline_mat.albedo_color = Color.BLACK
			outline_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var hw := wall_width / 2.0
			var hh := FULL_WALL_HEIGHT / 2.0
			for strip_info in [
				{"size": Vector3(wall_width, 0.04, 0.02), "off": Vector3(0,  hh, 0)},
				{"size": Vector3(wall_width, 0.04, 0.02), "off": Vector3(0, -hh, 0)},
				{"size": Vector3(0.04, FULL_WALL_HEIGHT, 0.02), "off": Vector3( hw, 0, 0)},
				{"size": Vector3(0.04, FULL_WALL_HEIGHT, 0.02), "off": Vector3(-hw, 0, 0)},
			]:
				var strip := MeshInstance3D.new()
				var strip_mesh := BoxMesh.new()
				strip_mesh.size = strip_info["size"]
				strip.mesh = strip_mesh
				strip.material_override = outline_mat
				strip.position = side_data[side]["pos"] + strip_info["off"]
				strip.rotation.y = side_data[side]["rot_y"]
				strip.layers = 0
				level_root.add_child(strip)
			role_nodes[side] = wall
		role_info["dict"][room_key] = role_nodes
	# Hide original walls — keep collision, full walls are the new visuals
	var ow_key := _room_key(coord)
	if original_walls.has(ow_key):
		for side in original_walls[ow_key]:
			for node in original_walls[ow_key][side]:
				if is_instance_valid(node):
					node.visible = false


func _sync_full_walls(room_coord: Vector2i, yaw: float, role: String) -> void:
	var room_key := _room_key(room_coord)
	var fw_dict := monster_full_walls if role == "monster" else thief_full_walls
	if not fw_dict or not fw_dict.has(room_key):
		return
	var y := fmod(-yaw + 360.0, 360.0)
	var hidden: Array[String] = []
	if y < 22.5 or y >= 337.5:
		hidden = ["down"]
	elif y < 67.5:
		hidden = ["down", "left"]
	elif y < 112.5:
		hidden = ["left"]
	elif y < 157.5:
		hidden = ["left", "up"]
	elif y < 202.5:
		hidden = ["up"]
	elif y < 247.5:
		hidden = ["up", "right"]
	elif y < 292.5:
		hidden = ["right"]
	else:
		hidden = ["right", "down"]
	var fw: Dictionary = fw_dict[room_key]
	for side in ["up", "right", "down", "left"]:
		if is_instance_valid(fw.get(side)):
			fw[side].visible = not hidden.has(side)
	if original_walls.has(room_key):
		var ow: Dictionary = original_walls[room_key]
		for side in ["up", "right", "down", "left"]:
			for node in ow.get(side, []):
				if is_instance_valid(node):
					node.visible = hidden.has(side)
	# Hide vertical pillars on camera-side corners
	if room_pillars and room_pillars.has(room_key):
		var pillars: Dictionary = room_pillars[room_key]
		for corner in ["up_left", "up_right", "down_left", "down_right"]:
			var p_node = pillars.get(corner)
			if is_instance_valid(p_node):
				var sides: PackedStringArray = corner.split("_")
				p_node.visible = not (hidden.has(sides[0]) and hidden.has(sides[1]))


func _create_room_pillars(coord: Vector2i, origin: Vector3) -> void:
	var hw := ROOM_EXTENT
	var h := FULL_WALL_HEIGHT
	var pillar_size := 0.12
	var black := StandardMaterial3D.new()
	black.albedo_color = Color.BLACK
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# 4 vertical corner pillars — tracked per corner for camera-direction hiding
	var pillar_nodes: Dictionary = {}
	for x in [-hw, hw]:
		for z in [-hw, hw]:
			var p := MeshInstance3D.new()
			p.name = "Pillar_V_%d_%d" % [coord.x, coord.y]
			var m := BoxMesh.new()
			m.size = Vector3(pillar_size, h, pillar_size)
			p.mesh = m
			p.material_override = black
			p.position = origin + Vector3(x, h / 2.0, z)
			_register_room_visual(coord, p)
			level_root.add_child(p)
			var corner: String = ("up" if z < 0 else "down") + "_" + ("left" if x < 0 else "right")
			pillar_nodes[corner] = p
	room_pillars[_room_key(coord)] = pillar_nodes
	# 4 bottom horizontal edge pillars (thicker)
	var bottom_pillar := 0.35
	for z in [-hw, hw]:
		var bpz := MeshInstance3D.new()
		var bmz := BoxMesh.new()
		bmz.size = Vector3(hw * 2.0, bottom_pillar, bottom_pillar)
		bpz.mesh = bmz
		bpz.material_override = black
		bpz.position = origin + Vector3(0, 0.0, z)
		_register_room_visual(coord, bpz)
		level_root.add_child(bpz)
	for x in [-hw, hw]:
		var bpx := MeshInstance3D.new()
		var bmx := BoxMesh.new()
		bmx.size = Vector3(bottom_pillar, bottom_pillar, hw * 2.0)
		bpx.mesh = bmx
		bpx.material_override = black
		bpx.position = origin + Vector3(x, 0.0, 0)
		_register_room_visual(coord, bpx)
		level_root.add_child(bpx)


func _create_ghost_room(coord: Vector2i, origin: Vector3, doors: Array) -> void:
	var room_key := _room_key(coord)
	var floor_size := (ROOM_EXTENT * 2.0 - 0.3) * 1.05

	# Ghost floor — one copy per ghost layer
	for layer in [LAYER_MONSTER_GHOST, LAYER_THIEF_GHOST]:
		var mat := monster_ghost_shader if layer == LAYER_MONSTER_GHOST else thief_ghost_shader
		var ghost_floor := MeshInstance3D.new()
		ghost_floor.name = "GhostFloor_%d_%d" % [coord.x, coord.y]
		var plane := PlaneMesh.new()
		plane.size = Vector2(floor_size, floor_size)
		plane.orientation = PlaneMesh.FACE_Y
		ghost_floor.mesh = plane
		ghost_floor.material_override = mat
		ghost_floor.position = origin + Vector3(0, -0.06, 0)
		ghost_floor.layers = layer
		level_root.add_child(ghost_floor)
		if layer == LAYER_MONSTER_GHOST:
			if not monster_ghost_visuals.has(room_key):
				monster_ghost_visuals[room_key] = []
			monster_ghost_visuals[room_key].append(ghost_floor)
		else:
			if not thief_ghost_visuals.has(room_key):
				thief_ghost_visuals[room_key] = []
			thief_ghost_visuals[room_key].append(ghost_floor)

	# Ghost walls with door openings — one copy per ghost layer
	var height := 1.05
	var total := ROOM_EXTENT * 2.0
	var gap := 2.65
	for side in ["up", "right", "down", "left"]:
		var has_door: bool = doors.has(side)
		for layer in [LAYER_MONSTER_GHOST, LAYER_THIEF_GHOST]:
			var mat := monster_ghost_shader if layer == LAYER_MONSTER_GHOST else thief_ghost_shader
			if not has_door:
				_add_ghost_wall_piece(coord, origin, side, 0.0, total, height, layer, mat)
			else:
				var segment := (total - gap) / 2.0
				var offset := gap / 2.0 + segment / 2.0
				_add_ghost_wall_piece(coord, origin, side, -offset, segment, height, layer, mat)
				_add_ghost_wall_piece(coord, origin, side, offset, segment, height, layer, mat)
				# Ghost door posts
				var post_height := height + 0.2
				for post_offset in [-gap / 2.0, gap / 2.0]:
					var post := MeshInstance3D.new()
					var post_mesh := BoxMesh.new()
					post_mesh.size = Vector3(0.16, post_height, 0.16)
					post.mesh = post_mesh
					post.material_override = mat
					if side == "up" or side == "down":
						post.position = origin + Vector3(post_offset, post_height / 2.0, -ROOM_EXTENT if side == "up" else ROOM_EXTENT)
					else:
						post.position = origin + Vector3(-ROOM_EXTENT if side == "left" else ROOM_EXTENT, post_height / 2.0, post_offset)
					post.layers = layer
					level_root.add_child(post)
					if layer == LAYER_MONSTER_GHOST:
						monster_ghost_visuals[room_key].append(post)
					else:
						thief_ghost_visuals[room_key].append(post)


func _add_ghost_wall_piece(coord: Vector2i, origin: Vector3, side: String, offset: float, length: float, height: float, layer: int, mat: ShaderMaterial) -> void:
	var room_key := _room_key(coord)
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	if side == "up" or side == "down":
		var z := -ROOM_EXTENT if side == "up" else ROOM_EXTENT
		mesh.size = Vector3(length, height, 0.18)
		wall.position = origin + Vector3(offset, height / 2.0, z)
	else:
		var x := -ROOM_EXTENT if side == "left" else ROOM_EXTENT
		mesh.size = Vector3(0.18, height, length)
		wall.position = origin + Vector3(x, height / 2.0, offset)
	wall.mesh = mesh
	wall.material_override = mat
	wall.layers = layer
	level_root.add_child(wall)
	if layer == LAYER_MONSTER_GHOST:
		monster_ghost_visuals[room_key].append(wall)
	else:
		thief_ghost_visuals[room_key].append(wall)


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
	var gap := DOOR_GAP
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
		var z := -ROOM_EXTENT if side == "up" else ROOM_EXTENT
		mesh.size = Vector3(length, height, 0.18)
		wall.position = origin + Vector3(offset, height / 2.0, z)
	else:
		var x := -ROOM_EXTENT if side == "left" else ROOM_EXTENT
		mesh.size = Vector3(0.18, height, length)
		wall.position = origin + Vector3(x, height / 2.0, offset)
	wall.mesh = mesh
	wall.material_override = material
	_register_room_visual(room, wall)
	level_root.add_child(wall)
	# Track original wall for full-wall visibility toggle
	var ow_key := _room_key(room)
	if not original_walls.has(ow_key):
		original_walls[ow_key] = {"up": [], "right": [], "down": [], "left": []}
	original_walls[ow_key][side].append(wall)


func _add_wall_outline_strips(room: Vector2i, origin: Vector3, offset: float, length: float, height: float, wall_axis: float, is_z_axis: bool) -> void:
	var strip_thick := 0.03
	var strip_off := 0.005
	var half := length / 2.0
	var mat := _material(Color.BLACK, 0.9, false, true)
	# Top strip
	_create_strip(room, origin, offset, height, half, wall_axis, strip_thick, strip_off, is_z_axis, true, length, height, mat)
	# Bottom strip
	_create_strip(room, origin, offset, 0.0, half, wall_axis, strip_thick, strip_off, is_z_axis, true, length, height, mat)
	# Left/front strip
	_create_strip(room, origin, offset - half, height / 2.0, half, wall_axis, strip_thick, strip_off, is_z_axis, false, length, height, mat)
	# Right/back strip
	_create_strip(room, origin, offset + half, height / 2.0, half, wall_axis, strip_thick, strip_off, is_z_axis, false, length, height, mat)


func _create_strip(room: Vector2i, origin: Vector3, pos: float, pos_y: float, half: float, wall_axis: float, strip_thick: float, strip_off: float, is_z: bool, is_horiz: bool, wall_len: float, wall_h: float, mat: Material) -> void:
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	if is_z:
		if is_horiz:
			strip_mesh.size = Vector3(wall_len, strip_thick, 0.18)
		else:
			strip_mesh.size = Vector3(strip_thick, wall_h, 0.18)
		strip.position = origin + Vector3(pos, pos_y, wall_axis + strip_off)
	else:
		if is_horiz:
			strip_mesh.size = Vector3(0.18, strip_thick, wall_len)
		else:
			strip_mesh.size = Vector3(0.18, wall_h, strip_thick)
		strip.position = origin + Vector3(wall_axis + strip_off, pos_y, pos)
	strip.mesh = strip_mesh
	strip.material_override = mat
	_register_room_visual(room, strip)
	level_root.add_child(strip)


func _add_floor_outline(room: Vector2i, origin: Vector3, floor_tex: String) -> void:
	var half: float = ROOM_EXTENT - 0.15
	# Wooden floors keep thin outline; pixel floors get 2x thicker
	var is_wooden := floor_tex.contains("木色")
	var strip_w := 0.06 if is_wooden else 0.06
	var strip_y := -0.07
	var strip_off := 0.005
	var mat := _material(Color.BLACK, 0.9, false, true)
	var floor_len := ROOM_EXTENT * 2.0 - 0.3
	for i in range(4):
		var strip := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		if i < 2:
			# X-axis strips (top/bottom edges)
			mesh.size = Vector3(floor_len, strip_w, strip_w)
			var z := -half if i == 0 else half
			strip.position = origin + Vector3(0, strip_y, z + strip_off * (1 if i == 0 else -1))
		else:
			# Z-axis strips (left/right edges)
			mesh.size = Vector3(strip_w, strip_w, floor_len)
			var x := -half if i == 2 else half
			strip.position = origin + Vector3(x + strip_off * (1 if i == 2 else -1), strip_y, 0)
		strip.mesh = mesh
		strip.material_override = mat
		_register_room_visual(room, strip)
		level_root.add_child(strip)


func _add_floor_cracks(room: Vector2i, origin: Vector3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(room.x * 997 + room.y * 1013)
	var count := rng.randi_range(4, 8)
	var extent: float = ROOM_EXTENT - 0.4
	var crack_y := -0.065
	for _i in range(count):
		var crack := Sprite3D.new()
		crack.name = "Crack_%d_%d_%d" % [room.x, room.y, _i]
		var tex_idx := rng.randi_range(0, CRACK_TEXTURES.size() - 1)
		crack.texture = load(CRACK_TEXTURES[tex_idx])
		crack.pixel_size = 0.009
		crack.position = origin + Vector3(
			rng.randf_range(-extent, extent),
			crack_y,
			rng.randf_range(-extent, extent),
		)
		crack.rotation_degrees = Vector3(-90, rng.randf_range(0, 360), 0)
		crack.modulate = Color.BLACK
		crack.shaded = false
		crack.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		_register_room_visual(room, crack)
		level_root.add_child(crack)


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
	var actor := CharacterBody3D.new()
	actor.name = "MonsterCutout" if role == "monster" else "ThiefCutout"
	actor.collision_layer = 2
	actor.collision_mask = 1
	world_root.add_child(actor)
	var shadow := MeshInstance3D.new()
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = 0.525
	shadow_mesh.bottom_radius = 0.525
	shadow_mesh.height = 0.025
	shadow.mesh = shadow_mesh
	shadow.material_override = dark_material
	shadow.position.y = 0.02
	shadow.scale.z = 0.55
	shadow.layers = layer
	actor.add_child(shadow)
	var sway_pivot := Node3D.new()
	sway_pivot.name = "SwayPivot"
	actor.add_child(sway_pivot)
	var texture: Texture2D = load("res://GJGamejam素材/人物/怪物.png" if role == "monster" else "res://GJGamejam素材/人物/主角.png")
	var pixel_size := 0.00263 if role == "monster" else 0.00270
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var capsule := CapsuleShape3D.new()
	# The collision width and height come from the rendered cutout itself.
	# Gameplay uses the same half-width converted into room coordinates.
	capsule.radius = texture.get_width() * pixel_size * 0.5
	capsule.height = maxf(texture.get_height() * pixel_size, capsule.radius * 2.0)
	collision_shape.shape = capsule
	collision_shape.position.y = capsule.height * 0.5
	actor.add_child(collision_shape)
	# These source pixels are the center of the lowest supporting foot in each
	# cutout. The generated quad is shifted so this point, rather than the
	# texture center, is exactly above the actor's ground position.
	var foot_x := 372.0 if role == "monster" else 300.0
	var sprite := Sprite3D.new()
	sprite.name = "PaperSprite"
	sprite.texture = texture
	sprite.pixel_size = pixel_size
	sprite.position = _foot_anchored_sprite_position(texture, sprite.pixel_size, foot_x)
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	sprite.render_priority = 1
	sprite.set_meta("foot_offset_x", sprite.position.x)
	sprite.layers = layer
	sway_pivot.add_child(sprite)
	return actor


func _foot_anchored_sprite_position(texture: Texture2D, pixel_size: float, foot_x: float) -> Vector3:
	var texture_size := texture.get_size()
	return Vector3(
		(texture_size.x * 0.5 - foot_x) * pixel_size,
		texture_size.y * pixel_size * 0.5,
		0.0,
	)


func _create_furniture_node(room: Vector2i, furniture: Dictionary) -> void:
	var kind: String = furniture["kind"]
	var info := _furniture_info(kind)
	var node := Node3D.new()
	node.name = str(furniture["id"])
	level_root.add_child(node)
	var shadow := MeshInstance3D.new()
	shadow.name = "FurnitureShadow"
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = info["shadow_radius"]
	shadow_mesh.bottom_radius = info["shadow_radius"]
	shadow_mesh.height = 0.025
	shadow.mesh = shadow_mesh
	shadow.material_override = dark_material
	shadow.position.y = 0.022
	_register_room_visual(room, shadow)
	node.add_child(shadow)
	var base := MeshInstance3D.new()
	base.name = "Base"
	var mesh := BoxMesh.new()
	mesh.size = info["size"]
	base.mesh = mesh
	base.material_override = _material(Color("#4a4338"), 0.94)
	base.position.y = mesh.size.y / 2.0
	base.visible = false
	_register_room_visual(room, base)
	node.add_child(base)
	var collision_body := StaticBody3D.new()
	collision_body.name = "CollisionBody"
	collision_body.collision_layer = 1
	collision_body.collision_mask = 2
	var collision_shape := CollisionShape3D.new()
	collision_shape.name = "CollisionShape3D"
	var box_shape := BoxShape3D.new()
	box_shape.size = info["size"]
	collision_shape.shape = box_shape
	collision_shape.position.y = box_shape.size.y * 0.5
	collision_body.add_child(collision_shape)
	node.add_child(collision_body)
	var selection := MeshInstance3D.new()
	selection.name = "SelectionRing"
	var selection_mesh := CylinderMesh.new()
	selection_mesh.top_radius = info["sel_radius"]
	selection_mesh.bottom_radius = info["sel_radius"]
	selection_mesh.height = 0.022
	selection.mesh = selection_mesh
	selection.material_override = _material(Color(1.0, 0.79, 0.18, 0.38), 0.9, true, true)
	selection.position.y = 0.015
	_register_room_visual(room, selection)
	selection.visible = false
	node.add_child(selection)
	var outline_y: float = info.get("sprite_y", 0.9) - 0.02
	var sprite_y: float = info.get("sprite_y", 0.9)
	var ps: float = info["pixel_size"]
	var outline := Sprite3D.new()
	outline.name = "OutlineSprite"
	outline.texture = load(info["path"])
	outline.pixel_size = ps * 1.08
	outline.position.y = outline_y
	outline.modulate = Color.BLACK
	outline.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_register_room_visual(room, outline)
	node.add_child(outline)
	var sprite := Sprite3D.new()
	sprite.name = "PaperSprite"
	sprite.texture = load(info["path"])
	sprite.pixel_size = ps
	sprite.position.y = sprite_y
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
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


func _furniture_info(kind: String) -> Dictionary:
	match kind:
		"衣柜": return {"size": Vector3(0.87, 0.425, 0.87), "path": "res://GJGamejam素材/2.5D物品/ff_wardrobe_clean.png", "pixel_size": 0.03868, "sel_radius": 0.78, "shadow_radius": 0.60, "sprite_y": 1.21}
		"书柜": return {"size": Vector3(1.0, 0.375, 0.87), "path": "res://GJGamejam素材/2.5D物品/ff_bookshelf_clean.png", "pixel_size": 0.03868, "sel_radius": 0.78, "shadow_radius": 0.62, "sprite_y": 1.21}
		"木桶": return {"size": Vector3(0.5, 0.45, 0.5), "path": "res://GJGamejam素材/2.5D物品/lp_barrel_clean.png", "pixel_size": 0.01112, "sel_radius": 0.42, "shadow_radius": 0.35}
		"木箱": return {"size": Vector3(0.6, 0.45, 0.6), "path": "res://GJGamejam素材/2.5D物品/lp_crate_clean.png", "pixel_size": 0.01334, "sel_radius": 0.48, "shadow_radius": 0.42}
		"花瓶": return {"size": Vector3(0.28, 0.42, 0.28), "path": "res://GJGamejam素材/2.5D物品/lp_vase_clean.png", "pixel_size": 0.00622, "sel_radius": 0.28, "shadow_radius": 0.22}
		_: return {"size": Vector3(0.6, 0.45, 0.6), "path": "res://GJGamejam素材/2.5D物品/lp_crate_clean.png", "pixel_size": 0.01334, "sel_radius": 0.48, "shadow_radius": 0.42}


func _create_item_node(room: Vector2i, item: Dictionary) -> void:
	var node := Node3D.new()
	node.name = str(item["id"])
	level_root.add_child(node)
	var sprite := Sprite3D.new()
	sprite.name = "ItemSprite"
	var visual := _item_visual_info(item)
	sprite.texture = load(visual["path"])
	sprite.pixel_size = float(visual["pixel_size"])
	sprite.modulate = visual.get("color", Color.WHITE)
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	if str(item.get("device_type", "")) == "decoy":
		var foot_x := 372.0 if str(item.get("character_role", "")) == "monster" else 300.0
		sprite.position = _foot_anchored_sprite_position(sprite.texture, sprite.pixel_size, foot_x)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	else:
		sprite.position.y = float(visual.get("height", 0.42))
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


func _item_visual_info(item: Dictionary) -> Dictionary:
	var kind := str(item.get("kind", ""))
	if kind == "pill":
		return {"path": "res://assets/25d/pill.svg", "pixel_size": 0.0048}
	if kind == "treasure":
		if int(item.get("value", 0)) <= 1:
			return {"path": "res://GJGamejam素材/2.5D物品/copper_coin.png", "pixel_size": 0.0075}
		return {"path": "res://GJGamejam素材/2.5D物品/红宝石.png", "pixel_size": 0.01006}
	if kind == "trinket":
		return {"path": "res://GJGamejam素材/2.5D物品/红宝石.png", "pixel_size": 0.0084}
	var tool_type := str(item.get("tool_type", item.get("device_type", "")))
	match tool_type:
		"trap":
			return {"path": "res://GJGamejam素材/2.5D物品/r3_trapclosed_clean.png", "pixel_size": 0.0105, "height": 0.24}
		"decoy":
			if kind != "device":
				return {"path": "res://GJGamejam素材/2.5D物品/玩偶.png", "pixel_size": 0.0062}
			var character_role := str(item.get("character_role", item.get("owner", "thief")))
			return {
				"path": "res://GJGamejam素材/人物/怪物.png" if character_role == "monster" else "res://GJGamejam素材/人物/主角.png",
				"pixel_size": 0.00262 if character_role == "monster" else 0.00270,
			}
		"alarm":
			return {"path": "res://GJGamejam素材/2.5D物品/s2_alarm_clean.png", "pixel_size": 0.0062}
		"phonograph":
			return {"path": "res://GJGamejam素材/2.5D物品/s2_gramo_clean.png", "pixel_size": 0.0105}
		"teleporter":
			return {"path": "res://GJGamejam素材/2.5D物品/红宝石.png", "pixel_size": 0.01006, "color": Color("#6ed5ff")}
		"adrenaline":
			return {"path": "res://GJGamejam素材/2.5D物品/s2_adren_clean.png", "pixel_size": 0.0062}
		"spring_glove":
			return {"path": "res://GJGamejam素材/2.5D物品/gm2_glove_clean.png", "pixel_size": 0.0062}
		"detector":
			return {"path": "res://GJGamejam素材/2.5D物品/gm2_detector_clean.png", "pixel_size": 0.0062}
		_:
			return {"path": "res://GJGamejam素材/2.5D物品/玩偶.png", "pixel_size": 0.0062}


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
	if (
		not initialized
		or not is_instance_valid(monster_node)
		or not is_instance_valid(thief_node)
		or not is_instance_valid(monster_camera)
		or not is_instance_valid(thief_camera)
		or not is_instance_valid(attack_cone)
		or monster.is_empty()
		or thief.is_empty()
	):
		return
	if not monster_node or not thief_node or not monster_camera or not thief_camera:
		return
	_sync_actor(monster_node, monster, time, false)
	_sync_actor(thief_node, thief, time, true)
	var actors_share_room: bool = monster["room"] == thief["room"]
	_set_actor_visual_layers(monster_node, LAYER_MONSTER | (LAYER_SHARED_ACTORS if actors_share_room else 0))
	_set_actor_visual_layers(thief_node, LAYER_THIEF | (LAYER_SHARED_ACTORS if actors_share_room else 0))
	_follow_camera(monster_camera, monster, "monster")
	_follow_camera(thief_camera, thief, "thief")
	# Trigger furniture bounce BEFORE the room loop so furniture
	# appears at drop height on the very first frame of a new room.
	var m_rk := _room_key(monster["room"])
	var t_rk := _room_key(thief["room"])
	if m_rk != _room_key(active_monster_room):
		furniture_bounces[m_rk] = time
	if t_rk != _room_key(active_thief_room):
		furniture_bounces[t_rk] = time
	for room in rooms:
		var coord: Vector2i = room["coord"]
		for furniture in room["furniture"]:
			var furniture_id: String = furniture["id"]
			if not furniture_nodes.has(furniture_id):
				_create_furniture_node(coord, furniture)
			var furniture_node: Node3D = furniture_nodes[furniture_id]
			furniture_node.position = world_position(coord, furniture["pos"])
			furniture_node.position.y += _furniture_bounce_offset(_room_key(coord), time)
			var furn_brightness := _light_brightness_at(_room_key(coord), furniture_node.position)
			var furn_sprite: Sprite3D = furniture_node.get_node_or_null("PaperSprite")
			if furn_sprite:
				furn_sprite.modulate = Color(furn_brightness, furn_brightness, furn_brightness)
			var furn_outline: Sprite3D = furniture_node.get_node_or_null("OutlineSprite")
			if furn_outline:
				furn_outline.modulate = Color.BLACK  # Outline stays black
			var content_value := _furniture_content_value(furniture)
			var shake_degrees := 0.0
			if (
				not bool(furniture.get("destroyed", false))
				and bool(furniture.get("detector_active", false))
				and content_value > 0
			):
				shake_degrees = minf(1.2 + float(content_value) * 1.25, 11.0)
			if time - float(furniture.get("last_hit_time", -10.0)) < 0.48:
				shake_degrees = maxf(shake_degrees, 13.0)
			var phase := float(abs(str(furniture_id).hash()) % 628) / 100.0
			furniture_node.rotation.y = -deg_to_rad(float(furniture["rotation"])) + deg_to_rad(sin(time * 5.2 + phase) * shake_degrees)
			furniture_node.scale = Vector3(1.0, 0.5, 1.0) if bool(furniture.get("destroyed", false)) else Vector3.ONE
			var furniture_collision: CollisionShape3D = furniture_node.get_node_or_null("CollisionBody/CollisionShape3D")
			if furniture_collision:
				furniture_collision.disabled = bool(furniture.get("destroyed", false))
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
			var item_kind := str(item.get("kind", ""))
			var visual_position := world_position(coord, item["pos"])
			if (
				item_kind == "tool"
				or (
					item_kind == "device"
					and str(item.get("device_type", "")) == "trap"
					and str(item.get("state", "")) == "recoverable"
				)
			):
				visual_position += _pickup_item_shake_offset(item_id, time)
			item_node.position = visual_position
			item_node.visible = (
				not bool(item["collected"])
				and (item_kind in ["tool", "device"] or not _item_hidden(room, item))
			)
			var item_sprite: Sprite3D = item_node.get_node_or_null("ItemSprite")
			if (
				item_sprite
				and item_kind == "device"
				and str(item.get("device_type", "")) == "trap"
			):
				var trap_path := (
					"res://GJGamejam素材/2.5D物品/r3_trapclosed_clean.png"
					if str(item.get("state", "")) == "active"
					else "res://GJGamejam素材/2.5D物品/r3_trapopen_clean.png"
				)
				var trap_texture: Texture2D = load(trap_path)
				if item_sprite.texture != trap_texture:
					item_sprite.texture = trap_texture
		_sync_room_marks(room)
	_sync_afterimages(afterimages, monster["room"], thief["room"])
	_sync_attack(monster, attack_active)
	_sync_room_layers(monster["room"], thief["room"], time)
	_sync_full_walls(monster["room"], camera_yaw_degrees["monster"], "monster")
	_sync_full_walls(thief["room"], camera_yaw_degrees["thief"], "thief")
	_update_wall_fades(time)
	_update_furniture_bounces(time)
	_sync_ghost_visibility(monster, thief)


func _pickup_item_shake_offset(item_id: String, time: float) -> Vector3:
	var phase := float(abs(item_id.hash()) % 1000) / 1000.0 * ITEM_SHAKE_CYCLE
	var cycle_time := fmod(time + phase, ITEM_SHAKE_CYCLE)
	if cycle_time >= ITEM_SHAKE_BURST:
		return Vector3.ZERO
	var fade := sin(cycle_time / ITEM_SHAKE_BURST * PI)
	var horizontal := sin((time + phase) * ITEM_SHAKE_FREQUENCY) * ITEM_SHAKE_DISTANCE * fade
	var depth := cos((time + phase) * ITEM_SHAKE_FREQUENCY * 0.83) * ITEM_SHAKE_DISTANCE * 0.35 * fade
	return Vector3(horizontal, 0.0, depth)


func _furniture_content_value(furniture: Dictionary) -> int:
	for content in furniture.get("contents", []):
		var kind := str(content.get("kind", ""))
		if kind == "treasure":
			return int(content.get("value", 0))
		if kind == "alarm":
			return int(content.get("signal_value", 3))
	return 0


func _sync_actor(node: Node3D, actor: Dictionary, time: float, is_thief: bool) -> void:
	if not node or not is_instance_valid(node):
		return
	var visual_pos: Vector2 = actor["pos"] + actor.get("impact_visual_offset", Vector2.ZERO)
	node.position = world_position(actor["room"], visual_pos)
	var pivot: Node3D = node.get_node_or_null("SwayPivot")
	if not pivot:
		return
	var sprite: Sprite3D = pivot.get_node_or_null("PaperSprite")
	if not sprite:
		return
	var dir: String = actor["dir"]
	sprite.flip_h = dir == "right"
	var sprite_foot_offset := float(sprite.get_meta("foot_offset_x", 0.0))
	sprite.position.x = -sprite_foot_offset if sprite.flip_h else sprite_foot_offset
	var brightness := _light_brightness_at(_room_key(actor["room"]), node.position)
	sprite.modulate = Color(brightness, brightness, brightness)
	var phase_offset := 1.6 if is_thief else 0.0
	var moving: bool = actor.get("moving", false)
	if moving:
		# Keep the foot planted at the actor origin. A small upward-only step
		# gives motion without driving the cutout below the floor or away from
		# its shadow.
		pivot.position = Vector3(0, absf(sin(time * 14.0 + phase_offset)) * 0.22, 0)
		pivot.rotation.z = 0.0
	else:
		# Rotate gently around the foot anchor instead of translating the whole
		# image away from the ground shadow.
		pivot.position = Vector3.ZERO
		pivot.rotation.z = sin(time * 2.5 + phase_offset) * 0.045


func _set_actor_visual_layers(node: Node, layers: int) -> void:
	if not node or not is_instance_valid(node):
		return
	for child in node.get_children():
		if child is VisualInstance3D:
			(child as VisualInstance3D).layers = layers
		_set_actor_visual_layers(child, layers)


func _follow_camera(camera: Camera3D, actor: Dictionary, role: String) -> void:
	if not camera or not is_instance_valid(camera):
		return
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
	if not attack_cone or not is_instance_valid(attack_cone):
		return
	attack_cone.visible = active
	if not active:
		return
	attack_cone.position = world_position(monster["room"], monster["pos"], 0.055)
	match monster["dir"]:
		"up": attack_cone.rotation.y = 0.0
		"right": attack_cone.rotation.y = -PI / 2.0
		"down": attack_cone.rotation.y = PI
		"left": attack_cone.rotation.y = PI / 2.0


func _sync_afterimages(images: Array, monster_room: Vector2i, thief_room: Vector2i) -> void:
	var live: Dictionary = {}
	var actors_share_room := monster_room == thief_room
	for image in images:
		var key := "%.4f" % float(image["created"])
		live[key] = true
		if not afterimage_nodes.has(key):
			var node := Node3D.new()
			var sprite := Sprite3D.new()
			sprite.texture = load("res://GJGamejam素材/人物/主角.png")
			sprite.pixel_size = 0.00270
			sprite.position.y = 0.86
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
			sprite.modulate = Color(1.0, 0.13, 0.1, 0.58)
			sprite.layers = LAYER_AFTERIMAGE
			node.add_child(sprite)
			world_root.add_child(node)
			afterimage_nodes[key] = node
		var image_node: Node3D = afterimage_nodes[key]
		image_node.position = world_position(image["room"], image["pos"])
		image_node.visible = actors_share_room and image["room"] == monster_room
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


func _sync_room_layers(monster_room: Vector2i, thief_room: Vector2i, game_time: float) -> void:
	if monster_room == active_monster_room and thief_room == active_thief_room:
		return
	# Enable the destination rooms first. The previous rooms remain visible until
	# every new layer has reached the renderer, preventing a transient black frame.
	_apply_room_layer(monster_room, LAYER_MONSTER_WORLD)
	_apply_room_layer(thief_room, LAYER_THIEF_WORLD)
	# Trigger wall fade animations on room change (use OLD active rooms)
	var m_key := _room_key(monster_room)
	var t_key := _room_key(thief_room)
	var old_m := _room_key(active_monster_room)
	var old_t := _room_key(active_thief_room)
	active_monster_room = monster_room
	active_thief_room = thief_room
	if m_key != old_m:
		wall_fades["monster_" + m_key] = {"phase": "appear", "start_time": game_time}
		furniture_bounces[m_key] = game_time
	if t_key != old_t:
		wall_fades["thief_" + t_key] = {"phase": "appear", "start_time": game_time}
		furniture_bounces[t_key] = game_time
	# Per-player full wall layer assignment
	if monster_full_walls:
		for key in monster_full_walls.keys():
			for side_node in monster_full_walls[key].values():
				if is_instance_valid(side_node):
					side_node.layers = LAYER_MONSTER_WORLD if key == m_key else 0
	if thief_full_walls:
		for key in thief_full_walls.keys():
			for side_node in thief_full_walls[key].values():
				if is_instance_valid(side_node):
					side_node.layers = LAYER_THIEF_WORLD if key == t_key else 0
	for key in room_visuals.keys():
		var desired_layers := _layers_for_room_key(key)
		for visual in room_visuals[key]:
			if is_instance_valid(visual):
				var instance := visual as VisualInstance3D
				if instance.layers != desired_layers:
					instance.layers = desired_layers
	# Toggle ghost visibility: show ghosts for rooms at Manhattan distance 1..2 (九宫格)
	for key in monster_ghost_visuals.keys():
		var coord := Vector2i(int(key.split(":")[0]), int(key.split(":")[1]))
		var dist := _manhattan_distance(coord, monster_room)
		var show := dist >= 1 and dist <= 2
		for visual in monster_ghost_visuals[key]:
			if is_instance_valid(visual):
				visual.layers = LAYER_MONSTER_GHOST if show else 0
	for key in thief_ghost_visuals.keys():
		var coord := Vector2i(int(key.split(":")[0]), int(key.split(":")[1]))
		var dist := _manhattan_distance(coord, thief_room)
		var show := dist >= 1 and dist <= 2
		for visual in thief_ghost_visuals[key]:
			if is_instance_valid(visual):
				visual.layers = LAYER_THIEF_GHOST if show else 0


func _manhattan_distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _light_brightness_at(room_key: String, world_pos: Vector3) -> float:
	if not room_lights:
		return LIGHT_MIN_BRIGHT
	var lights: Array = room_lights.get(room_key, [])
	if lights.is_empty():
		return LIGHT_MIN_BRIGHT
	var nearest_sq := INF
	for light in lights:
		var light_pos: Vector3 = light
		var dx := world_pos.x - light_pos.x
		var dz := world_pos.z - light_pos.z
		var dist_sq := dx * dx + dz * dz
		if dist_sq < nearest_sq:
			nearest_sq = dist_sq
	var dist := sqrt(nearest_sq)
	var t := clampf(dist / LIGHT_MAX_DIST, 0.0, 1.0)
	t = t * t  # Quadratic falloff for softer transition
	return lerpf(LIGHT_MAX_BRIGHT, LIGHT_MIN_BRIGHT, t)


func _update_wall_fades(game_time: float) -> void:
	var to_erase: Array[String] = []
	for fade_key in wall_fades.keys():
		var fade: Dictionary = wall_fades[fade_key]
		var elapsed := game_time - float(fade["start_time"])
		var progress := clampf(elapsed / WALL_FADE_DURATION, 0.0, 1.0)
		var eased := progress * progress * (3.0 - 2.0 * progress)  # smoothstep
		var alpha: float = eased if fade["phase"] == "appear" else (1.0 - eased)
		# Parse "monster_0:5" or "thief_3:2" → role + room_key
		var parts: PackedStringArray = fade_key.split("_", true, 1)
		var role: String = parts[0]
		var room_key: String = parts[1]
		var fw_dict := monster_full_walls if role == "monster" else thief_full_walls
		if fw_dict.has(room_key):
			for side_node in fw_dict[room_key].values():
				if is_instance_valid(side_node):
					var wmat: ShaderMaterial = side_node.material_override as ShaderMaterial
					if wmat:
						wmat.set_shader_parameter("fade_alpha", alpha)
		if progress >= 1.0:
			to_erase.append(fade_key)
	for key in to_erase:
		wall_fades.erase(key)
		


func _update_furniture_bounces(game_time: float) -> void:
	var to_erase: Array[String] = []
	for room_key in furniture_bounces.keys():
		var start_time: float = furniture_bounces[room_key]
		var elapsed := game_time - start_time
		if elapsed >= FURNITURE_BOUNCE_DURATION:
			to_erase.append(room_key)
	for key in to_erase:
		furniture_bounces.erase(key)


func _furniture_bounce_offset(room_key: String, game_time: float) -> float:
	var start_time: float = furniture_bounces.get(room_key, -999.0)
	if start_time < 0.0:
		return 0.0
	var elapsed := game_time - start_time
	if elapsed >= FURNITURE_BOUNCE_DURATION or elapsed < 0.0:
		return 0.0
	# Phase 1 — drop from height
	if elapsed < FURNITURE_FALL_DURATION:
		var t := elapsed / FURNITURE_FALL_DURATION
		return FURNITURE_DROP_HEIGHT * (1.0 - t * t)  # quadratic ease-in (gravity)
	# Phase 2 — damped bounce after landing
	var bounce_t := elapsed - FURNITURE_FALL_DURATION
	var bounce_duration := FURNITURE_BOUNCE_DURATION - FURNITURE_FALL_DURATION
	return 0.25 * exp(-bounce_t * 7.0) * abs(sin(bounce_t * TAU * 4.0))


func _sync_ghost_visibility(monster: Dictionary, thief: Dictionary) -> void:
	if not monster_ghost_shader or not thief_ghost_shader:
		return
	# Update shader uniforms with exact player world positions
	monster_ghost_shader.set_shader_parameter("player_position",
		world_position(monster["room"], monster["pos"], 0.38))
	thief_ghost_shader.set_shader_parameter("player_position",
		world_position(thief["room"], thief["pos"], 0.38))


func _layers_for_room_key(key: String) -> int:
	var layers := 0
	# Active room gets its layer
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
	if not initialized:
		return null
	if role == "monster":
		return monster_viewport.get_texture() if is_instance_valid(monster_viewport) else null
	return thief_viewport.get_texture() if is_instance_valid(thief_viewport) else null


func project_normalized(role: String, room: Vector2i, pos: Vector2, y := 0.25) -> Vector2:
	var camera := monster_camera if role == "monster" else thief_camera
	var viewport := monster_viewport if role == "monster" else thief_viewport
	if not initialized or not is_instance_valid(camera) or not is_instance_valid(viewport):
		return Vector2(0.5, 0.5)
	var pixel: Vector2 = camera.unproject_position(world_position(room, pos, y))
	return pixel / Vector2(viewport.size)
