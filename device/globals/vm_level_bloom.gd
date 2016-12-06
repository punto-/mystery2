var global = null
var vm
var current_context

var vm_debug_pause_pending = true

var jump_exceptions = {

}

func check_char(name, cmd):
	var char = vm.get_character(name)
	if char == null:
		vm.report_errors("", ["Global character id "+name+" not found for " + cmd])
		return false
	return true

func check_obj(name, cmd):
	var obj = vm.game.get_object(name)
	if obj == null:
		vm.report_errors("", ["Global id "+name+" not found for " + cmd])
		return false
	return true

func _walk(char, pos, block):
	if char == "-1":
		char = vm.current_character.char_id
	if !check_char(char, "walk"):
		return vm.state_return
	var act = null

	if vm.tasks[vm.task_current].skipped:
		vm.get_character(char).teleport_pos(pos)
		return vm.state_return

	if block:
		current_context.waiting = true
		current_context.wait_reason = "walk"
		act = ["context", current_context]

	var ichar = vm.get_character(char)
	if ichar.get_parent() == null:
		print("****** character with no parent")
		vm.current_scene.add_child(ichar)

	ichar.walk_to(pos, act)

	if block && current_context.waiting:
		return vm.state_yield
	else:
		return vm.state_return


### commands

func set_global(params):
	vm.set_global(params[0], params[1])
	return vm.state_return

func set_value(params):
	vm.set_value(params[0], params[1], params[2])
	return vm.state_return

func set_random_value(params):
	vm.set_random_value(params[0], params[1], params[2])
	return vm.state_return

func debug(params):
	for p in params:
		printraw(p)
	printraw("\n")
	return vm.state_return

func anim(params):
	if !check_obj(params[0], "anim"):
		return vm.state_return
	var obj = vm.game.get_object(params[0])
	obj.play_animation(current_context, params[1], true, false)
	return vm.state_return

func set_state(params):
	var obj = vm.game.get_object(params[0])
	if obj != null:
		obj.set_state(params[1])
	vm.set_state(params[0], params[1])
	return vm.state_return

func say(params):
	if vm.tasks[vm.task_current].skipped:
		return vm.state_return
	current_context.waiting = true
	current_context.wait_reason = "say"
	return vm.say(params, current_context)

func show_text(params):
	if vm.tasks[vm.task_current].skipped:
		return vm.state_return
	var err = vm.show_text(params, current_context)

	if params[4] || err != OK:
		return vm.state_return
	else:
		current_context.waiting = true
		current_context.wait_reason = "show_text"
		return vm.state_yield

func dialog(params):
	vm.cancel_skip()
	current_context.waiting = true
	current_context.wait_reason = "dialog"
	return vm.dialog(params, current_context)

func cut_scene(params):
	if !check_obj(params[0], "cut_scene"):
		return vm.state_return
	var obj = vm.game.get_object(params[0])
	current_context.waiting = true
	current_context.wait_reason = "cut_scene"
	obj.play_animation(current_context, params[1], true, false)
	return vm.state_yield

func animation(params):
	# paramters id, play (stop if false), play reversed, block execution
	return vm.play_animation(params[0], params[1], params[2], params[3], current_context)

func wait_on_animation(params):
	if vm.tasks[vm.task_current].skipped:
		return vm.state_return
	var name = params[0]
	var obj = null
	if name in vm.character_animations:
		obj = vm.get_character(vm.character_animations[name])
	elif name in vm.obj_animations:
		obj = vm.game.get_object(vm.obj_animations[name])
	if obj == null:
		vm.report_errors("", ["Owner object not found for animation "+name])
		return vm.state_return
	var waiting = obj.wait_on_animation(name, current_context)
	if waiting:
		current_context.waiting = true
		current_context.wait_reason = "wait_on_animation "+name
		return vm.state_yield
	else:
		current_context.waiting = false
		return vm.state_return

func wait_on_character(params):
	if vm.tasks[vm.task_current].skipped:
		return vm.state_return

	var char = params[0]
	if char == "-1":
		char = vm.current_character.char_id

	var obj = vm.get_character(char)
	if obj == null:
		vm.report_errors("", ["Character not found for wait_on_character "+char])
		return vm.state_return

	if !obj.get_parent():
		vm.report_errors("", ["Character not on scene wait_on_character "+char])
		return vm.state_return

	var ret = obj.wait_on_walk(["context", current_context])
	if ret:
		printt("wait on walk successfull, yielding")
		current_context.waiting = true
		return vm.state_yield
	else:
		return vm.state_return

	return vm.wait_on_character(char)

func branch(params):
	return vm.add_level(params, false, current_context.task)

