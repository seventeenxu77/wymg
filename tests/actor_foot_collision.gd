extends SceneTree


func _initialize() -> void:
	var game_script: Script = load("res://scripts/main.gd")
	var game: Node = game_script.new()

	var solid_room := {"doors": []}
	assert(game._position_clears_room_walls(solid_room, Vector2(2.5, 2.5)))
	assert(not game._position_clears_room_walls(
		solid_room,
		Vector2(game.ACTOR_COLLISION_RADIUS - 0.01, 2.5)
	))

	var door_room := {"doors": ["left"]}
	assert(game._position_clears_room_walls(
		door_room,
		Vector2(game.ACTOR_COLLISION_RADIUS - 0.01, 2.5)
	))
	assert(not game._position_clears_room_walls(
		door_room,
		Vector2(game.ACTOR_COLLISION_RADIUS - 0.01, 1.25)
	))

	var bed := {
		"kind": "床",
		"pos": Vector2(2.5, 2.5),
		"rotation": 0.0,
	}
	assert(game._actor_overlaps_furniture(Vector2(2.5, 2.5), bed))
	assert(game._actor_overlaps_furniture(Vector2(3.0, 2.5), bed))
	assert(not game._actor_overlaps_furniture(Vector2(3.5, 2.5), bed))
	bed["rotation"] = 90.0
	assert(not game._actor_overlaps_furniture(Vector2(3.0, 2.5), bed))
	assert(game._actor_overlaps_furniture(Vector2(2.5, 3.0), bed))
	bed["rotation"] = 0.0
	assert(game._actor_collision_radius("monster") > game._actor_collision_radius("thief"))
	assert(game._actor_overlaps_furniture(Vector2(3.2, 2.5), bed, "monster"))
	assert(not game._actor_overlaps_furniture(Vector2(3.2, 2.5), bed, "thief"))
	assert(game._position_clears_room_walls(door_room, Vector2(0.2, 2.82), "thief"))
	assert(not game._position_clears_room_walls(door_room, Vector2(0.2, 2.82), "monster"))

	var renderer := World25D.new()
	renderer.world_root = Node3D.new()
	renderer.add_child(renderer.world_root)
	renderer.level_root = Node3D.new()
	renderer.world_root.add_child(renderer.level_root)
	var monster_actor := renderer._create_actor("monster", World25D.LAYER_MONSTER)
	var monster_sprite := monster_actor.get_node("SwayPivot/PaperSprite") as Sprite3D
	assert(monster_actor is CharacterBody3D)
	assert(not monster_actor.has_node("SwayPivot/OutlineSprite"))
	assert(monster_sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y)
	assert(monster_sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
	var actor_collision := monster_actor.get_node("CollisionShape3D") as CollisionShape3D
	var actor_capsule := actor_collision.shape as CapsuleShape3D
	assert(is_equal_approx(
		actor_capsule.radius,
		monster_sprite.texture.get_width() * monster_sprite.pixel_size * 0.5
	))
	assert(is_equal_approx(
		actor_capsule.radius / World25D.CELL_SIZE,
		game._actor_collision_radius("monster")
	))
	assert(is_equal_approx(
		monster_sprite.position.y,
		monster_sprite.texture.get_height() * monster_sprite.pixel_size * 0.5
	))
	var furniture_data := {
		"id": "collision-crate",
		"kind": "木箱",
		"pos": Vector2(2.5, 2.5),
		"rotation": 0.0,
	}
	renderer._create_furniture_node(Vector2i.ZERO, furniture_data)
	var furniture_node: Node3D = renderer.furniture_nodes["collision-crate"]
	var furniture_sprite := furniture_node.get_node("PaperSprite") as Sprite3D
	var furniture_body := furniture_node.get_node("CollisionBody") as StaticBody3D
	var furniture_collision := furniture_body.get_node("CollisionShape3D") as CollisionShape3D
	var furniture_box := furniture_collision.shape as BoxShape3D
	assert(furniture_sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS)
	assert(furniture_box.size == renderer._furniture_info("木箱")["size"])

	renderer._sync_actor(monster_actor, {
		"room": Vector2i.ZERO,
		"pos": Vector2(2.5, 2.5),
		"dir": "right",
		"moving": false,
	}, 0.5, false)
	var pivot := monster_actor.get_node("SwayPivot") as Node3D
	assert(pivot.position.is_zero_approx())
	renderer._sync_actor(monster_actor, {
		"room": Vector2i.ZERO,
		"pos": Vector2(2.5, 2.5),
		"dir": "right",
		"moving": true,
	}, PI / 28.0, false)
	assert(is_equal_approx(pivot.position.y, 0.22))
	renderer._sync_actor(monster_actor, {
		"room": Vector2i.ZERO,
		"pos": Vector2(2.5, 2.5),
		"dir": "right",
		"moving": false,
		"hit_reaction_started_at": 1.0,
		"hit_reaction_direction": Vector2.RIGHT,
	}, 1.0 + World25D.HIT_REACTION_SECONDS * 0.5, true)
	assert(absf(pivot.rotation.z) > 0.35)
	assert(pivot.position.x > 0.15)

	print("Actor foot anchor and continuous ground collision regression test passed.")
	game.free()
	renderer.free()
	quit(0)
