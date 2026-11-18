extends Node
## Lightweight ENet session for two-player online co-op.

signal session_started
signal session_ended
signal peer_joined(id: int)
signal peer_left(id: int)

const DEFAULT_PORT := 7777

var peer: ENetMultiplayerPeer = null
var is_host := false
var is_client := false
var self_id := 1
var room_ip := "127.0.0.1"

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func host(port: int = DEFAULT_PORT) -> int:
	reset()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_server(port, 4)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	is_client = false
	self_id = 1
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_started.emit()
	return OK

func join(ip: String, port: int = DEFAULT_PORT) -> int:
	reset()
	if ip.strip_edges() == "":
		ip = "127.0.0.1"
	room_ip = ip.strip_edges()
	peer = ENetMultiplayerPeer.new()
	var err := peer.create_client(room_ip, port)
	if err != OK:
		peer = null
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	is_client = true
	self_id = multiplayer.get_unique_id()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	session_started.emit()
	return OK

func reset() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	if peer != null:
		peer.close()
		peer = null
	if multiplayer.peer_connected.is_connected(_on_peer_connected):
		multiplayer.peer_connected.disconnect(_on_peer_connected)
	if multiplayer.peer_disconnected.is_connected(_on_peer_disconnected):
		multiplayer.peer_disconnected.disconnect(_on_peer_disconnected)
	is_host = false
	is_client = false
	self_id = 1
	session_ended.emit()

func connected_peers() -> Array[int]:
	if multiplayer.multiplayer_peer == null:
		return []
	var out: Array[int] = []
	for id in multiplayer.get_peers():
		out.append(int(id))
	return out

func _on_peer_connected(id: int) -> void:
	print("NET: peer connected ", id)
	peer_joined.emit(id)

func _on_peer_disconnected(id: int) -> void:
	peer_left.emit(id)
