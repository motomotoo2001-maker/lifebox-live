extends RefCounted

const SCENE_PATH := "res://scenes/world/household_blockout.tscn"
const SCRIPT_PATH := "res://scripts/presentation/world/household_blockout.gd"

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(SCENE_PATH):
		failures.append("Household blockout scene must exist at %s" % SCENE_PATH)
		return failures
	if not FileAccess.file_exists(SCRIPT_PATH):
		failures.append("Household blockout script must exist at %s" % SCRIPT_PATH)
		return failures

	var packed_scene = load(SCENE_PATH)
	if packed_scene == null:
		failures.append("Household blockout scene must load")
		return failures

	var root = packed_scene.instantiate()
	if root == null:
		failures.append("Household blockout scene must instantiate")
		return failures

	if not root is Node3D:
		failures.append("Household blockout root must be Node3D")

	if not root.has_node("NavigationRegion3D"):
		failures.append("Household blockout must contain NavigationRegion3D")
	else:
		var region = root.get_node("NavigationRegion3D")
		if not region is NavigationRegion3D:
			failures.append("NavigationRegion3D node must have NavigationRegion3D type")
		elif region.navigation_mesh == null:
			failures.append("NavigationRegion3D must have authored NavigationMesh")
		elif region.navigation_mesh.vertices.size() < 4:
			failures.append("NavigationMesh must contain navigable vertices")

	if root.has_method("_build_navigation_mesh_resource"):
		var authored_mesh: NavigationMesh = root._build_navigation_mesh_resource()
		if authored_mesh == null:
			failures.append("authored room navigation mesh must be created")
		else:
			if authored_mesh.vertices.size() < 40:
				failures.append("authored room navigation mesh needs room/hall vertices")
			if authored_mesh.get_polygon_count() < 30:
				failures.append("authored room navigation mesh needs multiple room/hall polygons")
			if root._navigation_cell_enabled(-2.8, -2.6, -4.8, -0.8):
				failures.append("vertical room wall strip must not be navigable")
			if not root._navigation_cell_enabled(-6.0, -4.8, -0.8, -0.6):
				failures.append("left doorway connector must be navigable")
			if root._navigation_cell_enabled(-4.8, -2.8, -0.8, -0.6):
				failures.append("solid hall wall segment must not be navigable")

	if not root.has_node("Floor"):
		failures.append("Household blockout must contain Floor")
	elif not root.get_node("Floor") is MeshInstance3D:
		failures.append("Floor must be MeshInstance3D")

	for visual_path in [
		"Visuals",
		"Visuals/RoomPads",
		"Visuals/Walls",
		"Visuals/Furniture",
	]:
		if not root.has_node(visual_path):
			failures.append("Household blockout missing visual container %s" % visual_path)

	for method_name in [
		"get_resident_spawn",
		"get_destination",
		"_configure_authored_navigation",
		"_build_navigation_mesh_resource",
		"_navigation_cell_enabled",
		"_build_walls",
		"_build_fridge",
		"_build_sofa",
		"_build_shower",
		"_build_bed",
		"_build_kitchen_details",
		"_build_living_details",
		"_build_bedroom_details",
		"_build_bathroom_details",
		"_build_hall_details",
		"_build_yard_details",
	]:
		if not root.has_method(method_name):
			failures.append("Household blockout must expose %s()" % method_name)

	if not root.has_node("Spawns"):
		failures.append("Household blockout must contain Spawns")
	else:
		var seen_positions: Dictionary = {}
		for index in range(1, 7):
			var path := "Spawns/ResidentSpawn%02d" % index
			if not root.has_node(path):
				failures.append("Missing %s" % path)
				continue
			var marker = root.get_node(path)
			if not marker is Marker3D:
				failures.append("%s must be Marker3D" % path)
				continue
			var key := str(marker.position)
			if seen_positions.has(key):
				failures.append("Resident spawn points must have unique positions")
			seen_positions[key] = true

	if not root.has_node("Destinations"):
		failures.append("Household blockout must contain Destinations")
	else:
		for name in [
			"Fridge",
			"Shower",
			"Sofa",
			"TV",
			"BathroomSink",
			"Bookshelf",
		]:
			var path := "Destinations/%s" % name
			if not root.has_node(path):
				failures.append("Missing household destination %s" % path)
			elif not root.get_node(path) is Marker3D:
				failures.append("%s must be Marker3D" % path)

		for index in range(1, 7):
			var bed_path := "Destinations/Bed%02d" % index
			if not root.has_node(bed_path):
				failures.append("Missing household destination %s" % bed_path)
			elif not root.get_node(bed_path) is Marker3D:
				failures.append("%s must be Marker3D" % bed_path)

	root.free()
	return failures
