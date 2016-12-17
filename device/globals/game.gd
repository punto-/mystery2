var objects = {}
var res_cache

var game_size = Vector2()

var ui_layer
var hud_layer

var hud_stack = []
var ui_stack = []

var window_size = Vector2()

var current_scene

var vm

func register_object(name, val):
	objects[name] = val
	if name in vm.states:
		val.set_state(vm.states[name])
	else:
		val.set_state("default")
	if name in vm.actives:
		val.set_active(vm.actives[name])
	val.connect("exit_tree", self, "object_exit_scene", [name])

func get_object(name):
	if !(name in objects):
		return null

	return objects[name]

func object_exit_scene(name):
	objects.erase(name)

func say(params, level):
	get_node("speech_player").say(params, level)

func dialog(params, level):
	get_node("dialog_player").start(params, level)

func _process(time):
	check_screen()

func _input(event):
	if ui_stack.size() > 0:
		ui_stack[ui_stack.size()-1].input(event)

	elif hud_stack.size() > 0:
		hud_stack[hud_stack.size()-1].input(event)

	else:
		# give event to main character? or to current_scene?
		pass

func inventory_set(name, p_enabled):
	# maybe not necessary? it can be global flags
	pass

func change_scene(params, context):
	pass

func set_current_scene(p_scene):
	current_scene = p_scene

func check_screen():
	var vs = OS.get_video_mode_size()
	if vs == window_size:
		return
	window_size = vs

	var rate = float(vs.x)/float(vs.y)
	var height = int(game_size.x / rate)
	get_tree().get_root().set_size_override(true,Vector2(game_size.x,height))
	get_tree().get_root().set_size_override_stretch(true)

	var m = Matrix32()
	var ofs = Vector2(0, (height - game_size.y) / 2)
	m[2] = ofs
	get_tree().get_root().set_global_canvas_transform(m)

func add_hud(p_node):
	hud_stack.push_back(p_node)

func remove_hud(p_node):
	if hud_stack.size() == 0 || hud_stack[hud_stack.size()-1] != p_node:
		print("warning: removing node from hud which is not at the top ", p_node.get_path())

	hud_stack.erase(p_node)

func _ready():
	res_cache = preload("res://globals/resource_queue.gd").new()

	game_size = Vector2(Globals.get("display/game_width"), Globals.get("display/game_height"))

	vm = get_node("/root/vm")
	vm.game = self

	hud_layer = get_node("hud_layer")
	ui_layer = get_node("ui_layer")

	set_process(true)
	set_process_input(true)
