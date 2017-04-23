var game
var vm

func save():
	#TODO: Add more things to the "save" group as needed, will need loop in save_pressed
	var player = get_tree().get_nodes_in_group("save")[0]

	var save_dict = {
		file = player.get_filename(),
		parent = player.get_parent().get_name(),
		pos_x = player.get_pos().x,
		pos_y = player.get_pos().y,
		current_scene = game.current_scene
	}
	
	return save_dict

func save_pressed():
	var save_game = File.new()
	save_game.open_encrypted_with_pass("user://savegame.save", File.WRITE, "password")
	var node_data = save()
	save_game.store_line(node_data.to_json())
	save_game.close()

func input(event):
	if event.is_echo():
		return
	if !event.is_pressed():
		return
	if event.is_action("menu_request"):
		close()

func close():
	hide()
	game.remove_hud(self)

func open():
	show()
	game.add_hud(self)

func _ready():
	game = get_node("/root/game")
	vm = get_node("/root/vm")

	get_node("save_game").connect("pressed", self, "save_pressed")
