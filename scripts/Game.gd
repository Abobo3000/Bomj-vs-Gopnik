extends Node3D
## One-player cinematic 2.5D arcade fighter: combat and bots are deterministic
## enough to test, while hit VFX, sound, supers and scenery remain original.
const FighterScene = preload("res://scripts/Fighter.gd")
const ArenaScene = preload("res://scripts/Arena.gd")
const HUDScene = preload("res://scripts/HUD.gd")

var player
var cpu
var ui
var camera: Camera3D
var game_active := false
var fighting := false
var current_round := 1
var wins_player := 0
var wins_cpu := 0
var round_seconds := 90.0
var round_break := 0.0
var notice_seconds := 0.0
var opponent_decision := 0.0
var opponent_guard := 0.0
var hit_flash := 0.0
var camera_shake := 0.0
var moving_fx: Array = []
var impact_fx: Array = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	var stage := ArenaScene.new()
	stage.name = "ProvincialCourtyard1997"
	add_child(stage)
	camera = Camera3D.new()
	camera.name = "FightCamera"
	camera.current = true
	camera.fov = 40.0
	camera.near = 0.15
	camera.far = 105.0
	add_child(camera)
	camera.position = Vector3(0, 3.82, 12.2)
	camera.look_at(Vector3(0, 1.62, -1.2), Vector3.UP)
	_spawn_fighters(0)
	ui = HUDScene.new()
	add_child(ui)
	ui.setup(self)

func _spawn_fighters(which: int) -> void:
	if is_instance_valid(player):
		player.queue_free()
	if is_instance_valid(cpu):
		cpu.queue_free()
	player = FighterScene.new()
	cpu = FighterScene.new()
	add_child(player)
	add_child(cpu)
	player.setup(which, 1)
	cpu.setup(1 - which, -1)
	player.position = Vector3(-3.0, 0, 0)
	cpu.position = Vector3(3.0, 0, 0)
	player.move_strike.connect(_on_strike)
	cpu.move_strike.connect(_on_strike)
	player.died.connect(_on_fighter_down)
	cpu.died.connect(_on_fighter_down)

func start_match(choice: int) -> void:
	_clear_effects()
	_spawn_fighters(choice)
	current_round = 1
	wins_player = 0
	wins_cpu = 0
	round_seconds = 90.0
	round_break = 0.0
	opponent_decision = 0.8
	opponent_guard = 0.0
	notice_seconds = 1.0
	game_active = true
	fighting = true
	ui.hide_menu()
	ui.set_match_visible(true)
	ui.set_note("БОЙ!")
	_update_hud()

func player_won() -> bool:
	return wins_player >= 2

func player_action(action_name: String) -> void:
	if game_active and fighting and player.try_action(action_name):
		_play_sound("swing")

func _unhandled_input(event: InputEvent) -> void:
	if not game_active or not fighting:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_J: player_action("punch")
			KEY_K: player_action("kick")
			KEY_U: player_action("special1")
			KEY_I: player_action("special2")
			KEY_ESCAPE: _cancel_match()

func _cancel_match() -> void:
	game_active = false
	fighting = false
	ui.set_match_visible(false)
	ui.show_menu("start")

func _physics_process(delta: float) -> void:
	_tick_projectiles(delta)
	_tick_impact_particles(delta)
	hit_flash = move_toward(hit_flash, 0.0, delta * 2.1)
	camera_shake = move_toward(camera_shake, 0.0, delta * 5.0)
	if ui != null:
		ui.set_flash(hit_flash)
	camera.position = Vector3(rng.randf_range(-0.08, 0.08) * camera_shake, 3.82 + rng.randf_range(-0.06, 0.06) * camera_shake, 12.2)
	if not game_active:
		return
	player.tick(delta)
	cpu.tick(delta)
	if round_break > 0.0:
		round_break -= delta
		if round_break <= 0.0:
			_restart_round()
		_update_hud()
		return
	if not fighting:
		return
	round_seconds = maxf(0.0, round_seconds - delta)
	if notice_seconds > 0.0:
		notice_seconds -= delta
		if notice_seconds <= 0.0:
			ui.set_note("")
	var axis := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT) or ui.touch["left"]:
		axis -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT) or ui.touch["right"]:
		axis += 1.0
	player.set_guard(Input.is_key_pressed(KEY_L) or ui.touch["guard"])
	player.walk(axis, delta)
	_tick_cpu(delta)
	_separate_fighters()
	if round_seconds <= 0.0:
		var winner := 0 if player.hp > cpu.hp else (1 if cpu.hp > player.hp else -1)
		_end_round(winner)
	_update_hud()

