extends Node

# CONFIG

var listen_port = 4243
var listen_address = "127.0.0.1"
var server_port = 4242
var server_address = "127.0.0.1"

var socket = PacketPeerUDP.new()

# STATE

var player = 0
var players = 1 # player count
var listening = false
var local_seq = 0
var resendThreshold = 500
var expectAcknowledgement = {}

# SIGNALS
signal game_start

# array of dictionaries with player ids as keys
var data = [{},{}]

# RECEIVERS

func receive_acknowledgement(packet):
	expectAcknowledgement.erase(int(packet.ack))

func receive_player_joined(packet):
	players = packet.players
	send_acknowledgement(packet.seq)

func receive_start(packet):
	expectAcknowledgement.erase(int(packet.ack))
	emit_signal("game_start")
	send_acknowledgement(packet.seq)

func receive_connection_acknowledgement(packet):
	player = packet.player
	players = packet.players
	expectAcknowledgement.erase(int(packet.ack))
	
func receive_broadcast(packet):
	expectAcknowledgement.erase(int(packet.ack))
	if data.size() <= packet.step + 2:
		data.append({})
	data[packet.step + 2][packet.player] = packet.data
	send_acknowledgement(packet.seq)

# SENDERS

func resend_packet(packet):
	socket.put_packet(JSON.print(packet).to_ascii())
	
func send_connect():
	var packet = {
		'flag': 'connect',
		'seq': local_seq
	}
	socket.put_packet(JSON.print(packet).to_ascii())
	expectAcknowledgement[local_seq] = {"packet": packet, "ttl": resendThreshold}
	local_seq += 1

func send_start():
	var packet = {
		'flag': 'start',
		'seq': local_seq
	}
	socket.put_packet(JSON.print(packet).to_ascii())
	expectAcknowledgement[local_seq] = {"packet": packet, "ttl": resendThreshold}
	local_seq += 1

func send_data(data, step):
	var packet = {
		'flag': 'data',
		'data': data,
		'step': step,
		'seq': local_seq
	}
	socket.put_packet(JSON.print(packet).to_ascii())
	expectAcknowledgement[local_seq] = {"packet": packet, "ttl": resendThreshold}
	local_seq += 1

func send_acknowledgement(seq):
	var packet = {
		'flag': 'ack',
		'ack': seq
	}
	socket.put_packet(JSON.print(packet).to_ascii())

#

func get_data(step):
	# returns null if we havent received broadcast from all players
	if data.size() < step or data[step].keys().size() < players:
		return null
	return data[step]

# INITIALIZE

#func _ready():
#	connect_socket()

func _process(delta):
	if (listening):
		poll_server()
		check_acknowledgements(delta)

func check_acknowledgements(delta):
	for req in expectAcknowledgement.values():
		if req.ttl <= 0:
			resend_packet(req.packet)
			req.ttl = resendThreshold
		else:
			req.ttl -= delta * 1000

func poll_server():
	while (socket.get_available_packet_count() > 0):
		var data = socket.get_packet().get_string_from_ascii()
		var packet = JSON.parse(data).result
		match packet["flag"]:
			"ack":
				receive_acknowledgement(packet)
			"join":
				receive_player_joined(packet)
			"start":
				receive_start(packet)
			"cack":
				receive_connection_acknowledgement(packet)
			"broadcast":
				receive_broadcast(packet)
			_:
				print('Unsupported packet received')
		print(data)

func connect_socket(port):
	listen_port = int(port)
	var status = socket.listen(listen_port, listen_address)
	print(status)
	if(status != OK):
		print("An error has occurred listening on "+str(listen_address)+":"+str(listen_port))
	else:
		listening = true
		print("Listening on "+str(listen_address)+":"+str(listen_port))
			
	socket.set_dest_address(server_address, server_port)
	
	send_connect()
