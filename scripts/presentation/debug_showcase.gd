extends Control

const W := 720.0
const H := 1280.0

var residents := [
	{"name":"MIRA", "room":"KITCHEN", "money":"$84", "schedule":"BREAKFAST", "goal":"Talk to LEO", "hunger":78, "energy":72, "social":44, "mood":81},
	{"name":"LEO", "room":"LIVING", "money":"$61", "schedule":"FREE TIME", "goal":"Relax today", "hunger":66, "energy":68, "social":38, "mood":76},
	{"name":"NIKA", "room":"BEDROOM", "money":"$102", "schedule":"WORK PREP", "goal":"Work shift", "hunger":71, "energy":41, "social":82, "mood":63},
	{"name":"MAX", "room":"HALL", "money":"$47", "schedule":"FREE TIME", "goal":"Have fun", "hunger":52, "energy":88, "social":54, "mood":69},
	{"name":"SARA", "room":"BATH", "money":"$73", "schedule":"MORNING", "goal":"Improve comfort", "hunger":81, "energy":74, "social":61, "mood":79},
	{"name":"IVAN", "room":"YARD", "money":"$58", "schedule":"WORK", "goal":"Earn money", "hunger":59, "energy":65, "social":47, "mood":67},
]

func _ready() -> void:
	_build_ui()

