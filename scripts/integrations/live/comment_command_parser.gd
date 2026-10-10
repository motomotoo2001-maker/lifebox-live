class_name CommentCommandParser
extends RefCounted

const COMMAND_NONE: StringName = &""
const COMMAND_A: StringName = &"A"
const COMMAND_B: StringName = &"B"

func parse(text: String) -> StringName:
	var normalized := text.strip_edges().to_upper()
	match normalized:
		"!A":
			return COMMAND_A
		"!B":
			return COMMAND_B
		_:
			return COMMAND_NONE
