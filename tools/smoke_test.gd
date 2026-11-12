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
	assert(app.fighting and app.game_active, "Match should start")
	assert(app.player.energy == 0.0, "Stamina starts empty")
	app.cpu.position.x = app.player.position.x + 1.4
	var before: float = app.cpu.hp
	app._on_strike(app.player, "punch")
	assert(app.cpu.hp < before, "Punch should deal damage when in reach")
	assert(app.player.energy == 10.0, "Landing punch charges meter")
	app.player.action = ""
	app.player.energy = 100.0
	assert(app.player.try_action("special1"), "First super must trigger")
	assert(app.player.energy == 60.0, "First super costs 40")
	app.player.action = ""
	assert(not app.player.try_action("special2"), "Second super cannot trigger with 60")
	app.player.energy = 100.0
	assert(app.player.try_action("special2"), "Second super must trigger")
	assert(app.player.energy == 35.0, "Second super costs 65")
	app.start_match(1)
	assert(app.player.kind == 1 and app.cpu.kind == 0, "Gopnik vs CPU Bomj")
	app._end_round(0)
	assert(app.wins_player == 1 and not app.fighting, "Player gains a round")
	app._restart_round()
	assert(app.fighting and app.player.hp == 100.0, "Second round resets fighters")
	app._end_round(0)
	assert(app.player_won() and not app.game_active, "Two wins finish the match")
	print("SMOKE PASS: both fighters, normal hit, stamina costs, CPU selection, round and match flow")
	quit(0)