func _tick_cpu(delta: float) -> void:
	opponent_guard = maxf(0.0, opponent_guard - delta)
	cpu.set_guard(opponent_guard > 0.0)
	if cpu.defeated:
		return
	var distance := absf(cpu.position.x - player.position.x)
	if opponent_guard <= 0.0 and cpu.action == "":
		if distance > 1.72:
			cpu.walk(signf(player.position.x - cpu.position.x), delta)
		elif distance < 1.10 and rng.randf() < 0.09:
			cpu.walk(-signf(player.position.x - cpu.position.x), delta)
	opponent_decision -= delta
	if opponent_decision > 0.0 or cpu.action != "":
		return
	opponent_decision = rng.randf_range(0.49, 0.88)
	if player.action != "" and distance < 2.25 and rng.randf() < 0.33:
		opponent_guard = rng.randf_range(0.24, 0.60)
		cpu.set_guard(true)
		return
	if cpu.energy >= 65.0 and rng.randf() < 0.32 and distance < 5.6:
		cpu.try_action("special2")
	elif cpu.energy >= 40.0 and rng.randf() < 0.38 and distance < 4.0:
		cpu.try_action("special1")
	elif distance <= 2.1:
		cpu.try_action("kick" if rng.randf() < 0.35 else "punch")
	else:
		opponent_decision = 0.2

func _separate_fighters() -> void:
	var gap: float = cpu.position.x - player.position.x
	if gap < 1.05:
		var adjustment := (1.05 - gap) * 0.5
		player.position.x = clampf(player.position.x - adjustment, -5.4, 4.25)
		cpu.position.x = clampf(cpu.position.x + adjustment, -4.25, 5.4)

func _on_strike(who, move_name: String) -> void:
	if not fighting:
		return
	var target = cpu if who == player else player
	match move_name:
		"punch":
			_melee(who, target, 1.85, 9.0, 2.25)
		"kick":
			_melee(who, target, 2.25, 15.0, 3.6)
		"special1":
			if who.kind == 0:
				# Fanfurik: a stylized theatrical fire-breath, not a real technique.
				_play_sound("flame")
				for j in range(11):
					_spawn_vfx_ball(who.position + Vector3(who.facing * (0.7 + j * 0.18), 2.08 + rng.randf_range(-0.3, 0.35), 0.17), 0.11 + rng.randf() * 0.16, Color("#ff8539") if j % 2 else Color("#ffd55c"), Vector3(who.facing * rng.randf_range(1.5, 3.4), rng.randf_range(-0.2, 1.0), 0), 0.56)
				_melee(who, target, 3.85, 24.0, 4.2)
			else:
				# A volley of sunflower husks; one proper damage hit, decorative sparks.
				for j in range(7):
					_spawn_vfx_ball(who.position + Vector3(who.facing * 0.68, 2.30, 0.10), 0.044, Color("#e1c08a"), Vector3(who.facing * rng.randf_range(8.0, 11.0), rng.randf_range(-0.75, 0.65), 0), 0.4)
				_spawn_projectile(who, "husk", 13.0, 16.0)
		"special2":
			_spawn_projectile(who, "cat" if who.kind == 0 else "phone", 7.6 if who.kind == 0 else 10.7, 30.0 if who.kind == 0 else 28.0)

func _melee(attacker, target, distance: float, damage: float, knock: float) -> void:
	var dx: float = target.position.x - attacker.position.x
	if dx * float(attacker.facing) <= 0.0 or absf(dx) > distance:
		_play_sound("swing")
		return
	var dealt: float = target.take_hit(damage, attacker.facing, knock)
	if dealt <= 0.0:
		return
	if attacker.action == "punch" or attacker.action == "kick":
		attacker.gain_energy(10.0)
	else:
		attacker.gain_energy(3.0)
	_hit_feedback(target.position + Vector3(0, 1.65, 0))
	_play_sound("hit")

