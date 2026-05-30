class_name Synth
extends Node
## Sample-based polyphonic 8-bit synth.
## Plays looped single-cycle waveform samples (CC0 AKWF waveforms — see
## assets/audio/CREDITS.md) and retunes them per note with pitch_scale, so any
## MIDI note comes from a real recorded waveform rather than a raw generated
## square. Each sounding note is one pooled AudioStreamPlayer; notes get a short
## volume-envelope fade so toggling doesn't click. Reusable beyond the test scene.

const SQUARE_PATH := "res://assets/audio/lead_square.wav"
const TRIANGLE_PATH := "res://assets/audio/bass_triangle.wav"
const BASE_FREQ := 44100.0 / 600.0   # AKWF single-cycle base pitch = 73.5 Hz

const VOICE_DB := -12.0   # target loudness per held note (headroom for chords)
const ATTACK := 0.02      # fade-in seconds
const RELEASE := 0.14     # fade-out seconds before the voice is freed

var _streams: Dictionary = {}   # "square"/"triangle" -> AudioStreamWAV (looped)
var _players: Dictionary = {}   # id -> AudioStreamPlayer


func _ready() -> void:
	_streams["square"] = _load_looped_wav(SQUARE_PATH)
	_streams["triangle"] = _load_looped_wav(TRIANGLE_PATH)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------
## Start (or retrigger) a voice `id` at the given MIDI note.
## `waveform` is "square" or "triangle".
func note_on(id: String, midi: int, waveform: String = "square") -> void:
	note_off(id)   # clean retrigger if already sounding
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = _streams.get(waveform, _streams["square"])
	player.pitch_scale = _midi_to_freq(midi) / BASE_FREQ
	player.volume_db = -40.0
	player.play()
	var tween := create_tween()
	tween.tween_property(player, "volume_db", VOICE_DB, ATTACK)
	_players[id] = player


## Release the voice `id`: fade out, then free the player.
func note_off(id: String) -> void:
	if not _players.has(id):
		return
	var player: AudioStreamPlayer = _players[id]
	_players.erase(id)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, RELEASE)
	tween.tween_callback(player.queue_free)


## Release every sounding voice.
func all_off() -> void:
	for id in _players.keys():
		note_off(id)


## Play a one-shot plucked note: fast attack, brief hold, release, then free.
## `duration` is the total note length in seconds. Used by the sequencer for
## short riff notes (vs the sustained note_on/note_off pair).
func pluck(midi: int, waveform: String = "square", duration: float = 0.2) -> void:
	var player := AudioStreamPlayer.new()
	add_child(player)
	player.stream = _streams.get(waveform, _streams["square"])
	player.pitch_scale = _midi_to_freq(midi) / BASE_FREQ
	player.volume_db = -40.0
	player.play()
	var attack := minf(0.012, duration * 0.25)
	var release := minf(0.06, duration * 0.4)
	var hold := maxf(0.0, duration - attack - release)
	var tween := create_tween()
	tween.tween_property(player, "volume_db", VOICE_DB, attack)
	tween.tween_interval(hold)
	tween.tween_property(player, "volume_db", -60.0, release)
	tween.tween_callback(player.queue_free)


# ---------------------------------------------------------------------------
# Internals
# ---------------------------------------------------------------------------
func _midi_to_freq(midi: int) -> float:
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Read a small PCM WAV from res:// and build a forward-looping AudioStreamWAV
## (single-cycle waveforms must loop to sustain). Avoids relying on the editor's
## .wav import settings for the loop, so it works deterministically.
func _load_looped_wav(path: String) -> AudioStreamWAV:
	var bytes := FileAccess.get_file_as_bytes(path)
	# locate the "data" subchunk (canonical header puts PCM at byte 44, but scan
	# to be safe against extra chunks)
	var data_at := _find_chunk(bytes, "data")
	var pcm_len := bytes.decode_u32(data_at + 4)
	var pcm := bytes.slice(data_at + 8, data_at + 8 + pcm_len)

	var fmt_at := _find_chunk(bytes, "fmt ")
	var channels := bytes.decode_u16(fmt_at + 10)
	var mix_rate := bytes.decode_u32(fmt_at + 12)
	var frames: int = pcm_len / (2 * maxi(channels, 1))

	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = channels >= 2
	wav.mix_rate = mix_rate
	wav.data = pcm
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = frames - 1
	return wav


## Byte offset of a RIFF subchunk id (e.g. "data", "fmt "), searching past the
## 12-byte RIFF/WAVE header. Returns the offset of the 4-char id.
func _find_chunk(bytes: PackedByteArray, id: String) -> int:
	var target := id.to_ascii_buffer()
	var i := 12
	while i + 8 <= bytes.size():
		var match_id := true
		for k in 4:
			if bytes[i + k] != target[k]:
				match_id = false
				break
		if match_id:
			return i
		var size := bytes.decode_u32(i + 4)
		i += 8 + size + (size & 1)   # chunks are word-aligned
	return 44   # fallback to canonical PCM-after-44 layout
