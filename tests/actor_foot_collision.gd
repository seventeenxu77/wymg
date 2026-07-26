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

	var renderer := World25D.new()
	renderer.world_root = Node3D.new()
	renderer.add_child(renderer.world_root)
	var monster_actor := renderer._create_actor("monster", World25D.LAYER_MONSTER)
	var monster_sprite := monster_actor.get_node("SwayPivot/PaperSprite") as Sprite3D
	var monster_outline := monster_actor.get_node("SwayPivot/OutlineSprite") as Sprite3D
	assert(monster_sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y)
	assert(monster_sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED)
	assert(monster_outline.alpha_cut == SpriteBase3D.ALPHA_CUT_DISABLED)
	assert(monster_outline.render_priority < monster_sprite.render_priority)
	assert(is_equal_approx(
		monster_sprite.position.y,
		monster_sprite.texture.get_height() * monster_sprite.pixel_size * 0.5
	))

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

	print("Actor foot anchor and continuous ground collision regression test passed.")
	game.free()
	renderer.free()
	quit(0)
