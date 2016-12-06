var current_scene = null
var current_character = null
var interact_target = null
var current_target = null

var menu_stack = []

var objects = {}

var vm_size = Vector2()
var game_size

var inventory
var ui_layer

var game_state = {}

var screen_count = 0
var spawn_count = 0

var area_debug = true

var target_mode = false
var target_area = null
var target_sprite = null
var target_dir = Vector2()
var target_frames_wait = 0
const target_start_min = 0.4 * 0.4

var click_area = null
var target_mode_moved = false
var target_move_sq = 0.25 * 0.25
var target_mode_speed = 400

func _input(event):
	if menu_stack.size() > 0:
		return menu_stack[menu_stack.size()-1].input(event)

	if event.is_echo():
		return

	if event.type == InputEvent.MOUSE_MOTION:
		var pos = Vector2(event.global_x, event.global_y)
		if event.button_mask & BUTTON_MASK_RIGHT:
			target_mode = 0
			current_target = pos
		elif event.button_mask & BUTTON_MASK_LEFT:
			click_area.set_global_pos(pos)

	elif event.type == InputEvent.MOUSE_BUTTON:
		if event.button_index == BUTTON_LEFT:
			if event.pressed:
				click_area.show()
				click_area.set_global_pos(Vector2(event.global_x, event.global_y))
			else:
				click_area.hide()

	if event.is_pressed():
		if event.is_action("inventory_next"):
			inventory.item_move(1)
		elif event.is_action("inventory_prev"):
			inventory.item_move(-1)
		elif event.is_action("inventory_toggle"):
			inventory.toggle()

		elif event.is_action("item_use"):
			if current_character == null:
				return
			current_character.inventory_use()

		elif event.is_action("interact"):
			interact()

		elif event.is_action("targeting_toggle"):
			target_mode_start()

		elif event.is_action("area_debug_toggle"):
			area_debug = !area_debug
			get_tree().call_group(0, "char_debug", "set_enabled", area_debug)

	else:
		if event.is_action("targeting_toggle"):
			target_mode_end()
		pass

func _cur_target_pos():
	var pos
	if typeof(current_target) == TYPE_VECTOR2:
		return current_target
	if current_target != null:
		pos = current_target.get_global_pos()
	elif current_character != null:
		pos = current_character.get_global_pos()
	else:
		pos = game_size / 2

	return pos


func target_mode_start():
	target_mode = 0
	target_mode_moved = false


func target_mode_end():
	target_mode = 1
	if !target_mode_moved:
		current_target = null

func interact():
	if interact_target == null:
		return

	interact_target.interact(current_character)


func set_interact_target(p_obj):
	if p_obj != interact_target:
		if p_obj == null:
			print("******************** no target!")
		else:
			print("******************** new target ", p_obj.global_id)
	interact_target = p_obj

func change_scene(path, pos):
	var res = load(path)
	if res == null:
		print("warning: unable to load scene ", path)
		return

	var scene = res.instance()
	if scene == null:
		print("warning: unable to instance scene ", path)
		return

	printt("pos is ", pos)
	if pos != null && current_character != null:
		set_state(current_character, null, null)
		current_character.get_parent().remove_child(current_character)

	# todo: move to call deferred to be able to free before loading the next scene
	var root = get_node("/root")
	root.remove_child(current_scene)
	current_scene.free()

	set_current_target(null)

	screen_count += 1
	interact_target = null

	root.add_child(scene)

	printt("current character", current_character)
	if current_character != null:
		printt("got pos from _obj_pos", pos, _obj_pos(pos))
		pos = _obj_pos(pos)
		if pos != null :
			scene.get_node("ground").add_child(current_character)
			current_character.set_global_pos(pos)
	return

func _obj_pos(pos):
	if typeof(pos) == TYPE_STRING:
		var obj = get_object(pos)
		if obj == null:
			return null
		if obj.has_method("interact_pos"):
			return obj.interact_pos()
		elif obj.has_node("interact_pos"):
			return obj.get_node("interact_pos").get_global_pos()
		else:
			return obj.get_global_pos()
	else:
		return pos

