extends Control

export var mouse_enter_color = Color(1,1,0.3)
export var mouse_enter_shadow_color = Color(0.6,0.4,0)
export var mouse_exit_color = Color(1,1,1)
export var mouse_exit_shadow_color = Color(1,1,1)

var vm
var character
var context
var cmd

var is_choice

var container
var item
var label
var button

var animation
var ready = false
var option_selected
var dialog_task

func input(event):
	if event.is_action_pressed("ui_accept") and !is_choice:
		selected(0)
	pass

func selected(n):
	if !ready:
		return
	option_selected = n
	if vm.globals.has("finish_event"):
		animation.play("hide")
	else:
		clear_dialogue()
		if is_choice:
			vm.add_level(cmd[option_selected].params[1], false, dialog_task)
	ready = false

func add_speech(text, id):
	var it = item.duplicate()
	var but = it.get_node("button")
	var label = but.get_node("label")
	label.set_text(text)

	but.connect("pressed", self, "selected", [id])

	if is_choice:
		var height_ratio = Globals.get("platform/dialog_option_height")
		var size = it.get_custom_minimum_size()
		size.y = size.y * height_ratio
		but.set_size(size)

	container.add_child(it)

func add_choices():
	var i = 0
	for choice in cmd:
		add_speech(choice.params[0], i)
		i += 1

func start(params, p_context, p_is_choice):
	context = p_context
	dialog_task = vm.task_current
	is_choice = p_is_choice
	
	if is_choice:
		cmd = params[0]
		add_choices()
	else:
		character = vm.game.get_object(params[0])
		character.set_speaking(true)
		add_speech(params[1], 0)
	
	ready = false
	animation.play("show_basic")
	animation.seek(0, true)
	
func _on_mouse_enter(button):
	button.get_node("label").add_color_override("font_color", mouse_enter_color)
	button.get_node("label").add_color_override("font_color_shadow", mouse_enter_shadow_color)
	
func _on_mouse_exit(button):
	button.get_node("label").add_color_override("font_color", mouse_exit_color)
	button.get_node("label").add_color_override("font_color_shadow", mouse_exit_shadow_color)

func stop():
	hide()
	while container.get_child_count() > 0:
		var c = container.get_child(0)
		container.remove_child(c)
		c.free()
	vm.request_autosave()
	_queue_free()

func game_cleared():
	_queue_free()

func _queue_free():
	get_node("/root/game").remove_hud(self)
	queue_free()

func clear_dialogue():
	vm.finished(context, false)
	if !is_choice:
		character.set_speaking(false)
	stop()

func anim_finished():
	var cur = animation.get_current_animation()
	if cur == "show_basic":
		ready = true
	elif cur == "hide":
		clear_dialogue()
	else:
		ready = true

func _ready():
	hide()
	
	vm = get_tree().get_root().get_node("vm")
	
	container = get_node("anchor/scroll/container")
	container.set_stop_mouse(false)
	
	item = get_node("item")
	button = item.get_node("button")
	label = button.get_node("label")
	
	item.set_stop_mouse(false)
	button.set_stop_mouse(false)
	label.set_stop_mouse(false)
	
	call_deferred("remove_child", item)
	
	animation = get_node("animation")
	animation.connect("finished", self, "anim_finished")
	
	#get_node("anchor/scroll").set_theme(preload("res://game/globals/dialog_theme.xml"))
	
	add_to_group("game")