func _on_fighter_down(who) -> void:
	if not fighting:
		return
	_end_round(1 if who == player else 0)

func _end_round(winner: int) -> void:
	if not fighting:
		return
	fighting = false
	if winner == 0:
		wins_player += 1
		ui.set_note("РАУНД ТВОЙ!")
	elif winner == 1:
		wins_cpu += 1
		ui.set_note("РАУНД ПРОИГРАН")
	else:
		ui.set_note("НИЧЬЯ")
	_play_sound("gong")
	if wins_player >= 2 or wins_cpu >= 2:
		game_active = false
		ui.set_match_visible(false)
		ui.show_menu("final")
	else:
		round_break = 2.4

func _restart_round() -> void:
	current_round += 1
	round_seconds = 90.0
	_clear_effects()
	player.reset_fighter()
	cpu.reset_fighter()
	player.position = Vector3(-3.0, 0, 0)
	cpu.position = Vector3(3.0, 0, 0)
	opponent_decision = 0.75
	opponent_guard = 0.0
	notice_seconds = 1.0
	fighting = true
	ui.set_note("РАУНД %d — БОЙ!" % current_round)

func _update_hud() -> void:
	if ui != null and game_active:
		ui.update_bars(player, cpu, int(ceilf(round_seconds)), current_round, wins_player, wins_cpu)

func _spawn_projectile(who, style: String, velocity: float, damage: float) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = who.position + Vector3(who.facing * 0.7, 1.85, 0.30)
	var dark := Color("#24313b")
	if style == "phone":
		var brick := _box(node, Vector3.ZERO, Vector3(0.27, 0.58, 0.14), dark)
		brick.rotation.z = 0.15
		_box(node, Vector3(0.0, 0.13, 0.078), Vector3(0.19, 0.21, 0.02), Color("#7dc2ac"))
		for row in range(3):
			for col in range(3):
				_box(node, Vector3((col - 1) * 0.065, -0.073 - row * 0.068, 0.085), Vector3(0.043, 0.042, 0.02), Color("#afbac1"))
		_box(node, Vector3(0, 0.34, 0), Vector3(0.025, 0.12, 0.025), Color("#181c20"))
	elif style == "cat":
		# Cartoon ghost-cat projectile; no animal harm.
		_ball(node, Vector3(0, 0, 0), 0.32, Color("#b8a8c6"), Vector3(1.14, 0.72, 0.68))
		_ball(node, Vector3(0.30, 0.20, 0.03), 0.25, Color("#b8a8c6"))
		for side in [-1, 1]:
			_box(node, Vector3(0.17 + side * 0.13, 0.45, 0.04), Vector3(0.13, 0.22, 0.12), Color("#d4afbb"))
			_ball(node, Vector3(0.36 + side * 0.10, 0.23, 0.25), 0.045, Color("#91ffbe"))
		var tail := _box(node, Vector3(-0.42, 0.25, 0), Vector3(0.12, 0.65, 0.13), Color("#b8a8c6"))
		tail.rotation.z = -0.55
	else:
		_ball(node, Vector3.ZERO, 0.14, Color("#dfc18e"))
	moving_fx.append({"node": node, "owner": who, "dir": who.facing, "style": style, "velocity": velocity, "damage": damage, "life": 1.4, "age": 0.0})
	_play_sound("throw")

