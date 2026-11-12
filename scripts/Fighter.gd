extends Node3D
const RiggedVisual = preload("res://scripts/RiggedVisual.gd")
## Two fully procedural, readable fighting silhouettes. All geometry is authored here
## and can later be replaced by rigged CC0 GLB fighters without changing combat logic.
signal move_strike(who, move_name)
signal died(who)

const WALK_SPEED := 4.0
const MAX_HP := 100.0
const MAX_ENERGY := 100.0
var kind := 0 # 0 - Bomj, 1 - Gopnik
var facing := 1
var hp := MAX_HP
var energy := 0.0
var is_guarding := false
var action := ""
var action_time := 0.0
var action_length := 0.0
var strike_emitted := false
var hit_cooldown := 0.0
var knockback := 0.0
var defeated := false
var animation_clock := 0.0
var movement := 0.0
var combo_count := 0
var combo_window := 0.0
var buffered_action := ""
var last_hit_guarded := false
var model: Node3D
var chest: Node3D
var head: Node3D
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var rigged_visual: Node3D

func setup(new_kind: int, direction: int) -> void:
	kind = new_kind
	facing = direction
	name = "Bomj" if kind == 0 else "Gopnik"
	_build_model()
	# Replace primitive design placeholders with imported PBR skinned characters.
	rigged_visual = RiggedVisual.new()
	model.add_child(rigged_visual)
	rigged_visual.setup(kind)
	if rigged_visual.has_3d_asset():
		chest.visible = false
		left_leg.visible = false
		right_leg.visible = false
	# Meshes are authored with their faces along local +Z. The fighting lane is world X.
	# A 70-degree three-quarter pose looks toward the enemy yet shows facial details
	# to the camera at +Z. Direction -1 mirrors it for the CPU/opposite side.
	model.rotation.y = deg_to_rad(70.0) * float(facing)

func reset_fighter() -> void:
	hp = MAX_HP
	energy = 0.0
	is_guarding = false
	action = ""
	action_time = 0.0
	hit_cooldown = 0.0
	knockback = 0.0
	defeated = false
	movement = 0.0
	combo_count = 0
	combo_window = 0.0
	buffered_action = ""
	position.y = 0.0
	rotation.z = 0.0
	# Restore the actual animated model, not only the empty fighter root.
	if model != null:
		model.rotation.z = 0.0
		model.position.y = 0.0
	if is_instance_valid(rigged_visual):
		rigged_visual.reset_pose()

func tick(delta: float) -> void:
	animation_clock += delta
	hit_cooldown = maxf(0.0, hit_cooldown - delta)
	combo_window = maxf(0.0, combo_window - delta)
	if combo_window == 0.0:
		combo_count = 0
	if absf(knockback) > 0.01:
		position.x = clampf(position.x + knockback * delta, -5.5, 5.5)
		knockback = move_toward(knockback, 0.0, delta * 20.0)
	if action != "":
		action_time += delta
		if not strike_emitted and action_time >= _strike_time():
			strike_emitted = true
			if action != "hurt" and action != "knockout":
				move_strike.emit(self, action)
		if action_time >= action_length and not defeated:
			action = ""
			action_time = 0.0
			if buffered_action != "":
				var queued: String = buffered_action
				buffered_action = ""
				try_action(queued)
	movement = move_toward(movement, 0.0, delta * 3.0)
	_pose()

func walk(axis: float, delta: float) -> void:
	if defeated or action != "" or is_guarding:
		return
	movement = axis
	position.x = clampf(position.x + axis * WALK_SPEED * delta, -5.4, 5.4)

func try_action(move_name: String) -> bool:
	if defeated or is_guarding:
		return false
	if action != "":
		# Buffered normals let a three-hit combo feel intentional on touch screens.
		if move_name in ["punch", "kick"] and action in ["punch", "kick"] and action_time >= _strike_time() and action_time <= action_length:
			buffered_action = move_name
			return true
		return false
	var cost := 0.0
	if move_name == "special1":
		cost = 40.0
	elif move_name == "special2":
		cost = 65.0
	if energy < cost:
		return false
	energy -= cost
	if move_name == "punch" or move_name == "kick":
		if combo_window <= 0.0:
			combo_count = 0
	action = move_name
	action_time = 0.0
	strike_emitted = false
	match move_name:
		"punch": action_length = 0.42
		"kick": action_length = 0.64
		"special1": action_length = 1.05
		"special2": action_length = 1.25
		_: action_length = 0.44
	return true

