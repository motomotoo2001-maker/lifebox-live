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
	material.albedo_color = Color("d6dde7")
	material.roughness = 0.9
	floor_mesh.material_override = material

func _build_visual_blockout() -> void:
	if not is_instance_valid(room_pads) or room_pads.get_child_count() > 0:
		return

	var room_colors: Array[Color] = [
		Color("40566f"),
		Color("405b73"),
		Color("405f65"),
		Color("51496b"),
		Color("3d5872"),
		Color("356456"),
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

	_build_walls()
	_build_furniture()

func _build_walls() -> void:
	var outer := Color("9aaabd")
	var inner := Color("7f90a6")
	var height := 1.25

	_make_box(
		walls,
		&"BackWall",
		Vector3(0, height * 0.5, -5),
		Vector3(16, height, 0.16),
		outer
	)
	_make_box(
		walls,
		&"LeftWall",
		Vector3(-8, height * 0.5, 0),
		Vector3(0.16, height, 10),
		outer
	)
	_make_box(
		walls,
		&"RightWall",
		Vector3(8, height * 0.5, 0),
		Vector3(0.16, height, 10),
		outer
	)

	for x in [-2.7, 2.7]:
		_make_box(
			walls,
			StringName("DividerBack_%s" % x),
			Vector3(x, height * 0.5, -2.85),
			Vector3(0.12, height, 4.3),
			inner
		)
		_make_box(
			walls,
			StringName("DividerFront_%s" % x),
			Vector3(x, height * 0.5, 2.85),
			Vector3(0.12, height, 4.3),
			inner
		)

	var hall_segments := [
		[-7.0, 2.0],
		[-3.9, 1.8],
		[-1.35, 1.5],
		[1.35, 1.5],
		[3.9, 1.8],
		[7.0, 2.0],
	]
	for segment in hall_segments:
		_make_box(
			walls,
			StringName("HallSeg_%s" % str(segment[0])),
			Vector3(float(segment[0]), height * 0.5, 0),
			Vector3(float(segment[1]), height, 0.12),
			inner
		)

func _build_furniture() -> void:
	var fridge := get_destination(&"Fridge")
	if fridge != null:
		_build_fridge(fridge.position)

	var sofa := get_destination(&"Sofa")
	if sofa != null:
		_build_sofa(sofa.position)

	var shower := get_destination(&"Shower")
	if shower != null:
		_build_shower(shower.position)

	for index in range(1, 7):
		var bed := get_destination(StringName("Bed%02d" % index))
		if bed != null:
			_build_bed(index, bed.position)

func _build_fridge(position_value: Vector3) -> void:
	_make_box(
		furniture,
		&"FridgeBody",
		position_value + Vector3(0, 0.82, 0),
		Vector3(0.9, 1.64, 0.78),
		Color("dce7ef")
	)
	_make_box(
		furniture,
		&"FridgeTop",
		position_value + Vector3(0, 1.33, -0.405),
		Vector3(0.78, 0.025, 0.03),
		Color("8da0b4")
	)
	_make_box(
		furniture,
		&"FridgeHandle",
		position_value + Vector3(0.29, 0.78, -0.42),
		Vector3(0.05, 0.48, 0.04),
		Color("6a7a8c")
	)

func _build_sofa(position_value: Vector3) -> void:
	var color := Color("7289a4")
	_make_box(
		furniture,
		&"SofaSeat",
		position_value + Vector3(0, 0.28, 0),
		Vector3(2.5, 0.5, 0.9),
		color
	)
	_make_box(
		furniture,
		&"SofaBack",
		position_value + Vector3(0, 0.72, 0.36),
		Vector3(2.5, 0.65, 0.18),
		color.darkened(0.12)
	)
	_make_box(
		furniture,
		&"SofaArmL",
		position_value + Vector3(-1.18, 0.48, 0),
		Vector3(0.18, 0.7, 0.92),
		color.darkened(0.06)
	)
	_make_box(
		furniture,
		&"SofaArmR",
		position_value + Vector3(1.18, 0.48, 0),
		Vector3(0.18, 0.7, 0.92),
		color.darkened(0.06)
	)

func _build_shower(position_value: Vector3) -> void:
	_make_box(
		furniture,
		&"ShowerBase",
		position_value + Vector3(0, 0.08, 0),
		Vector3(1.25, 0.16, 1.25),
		Color("c9e7e8")
	)
	_make_box(
		furniture,
		&"ShowerBack",
		position_value + Vector3(0, 0.8, 0.55),
		Vector3(1.25, 1.5, 0.08),
		Color("78a7b4")
	)
	_make_box(
		furniture,
		&"ShowerSide",
		position_value + Vector3(0.58, 0.65, 0),
		Vector3(0.08, 1.2, 1.0),
		Color("8fc0c5")
	)

func _build_bed(index: int, position_value: Vector3) -> void:
	var base := Color("8798ad")
	_make_box(
		furniture,
		StringName("Bed%02dBase" % index),
		position_value + Vector3(0, 0.18, 0),
		Vector3(1.55, 0.36, 1.05),
		base
	)
	_make_box(
		furniture,
		StringName("Bed%02dBlanket" % index),
		position_value + Vector3(0, 0.39, 0.1),
		Vector3(1.45, 0.11, 0.66),
		Color("a9bbd1")
	)
	_make_box(
		furniture,
		StringName("Bed%02dPillow" % index),
		position_value + Vector3(0, 0.44, -0.31),
		Vector3(0.72, 0.14, 0.28),
		Color("e1e7ef")
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
	material.roughness = 0.88

	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.position = position_value
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