func branch_else(params):
	return vm.add_level(params, false, current_context.task)

func inventory_add(params):
	vm.inventory_set(params[0], true)
	return vm.state_return

func inventory_remove(params):
	vm.inventory_set(params[0], false)
	return vm.state_return

func inventory_clear(params):
	vm.inventory_clear()
	return vm.state_return

func set_active(params):
	var obj = vm.game.get_object(params[0])
	if obj != null:
		obj.set_active(params[1])
	vm.set_active(params[0], params[1])
	return vm.state_return

func stop(params):
	return vm.state_break

func repeat(params):
	return vm.state_repeat

func wait(params):
	return vm.wait(params[0], current_context)

func teleport(params):
	vm.teleport(params)
	return vm.state_return

func align_character(params):
	vm.align_character(params[0], int(params[1]))
	return vm.state_return

func teleport_pos(params):
	if !check_obj(params[0], "teleport_pos"):
		return vm.state_return
	vm.game.get_object(params[0]).teleport_pos(int(params[1]), int(params[2]))
	return vm.state_return

func walk_xy(params):
	return _walk(params[0], Vector2(int(params[1]), int(params[2])), params[3])

func walk_obj(params):
	if !check_obj(params[1], "walk_obj"):
		return vm.state_return
	var obj = vm.game.get_object(params[1])
	var pos = obj.get_interact_pos()

	return _walk(params[0], pos, params[2])

func walk_block(params):
	return _walk(params, true)

func change_scene(params):
	var path = params[0]
	var pos = null
	if params.size() > 1:
		if vm.compiler._is_numeric(params[1]):
			var pos_x = params[1]
			var pos_y = params[2]
			pos = Vector2(pos_x, pos_y)
		else:
			pos = params[1]

	return vm.game.change_scene(path, pos)

func load_character_scene(params):
	vm.call_deferred("load_character_scene", params, current_context)
	current_context.waiting = true
	current_context.wait_reason = "load_character_scene"
	return vm.state_yield

func preload_resource(params):
	var path = params[0]
	var do_load = params[1]
	var cache = params[2]
	if do_load:
		vm.res_cache.queue_resource(path, cache)
	else:
		vm.res_cache.unload_resource(path)

func spawn(params):
	var path = params[0]
	var pos_x = params[1]
	var pos_y = params[2]

	vm.game.spawn(path, Vector2(pos_x, pos_y))

func jump(params):
	print("****************** attempted to jump", vm.tasks[vm.task_current].id)
	if !(vm.tasks[vm.task_current].id in jump_exceptions):
		print({}.a)
	return vm.state_return
#	vm.jump(params[0])
#	return vm.state_jump

func dialog_config(params):
	vm.dialog_config(params)
	return vm.state_return

func call_action(params):
	print("calling action ", params)
	if params[0] == "-1":
		return
	vm.start_action(params[0])

func stack_action(params):
	printt("stacking action ", _unpack(params), vm.get_tree().get_frame())
	vm.stack_action(params[0])

func stop_event(params):
	print("stopping action ", params)
	vm.stop_event(params[0])

func set_cutscene_mode(params):
	printt("setting cutscene mode from ", vm.tasks[vm.task_current].id, params[0], vm.get_tree().get_frame())
	vm.set_cutscene_mode(params[0])

func set_cutscene_mode_stack(params):
	printt("setting cutscene mode stack from ", vm.tasks[vm.task_current].id, params[0], vm.get_tree().get_frame())
	vm.set_csm_stack(params[0])

func change_character(params):
	return vm.change_character(params[0], params[1], current_context)

func change_character_scene(params):
	return vm.change_character_scene(params, current_context)

func set_obj_visibility(params):
	var obj_id = params[0]
	var opacity = float(params[1]) / 100.0
	var time = float(params[2])

	vm.set_obj_visibility(obj_id, opacity, time)

	return vm.state_return

func set_character_visibility(params):
	var char_id = params[0]
	var opacity = float(params[1]) / 100.0
	var time = float(params[2])
	printt("set char_visibility ", char_id, opacity, time)

	vm.set_char_visibility(char_id, opacity, time)

	return vm.state_return

func set_char_pos(params):
	var char_id = params[0]
	var scene_id = params[1]
	var x = int(params[2])
	var y = int(params[3])

	vm.set_char_pos(char_id, scene_id, x, y)

	return vm.state_return

func change_waysystem(params):
	var ws = params[0]
	var scene = params[1]
	printt("**************************************** change waysystem ", ws)
	vm.change_waysystem(ws, scene)
	return vm.state_return