func _strike_time() -> float:
	match action:
		"punch": return 0.15
		"kick": return 0.27
		"special1": return 0.45
		"special2": return 0.55
	return 2.0

func take_hit(damage: float, direction: int, force: float = 3.0) -> float:
	if defeated or hit_cooldown > 0.0:
		return 0.0
	var actual := damage * (0.22 if is_guarding else 1.0)
	hp = maxf(0.0, hp - actual)
	energy = minf(MAX_ENERGY, energy + (5.0 if is_guarding else 11.0))
	knockback = float(direction) * force * (0.35 if is_guarding else 1.0)
	hit_cooldown = 0.22
	last_hit_guarded = is_guarding
	if hp <= 0.0:
		defeated = true
		action = "knockout"
		action_time = 0.0
		action_length = 100000.0
		died.emit(self)
	elif not is_guarding:
		buffered_action = ""
		action = "hurt"
		action_time = 0.0
		action_length = 0.34
	return actual

func register_combo_hit() -> void:
	if combo_window > 0.0:
		combo_count = mini(3, combo_count + 1)
	else:
		combo_count = 1
	combo_window = 0.96

func gain_energy(amount: float) -> void:
	energy = minf(MAX_ENERGY, energy + amount)

func set_guard(enabled: bool) -> void:
	if defeated:
		is_guarding = false
	else:
		is_guarding = enabled and action == ""

func _pose() -> void:
	if model == null:
		return
	var idle := sin(animation_clock * 3.6)
	var swing := sin(animation_clock * 13.0) * clampf(absf(movement), 0.0, 1.0)
	model.position.y = idle * 0.025
	model.rotation.z = idle * 0.013
	chest.rotation.z = 0.0
	chest.rotation.x = 0.0
	head.rotation.z = idle * 0.018
	# The chest faces local +Z, so strikes must swing in the YZ plane.
	# Rotating around Z (as in v0.1) caused arms and legs to swing sideways.
	left_arm.rotation = Vector3(-swing * 0.27, 0.0, -0.17)
	right_arm.rotation = Vector3(swing * 0.27, 0.0, 0.17)
	left_leg.rotation = Vector3(swing * 0.25, 0.0, 0.0)
	right_leg.rotation = Vector3(-swing * 0.25, 0.0, 0.0)
	# In three-quarter view the camera-near limb is different on each side.
	var front_arm: Node3D = left_arm if facing == 1 else right_arm
	var front_leg: Node3D = left_leg if facing == 1 else right_leg
	if is_guarding:
		left_arm.rotation.x = -2.1
		right_arm.rotation.x = -2.1
		left_arm.rotation.z = -0.38
		right_arm.rotation.z = 0.38
		chest.rotation.x = -0.09
	if action != "":
		var progress := clampf(action_time / maxf(0.01, action_length), 0.0, 1.0)
		var impulse := sin(progress * PI)
		match action:
			"punch":
				front_arm.rotation.x = -(0.38 + 1.57 * impulse)
				chest.rotation.x = -0.15 * impulse
				head.rotation.z = 0.05 * impulse
			"kick":
				front_leg.rotation.x = -1.26 * impulse
				chest.rotation.x = 0.19 * impulse
			"special1":
				front_arm.rotation.x = -(0.65 + 1.20 * impulse)
				head.rotation.x = -0.30 * impulse
			"special2":
				front_arm.rotation.x = -(0.55 + 1.55 * impulse)
				chest.rotation.x = -0.16 * impulse
			"hurt":
				chest.rotation.x = 0.24 * (1.0 - progress)
				head.rotation.x = 0.15 * (1.0 - progress)
			"knockout":
				model.rotation.z = -facing * 1.30 * minf(action_time / 0.6, 1.0)
				model.position.y = -0.42 * minf(action_time / 0.6, 1.0)
	if action != "special1" and action != "hurt":
		head.rotation.x = 0.0
	if not defeated:
		model.rotation.z = idle * 0.013
	if is_instance_valid(rigged_visual):
		rigged_visual.animate_combat(movement, action, action_time / maxf(0.01, action_length), is_guarding, action == "hurt", get_physics_process_delta_time())

