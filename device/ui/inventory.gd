var vm

var item
var clue

var instances

var inventory

var cur_item = 0
var first_item = 0

var cur_clue = -1
var first_clue = 0

var item_slots
var clue_slots

var item_cursor
var clue_cursor

var item_cols = 2

func update_slots(parent, slots, first, current, cursor):
	var slot = 0
	for i in range(parent.get_child_count()):
		var c = parent.get_child(i)
		if i < first || i >= first + slots.size():
			c.hide()
		else:
			c.show()
			c.set_global_pos(slots[slot])
			slot += 1

	if current == -1:
		cursor.hide()
	else:
		var s = current - first
		cursor.show()
		cursor.set_global_pos(slots[s])

func update_pages():
	update_slots(get_node("i"), item_slots, first_item, cur_item, item_cursor)
	update_slots(get_node("c"), clue_slots, first_clue, cur_clue, clue_cursor)


func global_changed(name):
	if name.find("i/") != 0 && name.find("c/") != 0:
		return

	update_items()

	if is_visible():
		update_pages()

func instance_item(p_item):
	var node = item.duplicate()
	node.set_texture(load(p_item.icon))
	node.set_name(p_item.id)
	node.set_meta("item", p_item)
	get_node("i").add_child(node)

func instance_clue(p_clue):
	var node = clue.duplicate
	node.set_name(p_clue.id)
	node.get_node("title").set_text(p_clue.title)
	node.set_meta("clue", p_clue)
	get_node("c").add_child(node)

func remove_item(path):
	if has_node(path):
		get_node(path).free()

func check_instances(list, prefix):
	for it in list:
		var gid = prefix + it.id
		var in_inv = vm.get_global(gid)
		var instanced = has_node(gid)

		if in_inv && !instanced:
			if prefix == "i/":
				instance_item(it)
			else:
				instance_clue(it)
		elif !in_inv && instanced:
			remove_item(gid)


func update_items():
	check_intances(inventory.items, "i/")
	check_intances(inventory.clues, "c/")

	if get_node("i").get_child_count() == 0:
		cur_item = -1
	if get_node("c").get_child_count() == 0:
		cur_clue = -1



func find_slots():
	item_slots = []
	var n = get_node("item_slots")
	for i in range(n.get_child_count()):
		var c = n.get_child(i)
		item_slots.push_back(c.get_global_pos())

	clue_slots = []
	n = get_node("clue_slots")
	for i in range(n.get_child_count()):
		var c = n.get_child(i)
		clue_slots.push_back(c.get_global_pos())

func input(event):
	if event.is_echo():
		return
	if !event.is_pressed():
		return

	var dir = Vector2()
	if event.is_action("ui_up"):
		dir.y = -1
	elif event.is_action("ui_down"):
		dir.y = 1
	elif event.is_action("ui_left"):
		dir.x = -1
	elif event.is_action("ui_right"):
		dir.x = 1

	if dir != Vector2():
		move_cursor(dir)
		update_pages()

	if event.is_action("inventory_toggle"):
		close()

func move_cursor(dir):

	var it_count = get_node("i").get_child_count()
	var clue_count = get_node("c").get_child_count()
	if dir.y != 0:
		if cur_item != -1:
			cur_item += item_cols * dir.y
			if cur_item < 0:
				cur_item += it_count
			elif cur_item >= it_count:
				cur_item -= it_count
		if cur_clue != -1:
			cur_clue += dir.y
			if cur_clue < 0:
				cur_clue += clue_count
			elif cur_clue >= clue_count:
				cur_clue -= clue_count

	elif dir.x != 0:
		# todo: figure out the right way to switch areas
		if it_count == 0 || clue_count == 0:
			return

		if cur_clue != -1:
			cur_item = first_item
			cur_clue = -1
		elif cur_item != -1:
			if dir.x == 1:
				if cur_item % 2 == 1 || cur_item == it_count -1:
					cur_clue = first_clue
					cur_item = -1
				else:
					cur_item += dir.x
					if cur_item < 0:
						cur_item = 0
					if cur_item >= it_count:
						cur_item = it_count - 1

	if cur_item != -1:
		if cur_item < first_item:
			first_item = cur_item
		if cur_item >= first_item + item_slots.size():
			first_item = cur_item - item_slots.size()

	if cur_clue != -1:
		if cur_clue < first_clue:
			first_clue = cur_clue
		if cur_clue >= first_clue + clue_slots.size():
			first_clue = cur_clue - clue_slots.size()

func close():
	hide()
	game.remove_hud(self)


func open():
	show()
	game.add_hud(self)
	update_pages()


func _ready():

	vm = get_node("/root/vm")

	item = get_node("item")
	item.hide()
	clue = get_node("clue")
	clue.hide()

	item_cursor = get_node("item_cursor")
	clue_cursor = get_node("clue_cursor")

	instances = get_node("instances")

	inventory = preload("res://game/inventory.gd")

	vm.connect("global_changed", self, "global_changed")

	get_node("i").hide()
	get_node("c").hide()

	find_slots()