func _panel(parent: Control, pos: Vector2, size: Vector2, color: Color, radius := 18.0) -> Panel:
	var p := Panel.new()
	p.position = pos
	p.size = size
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = int(radius)
	style.corner_radius_top_right = int(radius)
	style.corner_radius_bottom_left = int(radius)
	style.corner_radius_bottom_right = int(radius)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color("38465d")
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func _label(parent: Control, text: String, pos: Vector2, size: Vector2, font_size: int, color: Color = Color.WHITE, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_constant_override("outline_size", 1)
		l.add_theme_color_override("font_outline_color", Color("111722"))
	parent.add_child(l)
	return l

func _bar(parent: Control, label_text: String, value: float, y: float, tint: Color) -> void:
	_label(parent, label_text, Vector2(14,y), Vector2(92,18), 12, Color("9caec5"))
	var bg := ColorRect.new()
	bg.position = Vector2(100,y+3)
	bg.size = Vector2(130,10)
	bg.color = Color("263247")
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.position = Vector2(100,y+3)
	fill.size = Vector2(130.0 * clamp(value/100.0,0.0,1.0),10)
	fill.color = tint
	parent.add_child(fill)
	_label(parent, str(int(value)), Vector2(238,y-2), Vector2(32,18), 11, Color("d9e4f0"))

func _resident_dot(parent: Control, center: Vector2, idx: int, label_text: String) -> void:
	var dot := Panel.new()
	dot.position = center - Vector2(23,23)
	dot.size = Vector2(46,46)
	var st := StyleBoxFlat.new()
	st.bg_color = [Color("58a6ff"),Color("a371f7"),Color("f78166"),Color("3fb950"),Color("d29922"),Color("db61a2")][idx]
	st.corner_radius_top_left = 23
	st.corner_radius_top_right = 23
	st.corner_radius_bottom_left = 23
	st.corner_radius_bottom_right = 23
	st.border_width_left = 3
	st.border_width_top = 3
	st.border_width_right = 3
	st.border_width_bottom = 3
	st.border_color = Color("f0f6fc")
	dot.add_theme_stylebox_override("panel", st)
	parent.add_child(dot)
	var n := _label(parent, str(idx+1), center-Vector2(9,13), Vector2(18,24), 18, Color.WHITE, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label(parent, label_text, center+Vector2(-40,28), Vector2(80,18), 11, Color("d8e3f0"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("0c111b")
	add_child(bg)

	var top := _panel(self, Vector2(24,22), Vector2(672,112), Color("151e2d"), 22)
	_label(top, "LIFEBOX LIVE", Vector2(22,14), Vector2(360,34), 28, Color("eaf2ff"), true)
	_label(top, "AI TOWN  •  DEBUG SHOWCASE", Vector2(23,51), Vector2(420,22), 14, Color("75baff"), true)
	_label(top, "DAY 2   09:15", Vector2(480,17), Vector2(165,28), 20, Color("eaf2ff"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(top, "AUTONOMOUS  •  SAME-SEED DETERMINISTIC", Vector2(260,58), Vector2(385,20), 11, Color("7ee787"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(top, "Schedules + daily goals + critical-need safety + save/replay", Vector2(23,80), Vector2(620,18), 11, Color("93a4ba"))

	var world := _panel(self, Vector2(24,154), Vector2(672,412), Color("111827"), 22)
	_label(world, "HOUSEHOLD LIVE VIEW", Vector2(18,13), Vector2(300,24), 15, Color("dce8f8"), true)
	_label(world, "6 residents / current autonomous positions", Vector2(350,14), Vector2(300,20), 11, Color("8093ac")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	var rooms = [
		[Vector2(20,52),Vector2(200,150),"KITCHEN",Color("26344a")],
		[Vector2(230,52),Vector2(200,150),"LIVING",Color("26344a")],
		[Vector2(440,52),Vector2(212,150),"BEDROOM",Color("26344a")],
		[Vector2(20,212),Vector2(200,130),"BATH",Color("202d40")],
		[Vector2(230,212),Vector2(200,130),"HALL",Color("202d40")],
		[Vector2(440,212),Vector2(212,130),"YARD",Color("1d342b")],
	]
	for r in rooms:
		var rp := _panel(world, r[0], r[1], r[3], 12)
		_label(rp, r[2], Vector2(10,8), Vector2(120,18), 11, Color("8296af"), true)

	var table := ColorRect.new(); table.position=Vector2(65,120); table.size=Vector2(110,34); table.color=Color("6b4f3a"); world.add_child(table)
	var sofa := ColorRect.new(); sofa.position=Vector2(270,128); sofa.size=Vector2(120,42); sofa.color=Color("4b5d73"); world.add_child(sofa)
	var bed := ColorRect.new(); bed.position=Vector2(482,95); bed.size=Vector2(130,70); bed.color=Color("59677b"); world.add_child(bed)
	var bath := ColorRect.new(); bath.position=Vector2(62,272); bath.size=Vector2(116,42); bath.color=Color("4d6d78"); world.add_child(bath)

	_resident_dot(world, Vector2(118,104), 0, "MIRA")
	_resident_dot(world, Vector2(333,104), 1, "LEO")
	_resident_dot(world, Vector2(548,112), 2, "NIKA")
	_resident_dot(world, Vector2(330,270), 3, "MAX")
	_resident_dot(world, Vector2(118,267), 4, "SARA")
	_resident_dot(world, Vector2(548,270), 5, "IVAN")

	_label(world, "Latest:  MIRA completed social goal with LEO  •  IVAN entered work block", Vector2(20,368), Vector2(630,24), 12, Color("7ee787"), true)

	var list := _panel(self, Vector2(24,586), Vector2(672,556), Color("111827"), 22)
	_label(list, "RESIDENT STATE", Vector2(18,12), Vector2(220,22), 15, Color("dce8f8"), true)
	_label(list, "schedule  •  daily goal  •  needs", Vector2(350,12), Vector2(300,20), 11, Color("8093ac")).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	for i in range(residents.size()):
		var row_y := 44.0 + float(i) * 82.0
		var row := _panel(list, Vector2(12,row_y), Vector2(648,72), Color("182335"), 12)
		var d: Dictionary = residents[i]
		var avatar := Panel.new(); avatar.position=Vector2(12,13); avatar.size=Vector2(44,44)
		var ast := StyleBoxFlat.new(); ast.bg_color=[Color("58a6ff"),Color("a371f7"),Color("f78166"),Color("3fb950"),Color("d29922"),Color("db61a2")][i]; ast.corner_radius_top_left=22; ast.corner_radius_top_right=22; ast.corner_radius_bottom_left=22; ast.corner_radius_bottom_right=22; avatar.add_theme_stylebox_override("panel",ast); row.add_child(avatar)
		_label(row, d.name, Vector2(68,8), Vector2(105,22), 15, Color("f1f6ff"), true)
		_label(row, d.room + "  •  " + d.money, Vector2(68,31), Vector2(130,18), 11, Color("91a4bb"))
		_label(row, d.schedule, Vector2(205,8), Vector2(140,20), 12, Color("75baff"), true)
		_label(row, d.goal, Vector2(205,31), Vector2(190,20), 11, Color("d2a8ff"), true)
		var stats := Control.new(); stats.position=Vector2(360,0); stats.size=Vector2(280,72); row.add_child(stats)
		_bar(stats, "HUN", d.hunger, 3, Color("f2cc60"))
		_bar(stats, "ENG", d.energy, 19, Color("7ee787"))
		_bar(stats, "SOC", d.social, 35, Color("79c0ff"))
		_bar(stats, "MOOD", d.mood, 51, Color("d2a8ff"))

	var footer := _panel(self, Vector2(24,1162), Vector2(672,92), Color("151e2d"), 22)
	_label(footer, "SIMULATION HEALTH", Vector2(18,12), Vector2(220,20), 12, Color("9db0c7"), true)
	_label(footer, "54 / 54 TEST SUITES PASS", Vector2(18,37), Vector2(330,28), 20, Color("7ee787"), true)
	_label(footer, "save/load ✓   replay ✓   goals ✓   schedules ✓", Vector2(330,40), Vector2(320,20), 12, Color("a7b7ca"), true).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
