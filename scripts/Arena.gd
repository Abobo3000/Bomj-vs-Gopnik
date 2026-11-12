extends Node3D
## The combat stage is deliberately small and art-directed: provincial 1997,
## concrete slab apartments, glowing kiosk, broken fences and wet asphalt.
var rng := RandomNumberGenerator.new()
var lamps: Array[OmniLight3D] = []
var elapsed := 0.0
var pbr_cache: Dictionary = {}

func pbr_material(kind: String, tint: String) -> StandardMaterial3D:
	var key := kind + ":" + tint
	if pbr_cache.has(key):
		return pbr_cache[key]
	var mat := material(tint)
	mat.albedo_color = mat.albedo_color.lerp(Color.WHITE, 0.68)
	mat.albedo_texture = load("res://assets/textures/" + kind + "_albedo.png") as Texture2D
	mat.normal_enabled = true
	mat.normal_texture = load("res://assets/textures/" + kind + "_normal.png") as Texture2D
	mat.normal_scale = 0.85
	mat.roughness_texture = load("res://assets/textures/" + kind + "_roughness.png") as Texture2D
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.44, 0.44, 0.44)
	pbr_cache[key] = mat
	return mat

func _ready() -> void:
	rng.seed = 1997
	_build_world()

func _process(delta: float) -> void:
	elapsed += delta
	# Very subtle sodium-vapor lamp flicker, no post-processing required.
	if lamps.size() > 0:
		lamps[0].light_energy = 1.45 + sin(elapsed * 5.0) * 0.07
		if sin(elapsed * 18.7) > 0.985:
			lamps[0].light_energy *= 0.65

func material(hex: String, metallic: float = 0.0, roughness: float = 0.86, glow: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(hex)
	m.metallic = metallic
	m.roughness = roughness
	if glow:
		m.emission_enabled = true
		m.emission = Color(hex)
		m.emission_energy_multiplier = 2.0
	return m

func block(p: Vector3, size: Vector3, hex: String, metal: float = 0.0, rough: float = 0.9, glow: bool = false, texture_kind: String = "") -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	n.mesh = mesh
	n.material_override = pbr_material(texture_kind, hex) if texture_kind != "" else material(hex, metal, rough, glow)
	add_child(n)
	n.position = p
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if glow else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return n

func cylinder(p: Vector3, radius: float, height: float, hex: String) -> MeshInstance3D:
	var n := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.radial_segments = 10
	n.mesh = mesh
	n.material_override = material(hex)
	add_child(n)
	n.position = p
	return n

func label(text_value: String, p: Vector3, font_size: int, color: Color, pixel: float = 0.008) -> Label3D:
	var n := Label3D.new()
	n.text = text_value
	n.font_size = font_size
	n.pixel_size = pixel
	n.modulate = color
	n.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.shaded = false
	n.no_depth_test = false
	add_child(n)
	n.position = p
	return n

func _build_world() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#151927")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#62708b")
	env.ambient_light_energy = 0.72
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)
	var night := DirectionalLight3D.new()
	night.rotation_degrees = Vector3(-48, -28, 5)
	night.light_color = Color("#8fa9d5")
	night.light_energy = 0.72
	night.shadow_enabled = true
	add_child(night)
	# Wet oil-stained street, pavement, drainage and gritty curb.
	block(Vector3(0, -0.18, -1.2), Vector3(60, 0.3, 25), "#1c222e", 0.12, 0.36, false, "asphalt")
	block(Vector3(0, -0.08, -5.1), Vector3(60, 0.28, 5.6), "#33323a", 0.06, 0.82, false, "tile")
	block(Vector3(0, -0.02, -2.22), Vector3(60, 0.19, 0.23), "#5b5960", 0.0, 0.9, false, "concrete")
	for k in range(24):
		var px := rng.randf_range(-13, 13)
		var pz := rng.randf_range(-4.8, 3.2)
		var splash := cylinder(Vector3(px, -0.019, pz), rng.randf_range(0.13, 0.52), 0.014, "#293441")
		splash.scale.z = rng.randf_range(0.4, 1.2)
	for k in range(22):
		var px := rng.randf_range(-12, 12)
		var pz := rng.randf_range(-4.5, 2.8)
		var crack := block(Vector3(px, -0.018, pz), Vector3(rng.randf_range(0.17, 0.85), 0.012, 0.02), "#111720")
		crack.rotation.y = rng.randf_range(-1, 1)
	# Deep silhouettes and repetitive prefab architecture.
	for i in range(8):
		var x := (float(i) - 3.5) * 4.65
		var z := -15.1 - float(i % 3) * 1.6
		var levels := 6 + (i % 4)
		_apartment(x, z, levels, i)
	# Front block, fences and shop are placed asymmetrically.
	_kiosk(-8.1, -7.0)
	_lamp(-5.3, -3.85)
	_lamp(5.6, -3.95)
	_fence(8.0, -4.2)
	_bench(4.4, -5.8)
	_trash(-2.5, -5.9)
	# Overhead power cable and TV aerials.
	for i in range(4):
		var cable := block(Vector3(0, 4.8 + i * 0.16, -8.7), Vector3(24, 0.022, 0.022), "#262831")
		cable.rotation.z = 0.012 * float(i)
	label("ГОРОДСКОЙ РАЙОН  •  1997", Vector3(0, 6.8, -12.2), 54, Color("#91909a"), 0.007)
	label("БЕРЕГИ СЕБЯ", Vector3(8.15, 2.65, -10.5), 35, Color("#bcaaa0"), 0.011)
	label("ВЫБОРЫ 1996", Vector3(-4.4, 1.8, -8.2), 24, Color("#b3afa3"), 0.009)
	_add_rain()

