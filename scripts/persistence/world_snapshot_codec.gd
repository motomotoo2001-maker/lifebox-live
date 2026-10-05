class_name WorldSnapshotCodec
extends RefCounted

static func encode(world: SimulationWorld) -> Dictionary:
	if world == null:
		return {}
	return world.capture_persistence_state()

static func restore(
	world: SimulationWorld,
	snapshot: Dictionary
) -> Array[String]:
	if world == null:
		return ["destination world is required"]

	var errors: Array[String] = world.validate_persistence_state(snapshot)
	if not errors.is_empty():
		return errors

	if not world.restore_persistence_state(snapshot):
		return ["world restore failed after validation"]

	return []