func custom(params):
	var node = vm.get_node(params[0])
	if node == null:
		vm.report_errors("", ["Node not found for custom: "+params[0]])

	if params.size() > 2:
		node.call(params[1], params)
	else:
		node.call(params[1])

func cache_animation(params):
	var id = params[0]
	var do_load = params[1]
	var priority = true
	if params.size() > 2:
		priority = params[2]
	if do_load:
		vm.load_animation(id, true, priority)
		pass
	else:
		vm.unload_animation(id)

func cache_animation_priority(params):
	return cache_animation([params[0], params[1], true])

func cache_character(params):
	var id = params[0]
	var do_load = params[1]
	vm.cache_character(id, do_load)

func set_tool(params):
	var id = params[0]
	var drag = params[1]
	vm.set_tool(id, true, drag)

func scroll_scene(params):
	if !check_obj(params[0], "scroll_scene"):
		return vm.state_return
	var obj = vm.get_object(params[0])
	var pos = obj.get_interact_pos()

	vm.scroll_scene(pos)

func scroll_scene_xy(params):
	#printt("******* scroll scene to ", params)
	var x = params[0]
	var y = params[1]
	var scene = params[2]
	vm.scroll_scene(Vector2(x, y), scene)

func set_scroll_character(params):
	var char = params[0]
	var scroll = params[1]
	var scene = params[2]
	vm.set_scroll_character(char, scroll, scene)

func play_sound(params):
	var file = params[0]
	var volume = float(params[1]) / 100.0
	var balance = float(params[2]) / 100.0
	var scene_stop = params[3]
	var loop = params[4]
	vm.sound.play_sound(file, volume * vm.sfx_volume * Globals.get("game/max_sfx_volume"), balance, loop, null)
	pass

func stop_sound(params):
	var file = params[0]
	vm.sound.stop_sound_path(file)

func set_bg_music(params):
	var scene = params[0]
	var path = params[1]
	var volume = float(params[2]) / 100.0
	var balance = float(params[3]) / 100.0
	vm.set_bg_music(scene, path, volume, balance)

func set_lightmap(params):
	var scene = params[0]
	var path = params[1]
	vm.set_lightmap(scene, path)

func set_cursor_visibility(params):
	pass

func change_outfit(params):
	var outfit = params[0]
	var unload = params[1]
	vm.change_outfit(outfit, unload)

func clear_outfits(params):
	var char_id = params[0]
	vm.clear_outfits(char_id)

func set_brightness(params):
	pass

func play_video(params):
	var path = params[0]
	var scale = params[1]
	var sounds = params[2]
	return vm.play_video(path, scale, sounds, current_context)

func execute_script(params):
	var id = params[0]
	pass

func change_walking_sound(params):
	var char_id = params[0]
	var path = params[1]
	vm.change_walking_sound(char_id, path)

func set_tasks(params):
	var tasks = Marshalls.base64_to_variant(params[0])
	vm.set_tasks(tasks)

func set_anim_state(params):
	var obj = params[0]
	var anim = params[1]
	vm.set_obj_animation(obj, anim)
	if vm.get_object(obj) != null:
		vm.get_object(obj).play_anim(anim, true, false, false, null)

func earthquake(params):
	var start = params[0]
	var force = params[1]
	var speed = params[2] / 1000.0
	vm.earthquake(start, force, speed)

func stop_character(params):
	printt("stopping character ", params)
	var char = params[0]
	if char == "-1":
		char = vm.current_character.char_id
	if !check_char(char, "stop_character"):
		return vm.state_return

	var ichar = vm.get_character(char)
	ichar.stop_character()


func yield_esc(params):
	return vm.state_yield

func show_obj_text(params):
	var obj = params[0]
	var text = params[1]
	var x = params[2]
	var y = params[3]
	var align = params[4]
	vm.show_obj_text(obj, text, Vector2(x, y), align)

func hide_obj_text(params):
	var obj = params[0]
	vm.hide_obj_text(obj)

func award_achievement(params):
	var aid = params[0]
	vm.award_achievement(aid)

func call_script(params):
	var sid = params[0]
	var fname = ""
	if params.size() > 1:
		fname = params[1]
	vm.call_script(sid, fname)

func inventory_item_set_name(params):
	vm.inventory_change_name(params[0], params[1])

func inventory_item_set_icons(params):
	vm.inventory_change_icon(params[0], params[1])

func emo_inc(params):
	var obj = params[0]
	var emo = params[1]
	var val = params[2]

	vm.game.emo_inc(obj, emo, val)

func add_interest_point(params):
	var obj = params[0]
	var point = params[1]
	var prio = params[2]
	var rad = 0
	var ratio = 1
	if params.size() > 3:
		rad = float(params[3])
	if params.size() > 4:
		ratio = float(params[4])
	vm.game.add_interest_point(obj, point, prio, rad, ratio)

