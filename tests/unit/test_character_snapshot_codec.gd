extends RefCounted

const CODEC_PATH := "res://scripts/persistence/character_snapshot_codec.gd"
const CHARACTER_PATH := "res://scripts/simulation/characters/character_state.gd"
const MEMORY_EVENT_PATH := "res://scripts/simulation/memory/memory_event.gd"
const JOB_DEFINITION_PATH := "res://scripts/simulation/economy/job_definition.gd"

const NEED_NAMES: Array[String] = [
	"hunger", "energy", "hygiene", "comfort", "social", "mood",
]
const TRAIT_NAMES: Array[String] = [
	"sociability", "neatness", "ambition", "kindness",
	"impulsiveness", "confidence", "humor", "jealousy",
]

func run() -> Array[String]:
	var failures: Array[String] = []

	if not FileAccess.file_exists(CODEC_PATH):
		failures.append("CharacterSnapshotCodec must exist at %s" % CODEC_PATH)
		return failures

	var codec_script := load(CODEC_PATH)
	var character_script := load(CHARACTER_PATH)
	var memory_event_script := load(MEMORY_EVENT_PATH)
	var job_definition_script := load(JOB_DEFINITION_PATH)
	if (
		codec_script == null
		or character_script == null
		or memory_event_script == null
		or job_definition_script == null
	):
		failures.append("character snapshot dependencies must load")
		return failures

	var source = character_script.new(&"resident_save", "Resident Save")
	source.money = 123.5
	source.current_action_id = &"eat"
	source.movement.status = &"moving"

	var need_index := 0
	for need_name in NEED_NAMES:
		var need_state = source.needs.get(need_name)
		need_state.value = 10.0 + float(need_index * 7)
		need_state.decay_per_sim_hour = 1.5 + float(need_index)
		need_index += 1

	var trait_index := 0
	for trait_name in TRAIT_NAMES:
		source.personality.set(trait_name, 0.1 + float(trait_index) * 0.1)
		trait_index += 1

	source.memory.capacity = 5
	source.memory.add(memory_event_script.new(
		&"memory_a",
		&"compliment",
		42.0,
		[&"resident_other"],
		0.75,
		0.8
	))
	source.memory.add(memory_event_script.new(
		&"memory_b",
		&"argue",
		84.0,
		[&"resident_other_2"],
		-0.5,
		0.6
	))

	var job = job_definition_script.new()
	job.id = &"clerk"
	job.pay_per_sim_hour = 18.5
	job.shift_start_hour = 9.0
	job.shift_duration_hours = 8.0
	source.job.assign(job)
	source.job.total_worked_sim_seconds = 5432.0

	var encoded: Dictionary = codec_script.encode(source)
	if not _is_json_compatible(encoded):
		failures.append("encoded resident snapshot must contain JSON-compatible values only")

	var errors: Array[String] = codec_script.validate(encoded)
	if not errors.is_empty():
		failures.append("valid encoded resident must pass validation: %s" % " | ".join(errors))
		return failures

	var decoded = codec_script.decode_stable_state(encoded)
	if decoded == null:
		failures.append("valid resident snapshot must decode")
		return failures

	if decoded.id != source.id:
		failures.append("resident id must round-trip")
	if decoded.display_name != source.display_name:
		failures.append("display name must round-trip")
	if not is_equal_approx(decoded.money, source.money):
		failures.append("resident money must round-trip")

	for need_name in NEED_NAMES:
		var expected = source.needs.get(need_name)
		var actual = decoded.needs.get(need_name)
		if not is_equal_approx(actual.value, expected.value):
			failures.append("need value must round-trip: %s" % need_name)
		if not is_equal_approx(actual.decay_per_sim_hour, expected.decay_per_sim_hour):
			failures.append("need decay must round-trip: %s" % need_name)

	for trait_name in TRAIT_NAMES:
		var expected_trait: float = source.personality.get(trait_name)
		var actual_trait: float = decoded.personality.get(trait_name)
		if not is_equal_approx(actual_trait, expected_trait):
			failures.append("personality trait must round-trip: %s" % trait_name)

	if decoded.memory.capacity != 5:
		failures.append("memory capacity must round-trip")
	if decoded.memory.size() != 2:
		failures.append("memory events must round-trip")
	else:
		var memory_a = decoded.memory.get_event(&"memory_a")
		var memory_b = decoded.memory.get_event(&"memory_b")
		if memory_a == null or memory_b == null:
			failures.append("memory event ids must round-trip")
		else:
			if memory_a.kind != &"compliment":
				failures.append("memory kind must round-trip")
			if memory_a.related_resident_ids != [&"resident_other"]:
				failures.append("memory related resident ids must round-trip")
			if not is_equal_approx(memory_a.valence, 0.75):
				failures.append("memory valence must round-trip")
			if not is_equal_approx(memory_b.importance, 0.6):
				failures.append("memory importance must round-trip")

	if decoded.job.definition == null:
		failures.append("assigned job definition must round-trip")
	else:
		if decoded.job.definition.id != &"clerk":
			failures.append("job id must round-trip")
		if not is_equal_approx(decoded.job.definition.pay_per_sim_hour, 18.5):
			failures.append("job pay must round-trip")
		if not is_equal_approx(decoded.job.definition.shift_start_hour, 9.0):
			failures.append("job shift start must round-trip")
		if not is_equal_approx(decoded.job.definition.shift_duration_hours, 8.0):
			failures.append("job shift duration must round-trip")
	if not is_equal_approx(decoded.job.total_worked_sim_seconds, 5432.0):
		failures.append("job worked seconds must round-trip")

	if decoded.current_action_id != &"idle":
		failures.append("stable resident codec must intentionally exclude current action")
	if decoded.movement.status != &"idle" or decoded.movement.intent != null:
		failures.append("stable resident codec must intentionally exclude movement runtime state")

	var encoded_copy := encoded.duplicate(true)
	codec_script.validate(encoded)
	if encoded != encoded_copy:
		failures.append("CharacterSnapshotCodec.validate() must not mutate input")

	_test_invalid_cases(failures, codec_script, encoded)

	return failures

