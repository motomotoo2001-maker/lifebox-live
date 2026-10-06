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
		Color("66594f"),
		Color("4d6177"),
		Color("655a75"),
		Color("487078"),
		Color("596878"),
		Color("3e7259"),
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

	_build_kitchen_details()
	_build_living_details()
	_build_bedroom_details()
	_build_bathroom_details()
	_build_hall_details()
	_build_yard_details()


func _build_kitchen_details() -> void:
	var cabinet := Color("9b785f")
	var counter := Color("d2b08b")
	_make_box(
		furniture,
		&"KitchenCounter",
		Vector3(-5.35, 0.42, 4.35),
		Vector3(2.0, 0.82, 0.55),
		cabinet
	)
	_make_box(
		furniture,
		&"KitchenCounterTop",
		Vector3(-5.35, 0.86, 4.35),
		Vector3(2.12, 0.08, 0.62),
		counter
	)
	for index in range(3):
		_make_box(
			furniture,
			StringName("KitchenCabinetDoor%02d" % (index + 1)),
			Vector3(-6.0 + float(index) * 0.65, 0.42, 4.055),
			Vector3(0.52, 0.62, 0.025),
			Color("6f5547")
		)

	_make_box(
		furniture,
		&"KitchenTableTop",
		Vector3(-4.6, 0.66, 2.72),
		Vector3(1.7, 0.12, 1.05),
		Color("b98a62")
	)
	for offset in [
		Vector3(-0.7, 0.32, -0.38),
		Vector3(0.7, 0.32, -0.38),
		Vector3(-0.7, 0.32, 0.38),
		Vector3(0.7, 0.32, 0.38),
	]:
		_make_box(
			furniture,
			StringName("KitchenTableLeg_%s" % str(offset)),
			Vector3(-4.6, 0.32, 2.72) + offset,
			Vector3(0.1, 0.58, 0.1),
			Color("76533d")
		)

func _build_living_details() -> void:
	_make_box(
		furniture,
		&"LivingRug",
		Vector3(0.0, 0.035, 2.8),
		Vector3(3.7, 0.045, 2.25),
		Color("7b6fa8")
	)
	_make_box(
		furniture,
		&"LivingCoffeeTable",
		Vector3(0.0, 0.28, 2.55),
		Vector3(1.55, 0.16, 0.72),
		Color("8c684c")
	)
	_make_box(
		furniture,
		&"LivingMediaUnit",
		Vector3(0.0, 0.33, 1.1),
		Vector3(2.25, 0.5, 0.42),
		Color("3e4a5b")
	)
	_make_box(
		furniture,
		&"LivingTV",
		Vector3(0.0, 1.05, 1.05),
		Vector3(1.9, 1.0, 0.1),
		Color("17202c")
	)

func _build_bedroom_details() -> void:
	_make_box(
		furniture,
		&"BedroomWardrobe",
		Vector3(5.85, 0.92, -4.2),
		Vector3(1.6, 1.84, 0.58),
		Color("77635a")
	)
	for index in range(2):
		_make_box(
			furniture,
			StringName("BedroomNightstand%02d" % (index + 1)),
			Vector3(4.45 + float(index) * 1.25, 0.32, -2.15),
			Vector3(0.62, 0.58, 0.62),
			Color("92745f")
		)
		_make_box(
			furniture,
			StringName("BedroomLamp%02d" % (index + 1)),
			Vector3(4.45 + float(index) * 1.25, 0.82, -2.15),
			Vector3(0.25, 0.42, 0.25),
			Color("e8c985")
		)

func _build_bathroom_details() -> void:
	_make_box(
		furniture,
		&"BathroomVanity",
		Vector3(5.25, 0.43, 4.25),
		Vector3(1.15, 0.78, 0.55),
		Color("87a3a6")
	)
	_make_box(
		furniture,
		&"BathroomSink",
		Vector3(5.25, 0.88, 4.23),
		Vector3(0.72, 0.12, 0.42),
		Color("d5e4e6")
	)
	_make_box(
		furniture,
		&"BathroomMirror",
		Vector3(5.25, 1.45, 4.5),
		Vector3(0.85, 0.72, 0.06),
		Color("9fc8d2")
	)
	_make_box(
		furniture,
		&"BathroomToiletBase",
		Vector3(6.8, 0.28, 2.45),
		Vector3(0.62, 0.5, 0.72),
		Color("d9e6e8")
	)
	_make_box(
		furniture,
		&"BathroomToiletTank",
		Vector3(6.8, 0.72, 2.72),
		Vector3(0.58, 0.56, 0.25),
		Color("d9e6e8")
	)

func _build_hall_details() -> void:
	_make_box(
		furniture,
		&"HallConsole",
		Vector3(0.15, 0.42, -1.15),
		Vector3(1.8, 0.72, 0.42),
		Color("7f644e")
	)
	_make_box(
		furniture,
		&"HallPlantPot",
		Vector3(-1.55, 0.24, -1.25),
		Vector3(0.5, 0.46, 0.5),
		Color("8d5f48")
	)
	_make_box(
		furniture,
		&"HallPlantStem",
		Vector3(-1.55, 0.82, -1.25),
		Vector3(0.16, 0.72, 0.16),
		Color("47765a")
	)
	for offset in [
		Vector3(-0.2, 1.18, 0.0),
		Vector3(0.2, 1.12, 0.06),
		Vector3(0.0, 1.32, -0.08),
	]:
		_make_box(
			furniture,
			StringName("HallLeaf_%s" % str(offset)),
			Vector3(-1.55, 0.0, -1.25) + offset,
			Vector3(0.42, 0.18, 0.28),
			Color("5f956f")
		)

func _build_yard_details() -> void:
	_make_box(
		furniture,
		&"YardPlanter",
		Vector3(5.35, 0.28, -3.85),
		Vector3(2.3, 0.5, 0.72),
		Color("80604a")
	)
	for index in range(4):
		_make_box(
			furniture,
			StringName("YardShrub%02d" % (index + 1)),
			Vector3(4.55 + float(index) * 0.52, 0.72, -3.85),
			Vector3(0.38, 0.58 + float(index % 2) * 0.16, 0.38),
			Color("4f8a62")
		)

	_make_box(
		furniture,
		&"YardBenchSeat",
		Vector3(5.25, 0.42, -2.15),
		Vector3(2.2, 0.18, 0.62),
		Color("9a744f")
	)
	_make_box(
		furniture,
		&"YardBenchBack",
		Vector3(5.25, 0.86, -1.9),
		Vector3(2.2, 0.72, 0.16),
		Color("8a6748")
	)

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