func _mat(c: Color, metallic: float = 0.0, roughness: float = 0.85, glowing: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	if glowing:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 1.7
	return m

func _box(parent: Node3D, p: Vector3, size: Vector3, c: Color, metal: float = 0.0, rough: float = 0.85) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	n.mesh = m
	n.material_override = _mat(c, metal, rough)
	parent.add_child(n)
	n.position = p
	return n

func _ball(parent: Node3D, p: Vector3, r: float, c: Color, elongation: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	n.mesh = m
	n.material_override = _mat(c)
	parent.add_child(n)
	n.position = p
	n.scale = elongation
	return n

func _cylinder(parent: Node3D, p: Vector3, radius: float, height: float, c: Color, metal: float = 0.0) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius * 1.08
	m.height = height
	m.radial_segments = 10
	n.mesh = m
	n.material_override = _mat(c, metal)
	parent.add_child(n)
	n.position = p
	return n

func _build_model() -> void:
	model = Node3D.new()
	add_child(model)
	chest = Node3D.new()
	model.add_child(chest)
	chest.position.y = 1.49
	head = Node3D.new()
	chest.add_child(head)
	head.position = Vector3(0.0, 0.89, 0.0)
	left_arm = Node3D.new()
	right_arm = Node3D.new()
	left_leg = Node3D.new()
	right_leg = Node3D.new()
	for node in [left_arm, right_arm]:
		chest.add_child(node)
	for node in [left_leg, right_leg]:
		model.add_child(node)
	left_arm.position = Vector3(-0.53, 0.48, 0.0)
	right_arm.position = Vector3(0.53, 0.48, 0.0)
	left_leg.position = Vector3(-0.26, 1.05, 0.0)
	right_leg.position = Vector3(0.26, 1.05, 0.0)
	var skin := Color("#ba8873") if kind == 0 else Color("#d7a285")
	var dark := Color("#242526")
	if kind == 0:
		# Layers, lopsided quilted jacket, frayed patches and a chaotic beard.
		_box(chest, Vector3(0.0, 0.03, 0.0), Vector3(1.08, 1.33, 0.58), Color("#545e4a"))
		_box(chest, Vector3(0.0, 0.02, 0.32), Vector3(0.85, 1.12, 0.13), Color("#73705b"))
		_box(chest, Vector3(-0.21, 0.10, 0.40), Vector3(0.27, 0.75, 0.055), Color("#b69a67"))
		_box(chest, Vector3(0.22, -0.17, 0.40), Vector3(0.29, 0.37, 0.055), Color("#784b44"))
		_box(chest, Vector3(-0.30, -0.37, 0.41), Vector3(0.29, 0.24, 0.07), Color("#444d40"))
		_box(chest, Vector3(0.32, 0.32, 0.39), Vector3(0.2, 0.15, 0.06), Color("#93907a"))
		# Bag and collar.
		_box(chest, Vector3(-0.34, 0.02, -0.40), Vector3(0.55, 0.79, 0.23), Color("#494035"))
		_cylinder(chest, Vector3(0, 0.74, 0), 0.31, 0.2, Color("#77715f"))
	else:
		# Leather jacket, zipper, lapels, chain and shiny finish.
		_box(chest, Vector3(0.0, 0.09, 0.0), Vector3(1.10, 1.25, 0.62), Color("#15171e"), 0.28, 0.27)
		_box(chest, Vector3(0.0, 0.15, 0.332), Vector3(0.8, 0.97, 0.065), Color("#22232c"), 0.35, 0.25)
		_box(chest, Vector3(0, 0.01, 0.372), Vector3(0.035, 0.88, 0.032), Color("#c3b8a2"), 0.88)
		for side in [-1, 1]:
			var lapel := _box(chest, Vector3(side * 0.29, 0.39, 0.39), Vector3(0.36, 0.46, 0.06), Color("#383a43"), 0.4, 0.27)
			lapel.rotation.z = side * 0.28
		_cylinder(chest, Vector3(0.0, 0.77, 0.0), 0.22, 0.15, skin)
		_box(chest, Vector3(0, 0.63, 0.41), Vector3(0.30, 0.045, 0.04), Color("#d5a43d"), 0.9)
	# Arms and shoes. Lower legs hang from pivot to ground.
	for idx in range(2):
		var arm: Node3D = left_arm if idx == 0 else right_arm
		var leg: Node3D = left_leg if idx == 0 else right_leg
		var coat_color := Color("#5c6150") if kind == 0 else Color("#1b1d24")
		_cylinder(arm, Vector3(0, -0.33, 0), 0.20, 0.73, coat_color, 0.2 if kind == 1 else 0.0)
		_ball(arm, Vector3(0, -0.71, 0.04), 0.18, Color("#806d59") if kind == 0 else skin)
		if kind == 0:
			_box(arm, Vector3(0, -0.49, 0.20), Vector3(0.24, 0.15, 0.06), Color("#8b6951"))
		var pants := Color("#646154") if kind == 0 else Color("#222633")
		_cylinder(leg, Vector3(0, -0.43, 0), 0.225, 0.90, pants)
		if kind == 1:
			for stripe in range(3):
				_box(leg, Vector3(-0.18 if idx == 0 else 0.18, -0.41, -0.10 + stripe * 0.095), Vector3(0.045, 0.78, 0.035), Color("#e0d9ca"))
			# Signature white socks with trouser cuffs tucked inside.
			_cylinder(leg, Vector3(0, -0.90, 0), 0.15, 0.24, Color("#e4e2d8"))
			var shoe := _box(leg, Vector3(0.11 * facing, -1.01, 0.12), Vector3(0.44, 0.17, 0.27), Color("#17100f"), 0.35, 0.18)
			shoe.scale.x = 1.37
			_ball(leg, Vector3(0.38 * facing, -1.02, 0.12), 0.10, Color("#17100f"), Vector3(1.2, 0.55, 0.9))
		else:
			_box(leg, Vector3(0.08 * facing, -0.96, 0.12), Vector3(0.43, 0.21, 0.32), Color("#3b352e"))
	# Head silhouette and expression.
	_ball(head, Vector3(0, 0.08, 0.0), 0.43, skin, Vector3(0.92, 1.05, 0.89))
	_ball(head, Vector3(0, 0.01, 0.40), 0.12, skin, Vector3(0.68, 1.25, 0.9))
	for side in [-1, 1]:
		_ball(head, Vector3(side * 0.19, 0.13, 0.37), 0.065, Color("#e9daca"))
		_ball(head, Vector3(side * 0.19, 0.13, 0.424), 0.028, Color("#1a1c21"))
		var brow := _box(head, Vector3(side * 0.19, 0.24, 0.43), Vector3(0.19, 0.05, 0.05), Color("#302c27"))
		brow.rotation.z = -side * (0.36 if kind == 1 else 0.08)
	if kind == 0:
		# Individual coarse beard tufts create the character's graphic signature.
		_ball(head, Vector3(0, -0.23, 0.31), 0.27, Color("#35312e"), Vector3(1.16, 1.2, 0.72))
		for i in range(7):
			var x := (float(i) - 3.0) * 0.089
			_ball(head, Vector3(x, -0.39 - absf(x) * 0.11, 0.35), 0.091, Color("#3e3733") if i % 2 == 0 else Color("#514339"), Vector3(0.65, 1.7, 0.7))
		_ball(head, Vector3(0, 0.35, -0.02), 0.40, Color("#4d473f"), Vector3(1.02, 0.46, 1.02))
		_box(head, Vector3(0, 0.44, 0.20), Vector3(0.84, 0.14, 0.48), Color("#60584a"))
	else:
		# Bald cranium, tiny crown cap, arrogant eyebrows and cheek scars.
		_ball(head, Vector3(0, 0.48, 0), 0.32, Color("#25252b"), Vector3(1.10, 0.32, 1.10))
		_box(head, Vector3(0.04, 0.53, 0.24), Vector3(0.63, 0.10, 0.24), Color("#24252b"))
		_box(head, Vector3(0.22, -0.11, 0.403), Vector3(0.15, 0.025, 0.021), Color("#744a43"))
		_box(head, Vector3(0, -0.23, 0.35), Vector3(0.27, 0.044, 0.06), Color("#4d292b"))
	# Ground shadow, subtle stylized ellipse.
	var sh := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.72
	sm.bottom_radius = 0.72
	sm.height = 0.015
	sh.mesh = sm
	sh.scale.z = 0.59
	sh.material_override = _mat(Color(0.005, 0.006, 0.009, 0.55))
	add_child(sh)
	sh.position = Vector3(0, 0.012, 0)
