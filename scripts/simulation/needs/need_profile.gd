class_name NeedProfile
extends RefCounted

const NeedStateScript = preload("res://scripts/simulation/needs/need_state.gd")

var hunger = NeedStateScript.new(100.0, 12.0)
var energy = NeedStateScript.new(100.0, 8.0)
var hygiene = NeedStateScript.new(100.0, 4.0)
var comfort = NeedStateScript.new(100.0, 3.0)
var social = NeedStateScript.new(100.0, 5.0)
var mood = NeedStateScript.new(100.0, 2.0)