func _apartment(x: float, z: float, floors: int, variant: int) -> void:
	var h := float(floors) * 1.18
	var base := "#77737a" if variant % 3 == 0 else ("#797f89" if variant % 3 == 1 else "#726f6d")
	block(Vector3(x, h * 0.5 - 0.4, z), Vector3(4.75, h, 2.5), base, 0, 0.93, false, "concrete")
	block(Vector3(x, h - 0.30, z), Vector3(5.0, 0.23, 2.75), "#383941")
	# Every floor has narrow panel joints and 3 windows; deterministic light pattern.
	for f in range(floors):
		var y := float(f) * 1.18 + 0.25
		block(Vector3(x, y + 0.52, z + 1.26), Vector3(4.76, 0.045, 0.04), "#57565e")
		for w in range(3):
			var wx := x + float(w - 1) * 1.49
			var lit := rng.randf() < 0.28
			var glass := "#e6b575" if lit else "#252b3b"
			block(Vector3(wx, y + 0.17, z + 1.294), Vector3(0.88, 0.72, 0.06), glass, 0.0, 0.55, lit)
			block(Vector3(wx, y + 0.17, z + 1.344), Vector3(0.034, 0.73, 0.055), "#d1c6bb")
			block(Vector3(wx, y - 0.19, z + 1.36), Vector3(0.96, 0.075, 0.24), "#585862")
			if f % 2 == 0 and w == 1:
				block(Vector3(wx, y - 0.27, z + 1.48), Vector3(1.17, 0.11, 0.64), "#575962")
				block(Vector3(wx, y + 0.03, z + 1.77), Vector3(1.14, 0.55, 0.08), "#4a505a")
	# Rooftop antenna.
	cylinder(Vector3(x + 0.8, h + 0.75, z), 0.035, 1.5, "#2b3038")
	block(Vector3(x + 0.8, h + 1.07, z), Vector3(0.8, 0.025, 0.025), "#2b3038")

