class_name EventBus
extends RefCounted

signal simulation_event(topic: StringName, payload: Dictionary)

func publish(topic: StringName, payload: Dictionary = {}) -> void:
	simulation_event.emit(topic, payload)