func _test_invalid_cases(
	failures: Array[String],
	codec_script,
	valid_encoded: Dictionary
) -> void:
	var empty_id := valid_encoded.duplicate(true)
	empty_id["id"] = ""
	if codec_script.validate(empty_id).is_empty():
		failures.append("empty resident id must fail validation")

	var negative_money := valid_encoded.duplicate(true)
	negative_money["money"] = -1.0
	if codec_script.validate(negative_money).is_empty():
		failures.append("negative resident money must fail validation")

	var nan_money := valid_encoded.duplicate(true)
	nan_money["money"] = NAN
	if codec_script.validate(nan_money).is_empty():
		failures.append("non-finite resident money must fail validation")

	var over_capacity := valid_encoded.duplicate(true)
	over_capacity["memory"]["capacity"] = 1
	if codec_script.validate(over_capacity).is_empty():
		failures.append("memory event count above capacity must fail validation")

	var duplicate_memory := valid_encoded.duplicate(true)
	var first_memory: Dictionary = duplicate_memory["memory"]["events"][0].duplicate(true)
	duplicate_memory["memory"]["events"].append(first_memory)
	duplicate_memory["memory"]["capacity"] = 10
	if codec_script.validate(duplicate_memory).is_empty():
		failures.append("duplicate memory event ids must fail validation")

	var bad_need := valid_encoded.duplicate(true)
	bad_need["needs"]["hunger"]["value"] = 500.0
	if codec_script.validate(bad_need).is_empty():
		failures.append("need value outside 0..100 must fail validation")

	var bad_trait := valid_encoded.duplicate(true)
	bad_trait["personality"]["kindness"] = 5.0
	if codec_script.validate(bad_trait).is_empty():
		failures.append("personality trait outside 0..1 must fail validation")

	var bad_job := valid_encoded.duplicate(true)
	bad_job["job"]["definition"]["pay_per_sim_hour"] = -1.0
	if codec_script.validate(bad_job).is_empty():
		failures.append("negative job pay must fail validation")

func _is_json_compatible(value) -> bool:
	if value == null:
		return true
	if value is String or value is bool or value is int or value is float:
		return true
	if value is Array:
		for item in value:
			if not _is_json_compatible(item):
				return false
		return true
	if value is Dictionary:
		for key in value.keys():
			if not key is String:
				return false
			if not _is_json_compatible(value[key]):
				return false
		return true
	return false