func _kiosk(x: float, z: float) -> void:
	block(Vector3(x, 1.24, z), Vector3(3.35, 2.5, 2.4), "#4b494b", 0, 0.8, false, "rust")
	block(Vector3(x, 2.55, z), Vector3(3.8, 0.22, 2.9), "#4e241f", 0, 0.8, false, "rust")
	block(Vector3(x, 1.50, z + 1.23), Vector3(2.2, 1.12, 0.13), "#282f41")
	block(Vector3(x, 1.54, z + 1.31), Vector3(2.09, 0.98, 0.02), "#5d7185", 0.3, 0.18)
	block(Vector3(x, 2.76, z + 1.31), Vector3(3.45, 0.56, 0.13), "#a12732", 0.05, 0.5, true)
	label("ПРОДУКТЫ 24", Vector3(x, 2.76, z + 1.42), 54, Color("#ffdfb0"), 0.012)
	for k in range(3):
		block(Vector3(x - 0.83 + k * 0.76, 0.72, z + 1.4), Vector3(0.56, 0.5, 0.22), "#786e5c")

func _lamp(x: float, z: float) -> void:
	cylinder(Vector3(x, 2.8, z), 0.075, 5.6, "#424957")
	block(Vector3(x + 0.38, 5.58, z), Vector3(0.78, 0.10, 0.14), "#4e545c")
	block(Vector3(x + 0.73, 5.49, z), Vector3(0.50, 0.085, 0.45), "#ffcf82", 0, 0.4, true)
	var light := OmniLight3D.new()
	light.position = Vector3(x + 0.65, 5.34, z + 0.10)
	light.light_color = Color("#ffd18e")
	light.light_energy = 1.45
	light.omni_range = 11.0
	light.shadow_enabled = false
	add_child(light)
	lamps.append(light)

func _fence(x: float, z: float) -> void:
	for i in range(9):
		var fx := x + (float(i) - 4.0) * 0.8
		block(Vector3(fx, 0.86, z), Vector3(0.08, 1.72, 0.1), "#545764")
	for y in [0.45, 1.3]:
		block(Vector3(x, y, z), Vector3(7.0, 0.09, 0.10), "#505460")

func _bench(x: float, z: float) -> void:
	block(Vector3(x, 0.62, z), Vector3(1.87, 0.12, 0.49), "#624c3d")
	block(Vector3(x, 1.15, z - 0.19), Vector3(1.85, 0.75, 0.14), "#614d3e")
	for i in [-0.7, 0.7]:
		block(Vector3(x + i, 0.32, z), Vector3(0.12, 0.65, 0.39), "#373d40")

func _trash(x: float, z: float) -> void:
	cylinder(Vector3(x, 0.48, z), 0.43, 0.95, "#4e5554")
	cylinder(Vector3(x, 0.99, z), 0.49, 0.09, "#2b343b")
	for i in range(3):
		var y := 0.24 + i * 0.19
		block(Vector3(x, y, z + 0.42), Vector3(0.45, 0.027, 0.027), "#34393c")

func _add_rain() -> void:
	# Night rain on 90s asphalt: thin trails, cheap particle budget for S23.
	var weather := GPUParticles3D.new()
	weather.name = "Drizzle"
	weather.amount = 150
	weather.lifetime = 1.75
	weather.explosiveness = 0.0
	weather.preprocess = 1.7
	weather.position = Vector3(0.0, 7.7, 1.2)
	weather.visibility_aabb = AABB(Vector3(-13.0,-12.0,-8.0), Vector3(26.0,14.0,16.0))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(11.0, 0.15, 6.0)
	process.gravity = Vector3(0.0,-16.0,0.0)
	process.initial_velocity_min = 0.6
	process.initial_velocity_max = 1.0
	weather.process_material = process
	var drop := SphereMesh.new()
	drop.radius = 0.011
	drop.height = 0.15
	drop.radial_segments = 5
	drop.rings = 2
	drop.material = material("#91a5c4",0,0.18)
	weather.draw_pass_1 = drop
	add_child(weather)
	weather.emitting = true
