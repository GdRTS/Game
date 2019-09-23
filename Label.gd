extends Label

func _ready():
	add_to_group("sim")

func _network_step(commands):
	self.text = str(commands)
