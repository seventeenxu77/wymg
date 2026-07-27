extends SceneTree


func _initialize() -> void:
	var game_script: Script = load("res://scripts/main.gd")
	var game: Node = game_script.new()
	game.phase = "hunt"
	game.elapsed = 12.0
	game.monster = game._make_actor(Vector2i.ZERO, Vector2(1.0, 2.5), "right")
	game.thief = game._make_actor(Vector2i.ZERO, Vector2(2.7, 2.5), "left")
	game.status_effects = {
		"monster": game._fresh_status_effects(),
		"thief": game._fresh_status_effects(),
	}
	game.trapped_by = {"monster": "", "thief": ""}
	game.furniture_hit_actions = {"monster": {}, "thief": {}}
	game.attack_until = 0.0

	game._attack()
	assert(is_equal_approx(
		game.attack_until,
		game.elapsed + game.MONSTER_ATTACK_COOLDOWN
	))
	assert(is_equal_approx(
		float(game.monster["attack_started_at"]),
		game.elapsed
	))
	assert(int(game.thief["hp"]) == 1)
	assert(is_equal_approx(
		float(game.status_effects["thief"]["stunned_until"]),
		game.elapsed + game.MONSTER_ATTACK_HIT_STUN_SECONDS
	))
	game.thief["hidden_from_monster"] = true
	game._update_thief_stealth()
	assert(not bool(game.thief["hidden_from_monster"]))
	var hp_during_cooldown := int(game.thief["hp"])
	game._attack()
	assert(int(game.thief["hp"]) == hp_during_cooldown)
	assert(is_equal_approx(game.AFTERIMAGE_LINGER_SECONDS, 1.375))
	assert(game.SOUND_PATHS.has("scream"))
	assert(game.SOUND_PATHS.has("laugh"))

	game.noises.clear()
	var left_voice := InputEventKey.new()
	left_voice.pressed = true
	left_voice.keycode = KEY_B
	left_voice.physical_keycode = KEY_B
	game._input(left_voice)
	assert(game.noises.size() == 1)
	assert(str(game.noises[0]["source"]) == "monster")
	assert(str(game.noises[0]["label"]) == "怪物笑声")
	assert(is_equal_approx(float(game.noises[0]["duration"]), game.VOICE_NOISE_SECONDS))
	assert(str(game.noises[0]["follow_role"]) == "monster")
	game._input(left_voice)
	assert(game.noises.size() == 1)

	var right_voice := InputEventKey.new()
	right_voice.pressed = true
	right_voice.keycode = KEY_KP_MULTIPLY
	right_voice.physical_keycode = KEY_KP_MULTIPLY
	game._input(right_voice)
	assert(game.noises.size() == 2)
	assert(str(game.noises[1]["source"]) == "thief")
	assert(str(game.noises[1]["label"]) == "盗贼尖叫")
	assert(str(game.noises[1]["follow_role"]) == "thief")

	var renderer := World25D.new()
	renderer.world_root = Node3D.new()
	renderer.add_child(renderer.world_root)
	var thief_actor := renderer._create_actor("thief", World25D.LAYER_THIEF)
	var trapped_state: Dictionary = game._make_actor(Vector2i.ZERO, Vector2(2.5, 2.5), "left")
	trapped_state["trapped"] = true
	trapped_state["trapped_started_at"] = 20.0
	trapped_state["trap_prompt"] = "←"
	renderer._sync_actor(thief_actor, trapped_state, 20.12, true)
	var trap_prompt := thief_actor.get_node("TrapPrompt") as Label3D
	var trap_pivot := thief_actor.get_node("SwayPivot") as Node3D
	var thief_sprite := thief_actor.get_node("SwayPivot/PaperSprite") as Sprite3D
	assert(trap_prompt.visible)
	assert(trap_prompt.text == "←")
	assert(absf(trap_pivot.rotation.z) > 0.05)
	assert(thief_sprite.modulate.r > thief_sprite.modulate.g)

	var sweep := renderer._create_attack_cone()
	renderer.attack_cone = sweep
	var sweep_vertices: PackedVector3Array = (
		(sweep.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	)
	assert(sweep.name == "AttackSweep")
	assert(sweep_vertices.size() > 3)
	var attack_state: Dictionary = game._make_actor(Vector2i.ZERO, Vector2(2.5, 2.5), "up")
	attack_state["attack_started_at"] = 30.0
	renderer._sync_attack(attack_state, true, 30.05)
	var early_rotation := sweep.rotation.y
	renderer._sync_attack(attack_state, true, 30.45)
	assert(not is_equal_approx(sweep.rotation.y, early_rotation))

	print("Combat, voice noise, cooldown, afterimage, and trap feedback regression test passed.")
	game.free()
	renderer.free()
	quit(0)