func _tick_projectiles(delta: float) -> void:
	for i in range(moving_fx.size() - 1, -1, -1):
		var shot: Dictionary = moving_fx[i]
		var obj: Node3D = shot["node"]
		if not is_instance_valid(obj):
			moving_fx.remove_at(i)
			continue
		shot["age"] += delta
		shot["life"] -= delta
		obj.position.x += shot["velocity"] * float(shot["dir"]) * delta
		obj.position.y = 1.87 + sin(float(shot["age"]) * 8.5) * 0.14
		obj.rotation.z += delta * 8.5 * float(shot["dir"])
		var opponent = cpu if shot["owner"] == player else player
		if fighting and absf(obj.position.x - opponent.position.x) < 0.65:
			if opponent.take_hit(float(shot["damage"]), int(shot["dir"]), 5.8) > 0.0:
				shot["owner"].gain_energy(3.0)
				_hit_feedback(opponent.position + Vector3(0, 1.78, 0))
				_play_sound("hit")
			shot["life"] = 0.0
		if shot["life"] <= 0.0 or absf(obj.position.x) > 7.7:
			obj.queue_free()
			moving_fx.remove_at(i)

func _hit_feedback(hit_position: Vector3) -> void:
	hit_flash = 0.40
	camera_shake = 1.0
	for j in range(10):
		var angle := rng.randf_range(0, TAU)
		var velocity := Vector3(cos(angle) * rng.randf_range(1.5, 4.0), sin(angle) * rng.randf_range(1.0, 4.0), rng.randf_range(-0.5, 0.5))
		_spawn_vfx_ball(hit_position, rng.randf_range(0.04, 0.11), Color("#f4d18c") if j % 2 else Color("#fd765f"), velocity, 0.32)

func _spawn_vfx_ball(pos: Vector3, size: float, col: Color, vel: Vector3, life: float) -> void:
	var obj := Node3D.new()
	add_child(obj)
	obj.position = pos
	_ball(obj, Vector3.ZERO, size, col)
	impact_fx.append({"node": obj, "velocity": vel, "life": life, "total": life})

func _tick_impact_particles(delta: float) -> void:
	for i in range(impact_fx.size() - 1, -1, -1):
		var fx: Dictionary = impact_fx[i]
		var node: Node3D = fx["node"]
		if not is_instance_valid(node):
			impact_fx.remove_at(i)
			continue
		fx["life"] -= delta
		node.position += fx["velocity"] * delta
		node.position.y -= delta * delta * 2.5
		node.scale = Vector3.ONE * maxf(0.02, float(fx["life"]) / float(fx["total"]))
		if fx["life"] <= 0.0:
			node.queue_free()
			impact_fx.remove_at(i)

func _clear_effects() -> void:
	for fx in moving_fx:
		if is_instance_valid(fx["node"]):
			fx["node"].queue_free()
	for fx in impact_fx:
		if is_instance_valid(fx["node"]):
			fx["node"].queue_free()
	moving_fx.clear()
	impact_fx.clear()

func _simple_mat(col: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = col
	material.roughness = 0.39
	return material

func _box(parent: Node3D, at: Vector3, size: Vector3, col: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = _simple_mat(col)
	parent.add_child(obj)
	obj.position = at
	return obj

func _ball(parent: Node3D, at: Vector3, radius: float, col: Color, stretch: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = _simple_mat(col)
	parent.add_child(obj)
	obj.position = at
	obj.scale = stretch
	return obj

func _play_sound(preset: String) -> void:
	# Tiny original synthesized SFX; zero external assets or downloads.
	var rate := 22050
	var duration := 0.12
	var base := 200.0
	match preset:
		"hit": base = 85.0; duration = 0.20
		"swing": base = 245.0; duration = 0.10
		"throw": base = 460.0; duration = 0.16
		"flame": base = 120.0; duration = 0.55
		"gong": base = 185.0; duration = 0.44
	var count := int(float(rate) * duration)
	var pcm := PackedByteArray()
	pcm.resize(count * 2)
	for i in range(count):
		var t := float(i) / float(rate)
		var env := pow(1.0 - float(i) / float(count), 2.5)
		var tone := sin(TAU * base * t * (1.0 - t * 0.3))
		var noise := rng.randf_range(-1.0, 1.0)
		var sample := clampi(int((tone * 0.47 + noise * 0.53) * env * 17000.0), -32000, 32000)
		pcm.encode_s16(i * 2, sample)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = pcm
	var speaker := AudioStreamPlayer.new()
	speaker.volume_db = -9.0
	speaker.stream = wav
	add_child(speaker)
	speaker.finished.connect(speaker.queue_free)
	speaker.play()
