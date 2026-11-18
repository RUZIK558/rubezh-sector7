extends Node
## Pooled 2D/3D sound effects and cross-faded music.

const SFX := {
	"shot_1": "res://assets/audio/shot_1.wav",
	"shot_2": "res://assets/audio/shot_2.wav",
	"shot_3": "res://assets/audio/shot_3.wav",
	"empty": "res://assets/audio/empty.wav",
	"reload_out": "res://assets/audio/reload_out.wav",
	"reload_in": "res://assets/audio/reload_in.wav",
	"reload_bolt": "res://assets/audio/reload_bolt.wav",
	"step_1": "res://assets/audio/step_1.wav",
	"step_2": "res://assets/audio/step_2.wav",
	"step_3": "res://assets/audio/step_3.wav",
	"step_4": "res://assets/audio/step_4.wav",
	"jump": "res://assets/audio/jump.wav",
	"land": "res://assets/audio/land.wav",
	"hurt": "res://assets/audio/hurt.wav",
	"impact_concrete": "res://assets/audio/impact_concrete.wav",
	"impact_metal": "res://assets/audio/impact_metal.wav",
	"hitmarker": "res://assets/audio/hitmarker.wav",
	"headshot": "res://assets/audio/headshot.wav",
	"enemy_shot": "res://assets/audio/enemy_shot.wav",
	"enemy_charge": "res://assets/audio/enemy_charge.wav",
	"enemy_hit": "res://assets/audio/enemy_hit.wav",
	"enemy_death": "res://assets/audio/enemy_death.wav",
	"boss_roar": "res://assets/audio/boss_roar.wav",
	"summon": "res://assets/audio/summon.wav",
	"explosion": "res://assets/audio/explosion.wav",
	"pickup_ammo": "res://assets/audio/pickup_ammo.wav",
	"pickup_med": "res://assets/audio/pickup_med.wav",
	"ui_click": "res://assets/audio/ui_click.wav",
	"ui_hover": "res://assets/audio/ui_hover.wav",
	"wave_start": "res://assets/audio/wave_start.wav",
	"wave_clear": "res://assets/audio/wave_clear.wav",
	"victory": "res://assets/audio/victory.wav",
	"defeat": "res://assets/audio/defeat.wav",
	"pistol_shot": "res://assets/audio/pistol_shot.wav",
	"pistol_reload": "res://assets/audio/pistol_reload.wav",
	"knife_swing": "res://assets/audio/knife_swing.wav",
	"knife_hit": "res://assets/audio/knife_hit.wav",
}

const MUSIC := {
	"menu": "res://assets/audio/music_menu.wav",
	"combat": "res://assets/audio/music_combat.wav",
	"boss": "res://assets/audio/music_boss.wav",
}

const SFX_VOLUME := {
	"shot_1": -3.0, "shot_2": -3.0, "shot_3": -3.0,
	"enemy_shot": -9.0, "enemy_charge": -7.0, "enemy_hit": -6.0,
	"hitmarker": -9.0, "headshot": -6.0, "empty": -8.0,
	"reload_out": -5.0, "reload_in": -5.0, "reload_bolt": -5.0,
	"step_1": -19.0, "step_2": -19.0, "step_3": -19.0, "step_4": -19.0,
	"impact_concrete": -14.0, "impact_metal": -13.0,
	"explosion": -2.0, "boss_roar": -2.0, "wave_start": -7.0,
	"victory": -4.0, "defeat": -5.0, "ui_click": -12.0, "ui_hover": -22.0,
	"pistol_shot": -5.0, "pistol_reload": -5.0, "knife_swing": -8.0, "knife_hit": -4.0,
}

var _streams: Dictionary = {}
var _music_streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _cursor := 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_active: AudioStreamPlayer
var _music_track := ""
var _music_tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for key in SFX:
		_streams[key] = load(SFX[key])
	for key in MUSIC:
		var stream: AudioStream = load(MUSIC[key])
		if stream is AudioStreamWAV:
			var wav := stream as AudioStreamWAV
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
		_music_streams[key] = stream
	for i in 14:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	for p in [_music_a, _music_b]:
		p.bus = "Master"
		p.volume_db = -80.0
		add_child(p)
	_music_active = _music_a
	Settings.changed.connect(_on_settings_changed)

func _on_settings_changed() -> void:
	Settings.apply()

func play(sfx: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sfx):
		return
	var base: float = SFX_VOLUME.get(sfx, -4.0)
	var player := _players[_cursor]
	for i in _players.size():
		var idx := (_cursor + i) % _players.size()
		if not _players[idx].playing:
			player = _players[idx]
			_cursor = (idx + 1) % _players.size()
			break
	player.stream = _streams[sfx]
	player.volume_db = base + volume_db
	player.pitch_scale = pitch
	player.play()

func play_3d(sfx: String, world_pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(sfx):
		return
	var scene := get_tree().current_scene
	if scene == null:
		play(sfx, volume_db, pitch)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _streams[sfx]
	p.volume_db = SFX_VOLUME.get(sfx, -4.0) + volume_db
	p.pitch_scale = pitch
	p.max_distance = 70.0
	p.unit_size = 7.0
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.position = world_pos
	scene.add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_music(track: String) -> void:
	if not _music_streams.has(track):
		return
	if track == _music_track and _music_active.playing:
		return
	_music_track = track
	var next := _music_b if _music_active == _music_a else _music_a
	next.stream = _music_streams[track]
	next.volume_db = -80.0
	next.play()
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween().set_parallel(true)
	_music_tween.tween_property(next, "volume_db", -9.0, 1.6).set_trans(Tween.TRANS_SINE)
	_music_tween.tween_property(_music_active, "volume_db", -80.0, 1.2).set_trans(Tween.TRANS_SINE)
	var old := _music_active
	_music_tween.chain().tween_callback(old.stop)
	_music_active = next

func stop_music(fade := 1.0) -> void:
	_music_track = ""
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_active, "volume_db", -80.0, fade)
	_music_tween.tween_callback(_music_active.stop)

func duck_music(amount := 6.0, time := 0.4) -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music_active, "volume_db", -9.0 - amount, time * 0.3)
	_music_tween.tween_interval(time * 0.3)
	_music_tween.tween_property(_music_active, "volume_db", -9.0, time * 0.4)
