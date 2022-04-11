extends "res://addons/sound_manager/abstract_audio_player_pool.gd"


var tweens: Dictionary = {}


func _init():
	._init(["Music", "music"], 2)


func play(resource: AudioStream, crossfade_duration: int = 0, override_bus: String = "") -> AudioStreamPlayer:
	stop(crossfade_duration * 2)
	
	var player = _get_player_with_music(resource)
	
	# If the player already exists then just make sure the volume is right (it might have just
	# been fading in or out)
	if player != null:
		fade_volume(player, player.volume_db, 0, crossfade_duration)
		return player
	
	# Otherwise we need to prep another player and handle its introduction
	player = prepare(resource, override_bus)
	fade_volume(player, -80, 0, crossfade_duration)

	player.call_deferred("play")
	return player


func stop(fade_out_duration: int = 0) -> void:
	for player in busy_players:
		if fade_out_duration <= 0:
			fade_out_duration = 0.01
		fade_volume(player, player.volume_db, -80, fade_out_duration)


func _get_player_with_music(resource: AudioStream) -> AudioStreamPlayer:
	for player in busy_players:
		if player.stream.resource_path == resource.resource_path:
			return player
	return null


func fade_volume(player: AudioStreamPlayer, from_volume: int, to_volume: int, duration: int) -> AudioStreamPlayer:
	# Remove any tweens that might already be on this player
	_remove_tween(player)
	
	# Start a new tween
	var tween = Tween.new()
	add_child(tween)
	
	player.volume_db = from_volume
	if from_volume > to_volume:
		# Fade out
		tween.interpolate_property(player, "volume_db", from_volume, to_volume, duration, Tween.TRANS_CIRC, Tween.EASE_IN)
	else:
		# Fade in
		tween.interpolate_property(player, "volume_db", from_volume, to_volume, duration, Tween.TRANS_QUAD, Tween.EASE_OUT)
	
	tweens[player] = tween
	tween.connect("tween_all_completed", self, "_on_fade_completed", [player, tween, from_volume, to_volume, duration])
	tween.start()

	return player


### Helpers


func _remove_tween(player: AudioStreamPlayer) -> void:
	if tweens.has(player):
		var fade = tweens.get(player)
		fade.stop_all()
		fade.queue_free()
		tweens.erase(player)


### Signals


func _on_fade_completed(player: AudioStreamPlayer, tween: Tween, from_volume: int, to_volume: int, duration: float):
	_remove_tween(player)
	
	# If we just faded out then our player is now available
	if to_volume <= -79:
		player.stop()
		mark_player_as_available(player)
