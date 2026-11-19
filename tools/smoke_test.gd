extends SceneTree
## Automated headless gameplay acceptance test (not a graphics/GPU benchmark).
var app

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed = load("res://scenes/Main.tscn")
	assert(packed != null, "Main scene must exist")
	app = packed.instantiate()
	root.add_child(app)
	current_scene = app
	app.start_match(0)
	assert(app.player.kind == 0 and app.cpu.kind == 1, "Bomj vs CPU Gopnik")
	_assert_face_to_face()
	assert(app.player.rigged_visual.has_3d_asset(), "Bomj should load a real skinned 3D model")
	assert(app.cpu.rigged_visual.has_3d_asset(), "Gopnik should load a real skinned 3D model")
	assert(app.fighting and app.game_active, "Match should start")
	assert(app.player.energy == 0.0, "Stamina starts empty")
	app.cpu.position.x = app.player.position.x + 1.4
	var before: float = app.cpu.hp
	app.player.action = "punch"
	app._on_strike(app.player, "punch")
	assert(app.cpu.hp < before, "Punch should deal damage when in reach")
	assert(app.player.energy == 10.0, "Landing punch charges meter")
	assert(app.player.combo_count == 1, "Successful hit opens a combo window")
	app.player.action = ""
	app.player.energy = 100.0
	assert(app.player.try_action("special1"), "First super must trigger")
	assert(app.player.energy == 60.0, "First super costs 40")
	app.player.action = ""
	assert(not app.player.try_action("special2"), "Second super cannot trigger with 60")
	app.player.energy = 100.0
	assert(app.player.try_action("special2"), "Second super must trigger")
	assert(app.player.energy == 35.0, "Second super costs 65")
	app.choose_difficulty(2)
	assert(app.ai_level == 2, "Hard AI selectable")
	app.start_match(1)
	assert(app.player.rigged_visual.has_3d_asset() and app.cpu.rigged_visual.has_3d_asset(), "Both roles import real 3D assets")
	assert(app.player.kind == 1 and app.cpu.kind == 0, "Gopnik vs CPU Bomj")
	_assert_face_to_face()
	app._end_round(0)
	assert(app.wins_player == 1 and not app.fighting, "Player gains a round")
	app._restart_round()
	_assert_face_to_face()
	assert(app.fighting and app.player.hp == 100.0, "Second round resets fighters")
	app._end_round(0)
	assert(app.player_won() and not app.game_active, "Two wins finish the match")
	print("SMOKE PASS: real skinned GLB models, face-to-face stance, combo, hitstop, AI difficulty, round and match flow")
	quit(0)

func _assert_face_to_face() -> void:
	var player_forward: Vector3 = app.player.model.global_transform.basis.z.normalized()
	var cpu_forward: Vector3 = app.cpu.model.global_transform.basis.z.normalized()
	var toward_cpu: Vector3 = (app.cpu.global_position - app.player.global_position).normalized()
	var toward_player: Vector3 = -toward_cpu
	assert(player_forward.dot(toward_cpu) > 0.85, "Player's face must point toward CPU")
	assert(cpu_forward.dot(toward_player) > 0.85, "CPU's face must point toward player")
	assert(player_forward.z > 0.20 and cpu_forward.z > 0.20, "Both characters must retain facial visibility to camera")
