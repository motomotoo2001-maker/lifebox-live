extends RefCounted

const TIER_PATH := "res://scripts/simulation/fate/gift_tier_mapper.gd"
const CHAOS_PATH := "res://scripts/simulation/fate/chaos_meter.gd"
const COMMENT_PATH := "res://scripts/integrations/live/comment_command_parser.gd"

func run() -> Array[String]:
	var failures: Array[String] = []
	for path in [TIER_PATH, CHAOS_PATH, COMMENT_PATH]:
		if not FileAccess.file_exists(path):
			failures.append("missing live input primitive: %s" % path)
			return failures

	var tier_script = load(TIER_PATH)
	var chaos_script = load(CHAOS_PATH)
	var parser_script = load(COMMENT_PATH)
	for script in [tier_script, chaos_script, parser_script]:
		if script == null or not script.can_instantiate():
			failures.append("live input primitive must load")
			return failures

	_test_tiers(failures, tier_script)
	_test_chaos(failures, chaos_script)
	_test_comments(failures, parser_script)
	return failures

func _test_tiers(failures: Array[String], tier_script) -> void:
	var mapper = tier_script.new()
	var cases = [
		[0, 1, tier_script.TIER_MICRO],
		[9, 1, tier_script.TIER_MICRO],
		[10, 1, tier_script.TIER_SMALL],
		[49, 1, tier_script.TIER_SMALL],
		[50, 1, tier_script.TIER_MEDIUM],
		[199, 1, tier_script.TIER_MEDIUM],
		[200, 1, tier_script.TIER_LARGE],
		[999, 1, tier_script.TIER_LARGE],
		[1000, 1, tier_script.TIER_LEGENDARY],
		[5, 10, tier_script.TIER_MEDIUM],
	]
	for item in cases:
		if mapper.tier_for(item[0], item[1]) != item[2]:
			failures.append(
				"gift tier boundary mismatch for %s x %s"
				% [item[0], item[1]]
			)

	if mapper.effective_value(5, 10) != 50:
		failures.append("effective gift value must multiply repeat count")

	for invalid in [[-1, 1], [1, 0], [1, -1]]:
		if mapper.tier_for(invalid[0], invalid[1]) != &"":
			failures.append("invalid gift values must not map to a tier")

func _test_chaos(failures: Array[String], chaos_script) -> void:
	var meter = chaos_script.new()
	if not meter.add_likes(100):
		failures.append("positive like batch must apply")
	if not is_equal_approx(meter.value, 1.0):
		failures.append("100 likes must add exactly 1 chaos point")
	if meter.add_likes(0):
		failures.append("zero likes must be rejected")
	if not is_equal_approx(meter.value, 1.0):
		failures.append("rejected likes must not mutate chaos")
	if (
		not meter.apply_delta(200.0)
		or not is_equal_approx(meter.value, 100.0)
	):
		failures.append("chaos positive delta must clamp at 100")
	if (
		not meter.apply_delta(-30.0)
		or not is_equal_approx(meter.value, 70.0)
	):
		failures.append("chaos negative delta must apply")
	if meter.apply_delta(NAN):
		failures.append("NaN chaos delta must be rejected")
	if not is_equal_approx(meter.normalized(), 0.7):
		failures.append("normalized chaos must be 0..1")

	var state: Dictionary = meter.capture_state()
	var restored = chaos_script.new()
	if (
		not restored.restore_state(state)
		or restored.capture_state() != state
	):
		failures.append("chaos state must round-trip exactly")

func _test_comments(failures: Array[String], parser_script) -> void:
	var parser = parser_script.new()
	if parser.parse("!A") != parser_script.COMMAND_A:
		failures.append("!A must parse")
	if parser.parse("  !a  ") != parser_script.COMMAND_A:
		failures.append("!A parser must trim and ignore case")
	if parser.parse("!b") != parser_script.COMMAND_B:
		failures.append("!B must parse case-insensitively")

	for raw in ["", "hello", "!C", "!A please", "A"]:
		if parser.parse(raw) != parser_script.COMMAND_NONE:
			failures.append(
				"unknown comment command must parse as none: %s" % raw
			)
