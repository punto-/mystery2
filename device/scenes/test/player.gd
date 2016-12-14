extends "res://globals/item.gd" #KinematicBody2D

var speed = 3
var move_direction = Vector2(0, 0)
var target

var inventory = []

var canMove = true
var canInteract = false

func _ready():
    set_process_input(true)
    set_fixed_process(true)

func _fixed_process(delta):
	if(vm.can_interact()):
		move_player()
		
func _input(event):
	if(vm.can_interact() and target != null
		 and event.is_action_pressed("use")):
			target.interact(null)
		#if(inventory.find(target.get_name()) < 0):
		#	inventory.append(target.get_name())

func move_player():
	move_direction = Vector2(0,0)
	if(Input.is_action_pressed("walk_left")):
		move_direction += Vector2(-1, 0)
	if(Input.is_action_pressed("walk_right")):
		move_direction += Vector2(1, 0)
	if(Input.is_action_pressed("walk_up")):
		move_direction += Vector2(0, -1)
	if(Input.is_action_pressed("walk_down")):
		move_direction += Vector2(0, 1)
	move(move_direction.normalized() * speed)

func _on_Area2D_body_enter(body, obj):
	if(body.get_parent().get_name() == "Player" and obj.get_active()):
		target = obj
	
func _on_Area2D_body_exit(body, obj):
	if(body.get_parent().get_name() == "Player"):
		target = null