func spawn(fname, pos, node_path = null):
	var res = load(fname)
	if res == null:
		print("warning: invalid resource spawn ", fname)
		return null
	var scene
	spawn_count += 1
	if node_path != null && has_node(node_path):
		scene = get_node(node_path)
		if !scene.is_type("InstancePlaceholder"):
			print("warning: can't spawn scene at path ", node_path, ", another scene already exists")
			return
		scene.set_global_pos(pos)
		scene.replace_by_instance(res)
	else:
		scene = res.instance()
		if scene == null:
			print("warning: invalid scene spawn ", fname)
			return null

		if current_scene == null:
			print("no current scene")
			return null

		if typeof(node_path) == TYPE_STRING:
			scene.set_name(node_path.get_file())
		elif typeof(node_path) == TYPE_NODE_PATH:
			scene.set_name(node_path.get_name(node_path.get_name_count() - 1))
		else:
			scene.set_name(scene.get_name() + "_" + str(spawn_count))

		scene.set_global_pos(pos)
		current_scene.get_node("ground").add_child(scene)

	scene.set_global_pos(pos)
	scene.last_angle = randf() * PI * 2

	current_scene.add_instance(scene)

	return scene

func restore_instance(path):
	var inst = get_state(path, "instance")
	printt("********* restoring instance ", path, inst.path)
	spawn(inst.path, inst.pos, path)

func despawn(obj_id):
	if !(obj_id in objects):
		return

	objects[obj_id].despawn()


func get_object(obj):
	if !(obj in objects):
		return null
	return objects[obj]

func get_objects():
	return objects

func check_screen():
	var vs = OS.get_video_mode_size()
	if vs == vm_size:
		return
	vm_size = vs

	var rate = float(vs.x)/float(vs.y)
	var height = int(game_size.x / rate)
	get_tree().get_root().set_size_override(true,Vector2(game_size.x,height))
	get_tree().get_root().set_size_override_stretch(true)

	var m = Matrix32()
	var ofs = Vector2(0, (height - game_size.y) / 2)
	m[2] = ofs
	get_tree().get_root().set_global_canvas_transform(m)

func add_attack(attack):
	current_scene.add_child(attack)

func _get_target_dir():
	return Vector2(Input.get_joy_axis(0, 2), Input.get_joy_axis(0, 3))

func _process(time):

	check_screen()

	if menu_stack.size() == 0 && current_character != null:

		var walk_dir = Vector2()
		if Input.is_action_pressed("walk_left"):
			walk_dir.x += -1
		if Input.is_action_pressed("walk_right"):
			walk_dir.x += 1
		if Input.is_action_pressed("walk_up"):
			walk_dir.y += -1
		if Input.is_action_pressed("walk_down"):
			walk_dir.y += 1

		var joy_walk_dir = Vector2(Input.get_joy_axis(0, 0), Input.get_joy_axis(0, 1))

		var dir_final = joy_walk_dir
		if joy_walk_dir.length_squared() < 0.01:
			dir_final = walk_dir

		current_character.set_walk_direction(dir_final)

	if target_mode == 0:
		var dir = _get_target_dir()
		var pos = _cur_target_pos()
		if dir.length_squared() > target_move_sq:
			target_mode_moved = true
			pos = pos + dir * target_mode_speed * time
			current_target = pos

func _fixed_process(time):
	_check_targets()

func _point_area():
	var tdir = _get_target_dir()
	target_area.show()
	target_area.set_global_pos(_cur_target_pos())
	printt("area pos ", _cur_target_pos())
	target_area.set_rot(tdir.angle())


func _check_bodies(list, apos):
	var dist = null
	var body = null
	for b in list:
		if !(b extends preload("res://game/character.gd")) || !b.can_target:
			continue
		if b == current_character:
			continue
		if typeof(current_target) == typeof(b) && b == current_target:
			continue
		var d = apos.distance_squared_to(b.get_global_pos())
		if dist == null || d < dist:
			dist = d
			body = b

	return body

func _check_targets():
	if target_mode == 0:
		pass
	elif target_mode == 2:
		var body = _check_bodies(target_area.get_overlapping_bodies(), target_area.get_global_pos())

		if body != null:
			set_current_target(body)
			target_area.hide()
			target_mode = 3
		else:
			var tdir = _get_target_dir()
			if tdir.length_squared() < target_start_min:
				target_area.hide()
				target_mode = 1
			else:
				_point_area()

	elif target_mode == 3:
		var tdir = _get_target_dir()
		if tdir.length_squared() < target_start_min:
			target_mode = 1
	elif target_mode == 1:
		var tdir = _get_target_dir()
		if tdir.length_squared() > target_start_min:
			target_area.show()
			target_mode = 2
			target_frames_wait = 2
			_point_area()

	if click_area.is_visible():
		var body = _check_bodies(click_area.get_overlapping_bodies(), click_area.get_global_pos())
		if body != null:
			set_current_target(body)
			click_area.hide()



