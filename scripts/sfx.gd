extends Node
## Autoload "Sfx": efectos de sonido cozy sintetizados en runtime (sin
## assets): pops suaves de seleccion, un "plop" grave al construir, un pop
## descendente al borrar, una campanita doble cuando un monumento queda
## listo y un barrido con brillo cuando un limpiador purifica tiles.
## Todos son senos calidos con ataque suave y caida exponencial, a
## volumen bajo. Cada play() crea un AudioStreamPlayer descartable, asi los
## sonidos se superponen sin cortarse.

const MIX_RATE := 44100

## Musica de fondo en loop, a volumen bajo para no tapar los efectos.
const MUSIC_PATH := "res://background__music.wav"
const MUSIC_VOLUME_DB := -12.0

var _streams: Dictionary = {}
var _music: AudioStreamPlayer

func _ready() -> void:
	_streams = {
		select = _blip(520.0, 680.0, 0.09, 0.35),
		deselect = _blip(460.0, 330.0, 0.09, 0.28),
		build = _thump(),
		delete = _blip(300.0, 140.0, 0.16, 0.3),
		ready = _chime(),
		clean = _sweep(),
	}
	_start_music()

## Arranca la musica de fondo en loop. Si el WAV es PCM se le activa el loop
## nativo (sin corte); ademas, al terminar se relanza por las dudas (formatos
## comprimidos donde no se puede calcular el punto de loop).
func _start_music() -> void:
	# Sin ventana no hay audio real y el mixer dummy nunca libera el playback
	# (reportaria un falso leak al salir).
	if DisplayServer.get_name() == "headless":
		return
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSIC_PATH):
		stream = load(MUSIC_PATH)
	if stream == null:
		# El asset todavia no fue importado por el editor: parsear el WAV crudo.
		stream = AudioStreamWAV.load_from_file(MUSIC_PATH)
	if stream == null:
		push_warning("No se pudo cargar %s: sin musica de fondo." % MUSIC_PATH)
		return
	if stream is AudioStreamWAV and stream.format != AudioStreamWAV.FORMAT_IMA_ADPCM:
		var bytes_per_sample := 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
		var channels := 2 if stream.stereo else 1
		stream.loop_begin = 0
		stream.loop_end = stream.data.size() / bytes_per_sample / channels
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	_music = AudioStreamPlayer.new()
	_music.stream = stream
	_music.volume_db = MUSIC_VOLUME_DB
	add_child(_music)
	_music.finished.connect(_music.play)
	_music.play()

## Frenar la musica antes de salir libera el stream de audio: sin esto el
## playback activo queda referenciado por el mixer y Godot reporta un leak
## del AudioStreamWAV al cerrar.
func _exit_tree() -> void:
	if _music != null:
		_music.stop()

## Reproduce un efecto por nombre. pitch_jitter varia el tono al azar hasta
## ese porcentaje para que los sonidos repetidos no suenen identicos.
func play(effect: String, pitch_jitter := 0.0) -> void:
	var stream: AudioStreamWAV = _streams.get(effect)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

## Pop: seno con glide de tono, segundo armonico suave para calidez, ataque
## de pocos milisegundos (sin click) y caida exponencial.
func _blip(from_hz: float, to_hz: float, duration: float, volume: float) -> AudioStreamWAV:
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var freq := lerpf(from_hz, to_hz, t)
		phase += TAU * freq / MIX_RATE
		var env := minf(t * 30.0, 1.0) * exp(-5.0 * t)
		var s := sin(phase) + 0.35 * sin(phase * 2.0)
		samples[i] = s / 1.35 * env * volume
	return _make_stream(samples)

## "Plop" de construccion: golpe grave con el tono cayendo rapido (como algo
## que se apoya en el pasto) y un soplido de ruido cortito al inicio.
func _thump() -> AudioStreamWAV:
	var duration := 0.22
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var phase := 0.0
	for i in count:
		var t := float(i) / count
		var freq := 170.0 * pow(0.4, t)
		phase += TAU * freq / MIX_RATE
		var env := minf(t * 50.0, 1.0) * exp(-6.0 * t)
		var noise := randf_range(-1.0, 1.0) * exp(-60.0 * t) * 0.12
		samples[i] = sin(phase) * env * 0.5 + noise
	return _make_stream(samples)

## Campanita doble ascendente (monumento listo): dos notas suaves con
## armonico, la segunda entra apenas despues y queda resonando.
func _chime() -> AudioStreamWAV:
	var duration := 0.55
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var notes := [[660.0, 0.0], [990.0, 0.14]]
	for note in notes:
		var freq: float = note[0]
		var start := int(float(note[1]) * MIX_RATE)
		var phase := 0.0
		for i in range(start, count):
			var t := float(i - start) / MIX_RATE
			phase += TAU * freq / MIX_RATE
			var env := minf(t * 200.0, 1.0) * exp(-7.0 * t)
			samples[i] += (sin(phase) + 0.25 * sin(phase * 3.0)) / 1.25 * env * 0.22
	return _make_stream(samples)

## Barrido de limpieza: un "shhh" de ruido filtrado que sube y baja (como un
## cepillo pasando) y, cuando el barrido termina, un brillo ascendente cortito
## que resuelve: "quedo limpio".
func _sweep() -> AudioStreamWAV:
	var duration := 0.55
	var count := int(duration * MIX_RATE)
	var samples := PackedFloat32Array()
	samples.resize(count)
	var filtered := 0.0
	for i in count:
		var t := float(i) / MIX_RATE
		# Ruido pasado por un one-pole: soplido suave, sin aspereza.
		filtered = lerpf(filtered, randf_range(-1.0, 1.0), 0.12)
		var swoosh := sin(PI * clampf(t / 0.34, 0.0, 1.0))
		samples[i] = filtered * swoosh * swoosh * 0.5
	# Brillo resolutivo: seno ascendente con armonico, entra al morir el ruido.
	var start := int(0.26 * MIX_RATE)
	var phase := 0.0
	for i in range(start, count):
		var t := float(i - start) / MIX_RATE
		var freq := lerpf(740.0, 1180.0, minf(t / 0.2, 1.0))
		phase += TAU * freq / MIX_RATE
		var env := minf(t * 150.0, 1.0) * exp(-9.0 * t)
		samples[i] += (sin(phase) + 0.3 * sin(phase * 2.0)) / 1.3 * env * 0.26
	return _make_stream(samples)

func _make_stream(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, clampi(roundi(samples[i] * 32767.0), -32768, 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = bytes
	return stream
