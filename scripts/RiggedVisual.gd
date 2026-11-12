extends Node3D
## v1: real CC0 skinned GLB bodies and mobile-conscious bone animation.
## Base meshes are provided as bundled licensed binary assets, not block primitives.
var kind := 0
var skeleton: Skeleton3D
var imported_scene: Node3D
var bone_indices: Dictionary = {}
var base_poses: Dictionary = {}
var animation_time := 0.0
var decorations: Array[Node3D] = []
var blink_lamp := 0.0

func setup(new_kind: int) -> void:
	kind = new_kind
	var path := "res://assets/characters/bomj.glb" if kind == 0 else "res://assets/characters/gopnik.glb"
	if not ResourceLoader.exists(path):
		push_warning("Missing rigged model: " + path)
		return
	var pack := load(path) as PackedScene
	if pack == null:
		push_error("Invalid GLB character scene: " + path)
		return
	imported_scene = pack.instantiate() as Node3D
	if imported_scene == null:
		push_error("Expected Node3D in character GLB " + path)
		return
	add_child(imported_scene)
	imported_scene.scale = Vector3.ONE * (1.55 if kind == 0 else 1.58)
	skeleton = _find_skeleton(imported_scene)
	if skeleton == null:
		push_error("Character GLB must contain Skeleton3D: " + path)
		return
	for i in range(skeleton.get_bone_count()):
		var bone := skeleton.get_bone_name(i)
		bone_indices[bone] = i
		base_poses[bone] = skeleton.get_bone_pose_rotation(i)
	# This game is offline and uses a shared procedural fight animation controller.
	# We deliberately do not play imported walk/run clips over attack poses.
	_create_costume_details()
	print("CHARACTER_GLTF_OK ", path, " bones=", skeleton.get_bone_count())

func has_3d_asset() -> bool:
	return skeleton != null and imported_scene != null

func _find_skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node as Skeleton3D
	for child in node.get_children():
		var found := _find_skeleton(child)
		if found != null:
			return found
	return null

