class_name HouseholdBlockout
extends Node3D

@onready var floor_mesh: MeshInstance3D = $Floor
@onready var room_pads: Node3D = $Visuals/RoomPads
@onready var walls: Node3D = $Visuals/Walls
@onready var furniture: Node3D = $Visuals/Furniture

func _ready() -> void:
	_apply_floor_style()
	_build_visual_blockout()

func get_resident_spawn(index: int) -> Marker3D:
	if index < 1 or index > 6:
		return null
	var path := "Spawns/ResidentSpawn%02d" % index
	if not has_node(path):
		return null
	return get_node(path) as Marker3D

func get_destination(destination_name: StringName) -> Marker3D:
	var path := "Destinations/%s" % destination_name
	if not has_node(path):
		return null
	return get_node(path) as Marker3D

func _apply_floor_style() -> void:
	if not is_instance_valid(floor_mesh):
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("d7e0eb")
	material.roughness = 0.95
	floor_mesh.material_override = material

func _build_visual_blockout() -> void:
	if not is_instance_valid(room_pads):
		return
	if room_pads.get_child_count() > 0:
		return

	var room_colors: Array[Color] = [
		Color("32445d"),
		Color("3a4d67"),
		Color("354c5b"),
		Color("443f61"),
		Color("354b68"),
		Color("2f594c"),
	]
	var room_names := [
		&"Kitchen",
		&"Living",
		&"Bedroom",
		&"Bath",
		&"Hall",
		&"Yard",
	]
	var x_positions := [-5.4, 0.0, 5.4]
	var color_index := 0
	for z in [-2.25, 2.25]:
		for x in x_positions:
			_make_box(
				room_pads,
				StringName("%sPad" % room_names[color_index]),
				Vector3(x, -0.015, z),
				Vector3(5.0, 0.08, 4.0),
				room_colors[color_index]
			)
			color_index += 1

	# Cutaway walls: leave the camera-facing edge open.
	var wall_color := Color("8797ab")
	_make_box(walls, &"BackWall", Vector3(0.0, 0.45, -5.0), Vector3(16.0, 0.9, 0.16), wall_color)
	_make_box(walls, &"LeftWall", Vector3(-8.0, 0.45, 0.0), Vector3(0.16, 0.9, 10.0), wall_color)
	_make_box(walls, &"RightWall", Vector3(8.0, 0.45, 0.0), Vector3(0.16, 0.9, 10.0), wall_color)
	_make_box(walls, &"CenterHorizontal", Vector3(0.0, 0.28, 0.0), Vector3(16.0, 0.56, 0.12), Color("718299"))
	for x in [-2.7, 2.7]:
		_make_box(
			walls,
			StringName("Divider_%s" % str(x)),
			Vector3(x, 0.28, 0.0),
			Vector3(0.12, 0.56, 10.0),
			Color("718299")
		)

	_build_furniture()

func _build_furniture() -> void:
	var fridge := get_destination(&"Fridge")
	if fridge != null:
		_make_box(
			furniture,
			&"FridgeVisual",
			fridge.position + Vector3(0.0, 0.9, 0.0),
			Vector3(0.9, 1.8, 0.8),
			Color("c7d4e3")
		)

	var sofa := get_destination(&"Sofa")
	if sofa != null:
		_make_box(
			furniture,
			&"SofaVisual",
			sofa.position + Vector3(0.0, 0.35, 0.0),
			Vector3(2.5, 0.7, 0.95),
			Color("657b96")
		)

	var shower := get_destination(&"Shower")
	if shower != null:
		_make_box(
			furniture,
			&"ShowerVisual",
			shower.position + Vector3(0.0, 0.32, 0.0),
			Vector3(1.2, 0.64, 1.2),
			Color("78a7b4")
		)

	for index in range(1, 7):
		var bed := get_destination(StringName("Bed%02d" % index))
		if bed == null:
			continue
		_make_box(
			furniture,
			StringName("Bed%02dVisual" % index),
			bed.position + Vector3(0.0, 0.24, 0.0),
			Vector3(1.55, 0.48, 1.05),
			Color("7f8da2")
		)

func _make_box(
	parent: Node3D,
	node_name: StringName,
	position_value: Vector3,
	size_value: Vector3,
	color: Color
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value

	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