func set_param(params):
	var obj = params[0]
	var param = params[1]
	var opr = params[2]
	var value = float(params[3])
	vm.game.set_parameter(obj, value, opr, value)

func change_type(params):
	var obj = params[0]
	var opr = params[1]
	var type = params[2]
	vm.game.chaneg_type(obj, opr, type)

func move_to_range(params):
	var obj = params[0]
	var target = params[1]
	var distance_min = params[2]
	var distance_max = params[3]
	var fov = params[4]
	var time = params[5]

	return vm.game.move_to_range(current_context, obj, target, distance_min, distance_max, fov, time)

func face(params):
	if !check_obj(params[0], "face"):
		print("warning: object not found for face ", params[0])
	if !check_obj(params[1], "face"):
		print("warning: target not found for face ", params[1])

	var obj = vm.game.get_object(params[0])
	var target = vm.game.get_object(params[1])

	obj.face(target)


func spawn_attack(params):
	if !check_obj(params[0], "spawn_attack"):
		print("warning: object not found for attack source ", params[0])
		return vm.state_return
	var obj = vm.game.get_object(params[0])

	var target
	if params.size() > 2:
		target = params[2]
		if typeof(target) == TYPE_STRING:
			if !check_obj(target, "spawn_attack"):
				print("warning: object not found for attack target ", target)
			target = vm.game.get_object(target).get_global_pos()

	obj.spawn_attack(params[1], target)

const attack_types = { "energy": 1, "health": 2, "combined": 3 }

func attack(params):
	var target = params[0]
	var type = params[1]
	var damage = params[2]

	if !check_obj(target, "attack"):
		return

	if !(type in attack_types):
		print("warning: attack type invalid: ", type)
		return

	var obj = vm.game.get_object(target)

	obj.damage(attack_types[type], damage)

func despawn(params):
	var target = params[0]
	if !check_obje(target, "despawn"):
		return

	vm.game.despawn(params[0])


func harvest(params):
	var target = params[0]
	if !check_obj(target, "harvest"):
		return

	var obj = vm.game.get_object(target)

	obj.harvest()

### end command

func run(context):
	var cmd = context.instructions[context.ip]
	if cmd.name == "branch":
		context.branch_run = false
	elif cmd.name == "label":
		return vm.state_return

	if !vm.test(cmd):
		return vm.state_return
	#print("name is ", cmd.name)
	#if !(cmd.name in self):
	#	vm.report_errors("", ["Unexisting command "+cmd.name])

	if cmd.name == "branch":
		context.branch_run = true
	elif cmd.name == "branch_else":
		if context.branch_run:
			return vm.state_return
		else:
			context.branch_run = true
	else:
		context.branch_run = false

	var params
	if !("no_eval" in vm.compiler.commands[cmd.name]) || !vm.compiler.commands[cmd.name].no_eval:
		params = []
		for p in cmd.params:
			params.push_back(vm.eval_value(p))
	else:
		params = cmd.params

	#printt(" calling cmd ", cmd.name, _unpack(cmd.params))
	return call(cmd.name, params)

func _unpack(pack):
	var ret = []
	for p in pack:
		ret.push_back(p)
	return ret

func run_vm_pause(context):
	var cmd = vm.dump_packed(context.instructions[context.ip])

	var text = cmd.name
	for p in cmd.params:
		text = text + ", " + str(p)
	var cpos = vm.camera.get_camera_pos()
	var params = [text, "55", cpos.x, cpos.y, false]
	vm.show_text(params, context)
	printt("debug action ", text)
	context.waiting = true

func resume(context):
	current_context = context
	if context.waiting:
		return vm.state_yield
	if context.aborted:
		context.ip = 0
		return vm.state_return
	var count = context.instructions.size()
	while context.ip >= 0 && context.ip < count:
		var stack = vm.tasks[vm.task_current].stack
		var top = stack.size()

		var ret = run(context)
		context.ip += 1

		if top < stack.size():
			return vm.state_call
		if ret == vm.state_yield:
			context.waiting = true
			return vm.state_yield
		if ret == vm.state_call:
			return vm.state_call
		if ret == vm.state_break:
			if context.break_stop:
				break
			else:
				return vm.state_break
		if ret == vm.state_repeat:
			context.ip = 0
		if ret == vm.state_jump:
			return vm.state_jump
	context.ip = 0
	return vm.state_return

func set_vm(p_vm):
	vm = p_vm

func _init():
	#print("*************** vm level init")
	#vm = get_tree().get_singleton("vm")
	pass
