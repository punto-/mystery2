extends Control

var vm
var game

var root_string = "/root/"
var scene_path = "res://scenes/test/" 
var scene_name

func input(event):
	if event.is_echo():
		return
	if !event.is_pressed():
		return

func new_pressed():
	vm.clear()
	var events = vm.compile("res://game/game.esc")
	vm.run_event(events["load"], {})

func load_pressed():
	var save = File.new()
	if !save.file_exists("user://savegame.save"):
		return

	var nodes = get_tree().get_nodes_in_group("save")
	var line = {}

	var err = save.open_encrypted_with_pass("user://savegame.save", File.READ, "password")

	while(!save.eof_reached()):
		line.parse_json(save.get_line())
		var scene = line["parent"]
		scene_name = scene_path + scene + ".tscn"
		
		game.change_scene([scene_name], vm.level.current_context)
		
		var curr_scene = game.current_scene
		
		var obj
		if(curr_scene.has_node("player")):
			obj = curr_scene.get_node("player")
		else:
			obj = load(line["file"]).instance()
			curr_scene.add_child(obj)
		
		obj.set_pos(Vector2(line["pos_x"], line["pos_y"]))
		#for i in line.keys():
		#	obj.set(i, line[i])
	
	save.close()

func _ready():
	get_node("new_game").connect("pressed", self, "new_pressed")
	get_node("load_game").connect("button_down", self, "load_pressed")
	
	vm = get_tree().get_root().get_node("vm")
	game = get_tree().get_root().get_node("game")

	set_process_input(true)

	add_to_group("ui")