func _material(c: Color, rough: float = 0.82, metal: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = rough
	mat.metallic = metal
	mat.ao_enabled = true
	mat.ao_light_affect = 0.5
	return mat

func _mesh(parent: Node3D, geom: Mesh, material: Material, offset: Vector3, orientation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.mesh = geom
	obj.material_override = material
	parent.add_child(obj)
	obj.position = offset
	obj.rotation = orientation
	return obj

func _sphere(parent: Node3D, offset: Vector3, size: Vector3, col: Color, rough: float = 0.8) -> void:
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 20
	sph.rings = 10
	var obj := _mesh(parent, sph, _material(col, rough), offset)
	obj.scale = size

func _hat(parent: Node3D, col: Color) -> void:
	var crown := CylinderMesh.new()
	crown.top_radius = 0.28
	crown.bottom_radius = 0.31
	crown.height = 0.17
	crown.radial_segments = 24
	_mesh(parent, crown, _material(col, 0.96), Vector3(0.0, 0.31, 0))
	var rim := CylinderMesh.new()
	rim.top_radius = 0.33
	rim.bottom_radius = 0.33
	rim.height = 0.050
	rim.radial_segments = 24
	_mesh(parent, rim, _material(col.darkened(0.11)), Vector3(0.0, 0.22, 0))

func _attachment(bone_name: String) -> BoneAttachment3D:
	var node := BoneAttachment3D.new()
	node.bone_name = bone_name
	skeleton.add_child(node)
	decorations.append(node)
	return node

func _fabric_ribbon(parent: Node3D, p: Vector3, height: float, width: float, col: Color) -> void:
	# Woven strip with multiple folds, no hard-edged BoxMesh.
	var surf := SurfaceTool.new()
	surf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(8):
		var y0 := -height * float(segment) / 8.0
		var y1 := -height * float(segment + 1) / 8.0
		var curvature0 := sin(float(segment) * 1.5) * 0.016
		var curvature1 := sin(float(segment + 1) * 1.5) * 0.016
		var z0 := sin(float(segment) * 1.2) * 0.016
		var z1 := sin(float(segment + 1) * 1.2) * 0.016
		var a := Vector3(-width * 0.5 + curvature0, y0, z0)
		var b := Vector3(width * 0.5 + curvature0, y0, z0)
		var c := Vector3(-width * 0.5 + curvature1, y1, z1)
		var d := Vector3(width * 0.5 + curvature1, y1, z1)
		surf.set_uv(Vector2(0, float(segment) / 8.0)); surf.add_vertex(a)
		surf.set_uv(Vector2(1, float(segment) / 8.0)); surf.add_vertex(b)
		surf.set_uv(Vector2(0, float(segment + 1) / 8.0)); surf.add_vertex(c)
		surf.set_uv(Vector2(1, float(segment) / 8.0)); surf.add_vertex(b)
		surf.set_uv(Vector2(1, float(segment + 1) / 8.0)); surf.add_vertex(d)
		surf.set_uv(Vector2(0, float(segment + 1) / 8.0)); surf.add_vertex(c)
	surf.generate_normals()
	_mesh(parent, surf.commit(), _material(col, 0.88), p)

func _create_costume_details() -> void:
	# All details are bone-attached, so clothing does not hover when a fighter strikes.
	if not bone_indices.has("Head"):
		return
	var head := _attachment("Head")
	if kind == 0:
		_hat(head, Color("#44404b"))
		# Scraggly grey-brown pointed beard with asymmetrical tuft clumps.
		for i in range(15):
			var phi := float(i) * TAU / 15.0
			var x := cos(phi) * 0.16
			var z := sin(phi) * 0.12
			var tuft := CylinderMesh.new()
			tuft.top_radius = 0.073 if i % 3 == 0 else 0.052
			tuft.bottom_radius = 0.007
			tuft.height = 0.22 + float(i % 5) * 0.027
			tuft.radial_segments = 7
			var tone := Color("#625849") if i % 3 == 0 else (Color("#9a968d") if i % 3 == 1 else Color("#45413c"))
			_mesh(head, tuft, _material(tone), Vector3(x, -0.24 - float(i % 3) * 0.026, 0.18 + z), Vector3(0.2 * cos(phi), 0, 0.2 * sin(phi)))
		# Layered ragged overcoat fragments and collar strips.
		var torso := _attachment("Spine02")
		_fabric_ribbon(torso, Vector3(-0.27, 0.08, 0.25), 0.78, 0.27, Color("#5d463d"))
		_fabric_ribbon(torso, Vector3(0.31, 0.03, 0.24), 0.65, 0.25, Color("#80725f"))
		_fabric_ribbon(torso, Vector3(0.04, 0.10, 0.29), 0.40, 0.15, Color("#96866d"))
		var bag := _attachment("Spine")
		_sphere(bag, Vector3(-0.40, -0.07, -0.14), Vector3(0.22, 0.26, 0.13), Color("#4c433b"))
	else:
		_hat(head, Color("#1e2027"))
		# Leather collar, knitted waistband, chain and authentic triple stripe motif.
		var torso := _attachment("Spine02")
		_fabric_ribbon(torso, Vector3(-0.29, 0.13, 0.20), 0.45, 0.13, Color("#1b1c22"))
		_fabric_ribbon(torso, Vector3(0.27, 0.13, 0.20), 0.45, 0.13, Color("#202128"))
		var chain := _attachment("Spine01")
		_sphere(chain, Vector3(0.0, 0.13, 0.25), Vector3(0.22, 0.024, 0.02), Color("#c29a55"), 0.25)
		for side in ["Left", "Right"]:
			for bone_name in [side + "UpLeg", side + "Leg"]:
				if bone_indices.has(bone_name):
					var leg := _attachment(bone_name)
					for stripe in range(3):
						_fabric_ribbon(leg, Vector3((0.19 if side == "Right" else -0.19) + float(stripe - 1) * 0.026, -0.12, 0.15), 0.44, 0.017, Color("#f2e8d8"))
			for arm_name in [side + "Arm", side + "ForeArm"]:
				if bone_indices.has(arm_name):
					var arm := _attachment(arm_name)
					_fabric_ribbon(arm, Vector3(0.16 if side == "Right" else -0.16, -0.10, 0.12), 0.32, 0.035, Color("#bfbfc3"))

func reset_pose() -> void:
	if skeleton == null:
		return
	for bone in bone_indices:
		var idx: int = bone_indices[bone]
		skeleton.set_bone_pose_rotation(idx, base_poses[bone])

func _rotate(name: String, euler: Vector3) -> void:
	if not bone_indices.has(name):
		return
	var idx: int = bone_indices[name]
	skeleton.set_bone_pose_rotation(idx, base_poses[name] * Quaternion.from_euler(euler))

func animate_combat(walking: float, state: String, progress: float, guard: bool, stunned: bool, delta: float) -> void:
	if skeleton == null:
		return
	animation_time += delta
	var swing := sin(animation_time * 10.0) * clampf(absf(walking), 0.0, 1.0)
	var breathing := sin(animation_time * 2.7) * 0.042
	_rotate("Spine01", Vector3(breathing, 0, 0))
	_rotate("Spine02", Vector3(-0.14 + breathing, 0, 0))
	_rotate("Head", Vector3(0.065 + sin(animation_time * 1.8) * 0.024, 0, 0))
	_rotate("LeftArm", Vector3(-0.37 - swing * 0.27, 0, 0.15))
	_rotate("RightArm", Vector3(-0.37 + swing * 0.27, 0, -0.15))
	_rotate("LeftForeArm", Vector3(-0.54, 0, 0))
	_rotate("RightForeArm", Vector3(-0.54, 0, 0))
	_rotate("LeftUpLeg", Vector3(swing * 0.35, 0, 0))
	_rotate("RightUpLeg", Vector3(-swing * 0.35, 0, 0))
	_rotate("LeftLeg", Vector3(maxf(0.0, swing) * 0.33, 0, 0))
	_rotate("RightLeg", Vector3(maxf(0.0, -swing) * 0.33, 0, 0))
	if guard:
		_rotate("LeftArm", Vector3(-1.2, 0, 0.22))
		_rotate("RightArm", Vector3(-1.2, 0, -0.22))
		_rotate("LeftForeArm", Vector3(-1.1, 0, 0.0))
		_rotate("RightForeArm", Vector3(-1.1, 0, 0.0))
		_rotate("Spine02", Vector3(0.18, 0, 0))
	if state == "":
		return
	var wave := sin(clampf(progress, 0.0, 1.0) * PI)
	var strike_arm := "RightArm" if kind == 0 else "LeftArm"
	var strike_forearm := "RightForeArm" if kind == 0 else "LeftForeArm"
	match state:
		"punch":
			_rotate(strike_arm, Vector3(-0.48 - 1.36 * wave, 0.06, 0))
			_rotate(strike_forearm, Vector3(-0.5 + 0.35 * wave, 0, 0))
			_rotate("Spine02", Vector3(-0.13, 0.25 * wave, 0))
		"kick":
			_rotate("RightUpLeg", Vector3(-1.17 * wave, 0.0, 0))
			_rotate("RightLeg", Vector3(0.34 * wave, 0, 0))
			_rotate("Spine02", Vector3(0.14 * wave, -0.12, 0))
		"special1":
			_rotate(strike_arm, Vector3(-1.2 * wave, 0, 0))
			_rotate("Head", Vector3(-0.35 * wave, 0, 0))
			_rotate("Spine02", Vector3(-0.18 * wave, 0, 0))
		"special2":
			_rotate(strike_arm, Vector3(-1.65 * wave, 0, 0))
			_rotate(strike_forearm, Vector3(-1.0 * wave, 0, 0))
		"hurt":
			_rotate("Spine02", Vector3(0.32 * (1.0 - progress), 0, 0))
			_rotate("Head", Vector3(0.27 * (1.0 - progress), 0, 0))
		"knockout":
			_rotate("Spine02", Vector3(0.15, 0, 0))