func character_health_changed():
	get_node("hud_layer/hud").update_health(current_character)

func set_current_character(char):
	if current_character != null:
		current_character.disconnect("health_changed", self, "character_health_changed")
	print("setting current character")
	current_character = char
	if current_character != null:
		current_character.connect("health_changed", self, "character_health_changed")

func set_current_target(target):
	current_target = target

func set_scene(p_scene):
	printt("************ calling set scene")
	current_scene = p_scene

func emo_inc(obj, emo, val):
	if !(obj in objects):
		printt("warning: object not found", obj)
		return

	objects[obj].emo_inc(emo, val)

func add_interest_point(obj, point, prio, radius, ratio):
	if !(obj in objects):
		printt("warning: object not found", obj)
		return

	if !(point in objects):
		printt("warning: point not found", point)
		return

	objects[obj].add_interest_point(objects[point], prio, radius, ratio)

func set_parameter(obj, param, opr, value):
	if !(obj in objects):
		printt("warning: object not found", obj)
		return

	var cur = objects[obj]._get(param)
	var newval
	if opr == "=":
		newval = value
	elif opr == "+=":
		newval += value
	elif opr == "-=":
		newval -= value
	elif opr == "/=":
		newval /= value
	elif opr == "*=":
		newval *= value
	else:
		print("warning: invalid operator! ", opr)
		return

	objects[obj]._set(param, value)

func _has_Type(types, type):
	var p = types.find(type)
	if p < 0:
		return null

	# todo improve this?

	return type

func change_type(obj, opr, value):

	if !(obj in objects):
		printt("warning: object not found", obj)
		return

	var cur = objects[obj].mob_type
	var newval
	if opr == "=":
		newval = value
	elif opr == "+=":
		if _has_type(cur, value):
			return
		else:
			newval = cur + "," + value
	elif opr == "-=":
		var type_str = _has_type(cur, value)
		if type_str == null:
			return
		else:
			newval = cur.replace(type_str, "")
	else:
		print("warning: invalid operator! ", opr)
		return

	objects[obj].mob_type = newval

func move_to_range(context, obj, target, distance_min, distance_max, fov, time):

	if !(obj in objects):
		printt("warning: object not found for move_to_range", obj)
		return
	var tpos = target
	if typeof(target) == TYPE_STRING:
		if !(target in objects):
			printt("warning: target not found for move_to_range", target)
			return
		tpos = objects[target].get_global_pos()

	return objects[obj].move_to_range(context, target, distance_min, distance_max, fov, time)

func char_clicked(p_char):
	set_current_target(p_char)

func register_object(obj):
	objects[obj.global_id] = obj
	obj.connect("exit_tree", self, "object_exit_scene", [obj.global_id])

func object_exit_scene(name):
	objects.erase(name)

func get_state(obj, name):
	var path
	if typeof(obj) == TYPE_STRING || typeof(obj) == TYPE_NODE_PATH:
		path = str(obj)
	else:
		path = str(obj.get_path())

	if !(path in game_state):
		return null

	if name in game_state[path]:
		return game_state[path][name]

	return null

func set_state(obj, name, value):
	var path
	if typeof(obj) == TYPE_STRING || typeof(obj) == TYPE_NODE_PATH:
		path = str(obj)
	else:
		path = str(obj.get_path())

	if name == null:
		game_state.erase(path)
		return

	if !(path in game_state):
		game_state[path] = {}

	game_state[path][name] = value

func has_state(obj):
	var path
	if typeof(obj) == TYPE_STRING || typeof(obj) == TYPE_NODE_PATH:
		path = str(obj)
	else:
		path = str(obj.get_path())

	return (path in game_state)

func get_screen():
	return screen_count

func start_game():
	clear()
	var vm = get_node("/root/vm")
	var game = vm.compile("res://game/game.esc")
	vm.run_event(game.start, {})

func clear():
	screen_count = 0
	game_state = {}

func _setup_target_area():
	add_child(target_area)
	target_area.hide()

	add_child(click_area)
	click_area.hide()

func _ready():

	game_state = {}

	inventory = get_node("hud_layer/inventory")
	ui_layer = get_node("ui_layer")

	game_size = Vector2()
	game_size.x = Globals.get("display/game_width")
	game_size.y = Globals.get("display/game_height")

	set_process_input(true)
	set_process(true)
	set_fixed_process(true)

	target_area = preload("res://game/target_area.tscn").instance()
	click_area = preload("res://game/click_area.tscn").instance()
	target_mode = 1
	call_deferred("_setup_target_area")

	call_deferred("start_game")
