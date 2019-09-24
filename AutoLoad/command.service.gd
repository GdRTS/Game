extends Node

onready var network_service = get_node("/root/NetworkService")

# 2d array: steps, commands
# step 0 always empty
var commandRequests = [[]]

# 2d array: steps, commands
# step 0 and 1 always empty
# null means that commands havent been received yet
var commands = [[],[]]

var game_started = false

func _ready():
	add_to_group("sim")
	network_service.connect("game_start", self, "_on_start")
	print("Iterations per second: ", Engine.iterations_per_second)

# runs 60 times per second by default
var network_step = 0
var iteration = 0
func _physics_process(delta):
	if game_started:
		if iteration % 60 == 0: # at 1s intervals
			network_service.send_data(commandRequests[network_step], network_step)
			# TODO pause game if we didnt receive commands in time
			network_step += 1
			commands.append(network_service.get_data(network_step))
			get_tree().call_group("sim", "_network_step", commands[network_step])
			commandRequests.append([]) # initialize next step
			iteration = 0
		iteration += 1

func _on_start():
	game_started = true

# REQUESTS

func requestGameStart():
	network_service.send_start()

func requestCommand(command):
	commandRequests[network_step].append(command)