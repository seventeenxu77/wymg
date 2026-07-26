@tool
class_name GameAudioSystem
extends "res://scripts/systems/room_system.gd"

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


func _load_sound_streams() -> void:
	sound_streams.clear()
	for sound_name in SOUND_PATHS:
		var path := str(SOUND_PATHS[sound_name])
		if not ResourceLoader.exists(path):
			continue
		var stream := ResourceLoader.load(path) as AudioStream
		if stream:
			sound_streams[sound_name] = stream


func _setup_walk_players() -> void:
	walk_players.clear()
	if not sound_streams.has("walk"):
		return
	for role in ["monster", "thief"]:
		var player := AudioStreamPlayer.new()
		var stream := sound_streams["walk"].duplicate() as AudioStream
		if stream is AudioStreamMP3:
			stream.loop = true
		player.stream = stream
		player.volume_db = -18.0
		add_child(player)
		walk_players[role] = player


func _update_walk_audio() -> void:
	for role in ["monster", "thief"]:
		if not walk_players.has(role):
			continue
		var player := walk_players[role] as AudioStreamPlayer
		var actor := _get_actor(role)
		var should_play := phase in ["hide", "hunt"] and bool(actor.get("moving", false))
		if should_play and not player.playing:
			player.play()
		elif not should_play and player.playing:
			player.stop()


func _play_sound(sound_name: String, volume_db := -10.0, throttle := 0.0) -> void:
	if not is_inside_tree() or not sound_streams.has(sound_name):
		return
	var now := Time.get_ticks_msec() / 1000.0
	if throttle > 0.0 and now - float(sound_last_played.get(sound_name, -100.0)) < throttle:
		return
	sound_last_played[sound_name] = now
	var existing: AudioStreamPlayer = sound_players.get(sound_name) as AudioStreamPlayer
	if is_instance_valid(existing):
		existing.stop()
		existing.queue_free()
	var player := AudioStreamPlayer.new()
	player.stream = sound_streams[sound_name]
	player.volume_db = volume_db
	add_child(player)
	sound_players[sound_name] = player
	player.finished.connect(func():
		if sound_players.get(sound_name) == player:
			sound_players.erase(sound_name)
		player.queue_free()
	)
	player.play()


func _reveal_thief(actor_override: Dictionary = {}) -> void:
	if phase != "hunt":
		return
	var actor := actor_override if not actor_override.is_empty() else thief
	actor["hidden_from_monster"] = false
	actor["revealed_until"] = maxf(
		float(actor.get("revealed_until", 0.0)),
		elapsed + THIEF_REVEAL_SECONDS,
	)
	if elapsed - last_afterimage_at < 0.5:
		return
	last_afterimage_at = elapsed
	afterimages.append({
		"room": actor["room"],
		"pos": actor["pos"],
		"created": elapsed,
		"expires": elapsed + 1.1,
	})
