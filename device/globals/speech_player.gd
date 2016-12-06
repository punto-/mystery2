extends ResourcePreloader

func say(params, callback):
	var type
	if params.size() < 3 || !has_resource(params[2]):
		type = "default"
	else:
		type = params[2]
	type = type + Globals.get("platform/dialog_type_suffix")
	var inst = get_resource(type).instance()
	var z = inst.get_z()
	get_node("/root/game").add_hud(inst)
	var intro = true
	var outro = true
	inst.init(params, callback)
	inst.set_z(z)

func _ready():
	add_to_group("dialog")
