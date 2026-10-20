extends Node
## Small synthesized, original sound library. No network or asset dependency.
var clips = {}
var enabled = true
var rng = RandomNumberGenerator.new()

func _ready():
	rng.seed = 708
	for kind in ["shot", "hit", "kill", "step", "reload", "rack", "shield", "hurt", "empty", "casing", "impact_metal", "impact_concrete", "impact_wood", "impact_glass"]:
		clips[kind] = synth(kind)

func synth(kind: String) -> AudioStreamWAV:
	var duration = {"shot": 0.22, "hit": 0.12, "kill": 0.26, "step": 0.09, "reload": 0.28, "rack": 0.18, "shield": 0.3, "hurt": 0.3, "empty": 0.06, "casing": 0.08, "impact_metal": 0.24, "impact_concrete": 0.18, "impact_wood": 0.16, "impact_glass": 0.28}[kind]
	var count = int(duration * 22050)
	var bytes = PackedByteArray()
	bytes.resize(count * 2)
	var low = 0.0
	for i in range(count):
		var t = i / 22050.0
		var n = rng.randf_range(-1, 1)
		low = low * 0.73 + n * 0.27
		var sample = 0.0
		match kind:
			"shot": sample = (n * exp(-t * 65) * 0.65 + low * exp(-t * 22) + sin(t * 420 * exp(-t * 6)) * exp(-t * 26) * 0.65)
			"hit": sample = low * exp(-t * 38) * 0.7 + sin(t * 530) * exp(-t * 50) * 0.25
			"kill": sample = low * exp(-t * 18) * 0.9 + sin(t * 210) * exp(-t * 25) * 0.3
			"step": sample = low * exp(-t * 52) * 0.35
			"reload": sample = n * (exp(-t * 80) * 0.4 + exp(-abs(t - 0.16) * 110) * 0.4)
			"rack": sample = n * exp(-t * 33) * 0.3 + sin(t * 1100) * exp(-t * 45) * 0.2
			"shield": sample = (sin(t * 1300) + sin(t * 1970) * 0.4 + low * 0.9) * exp(-t * 15) * 0.35
			"hurt": sample = (low * 0.8 + sin(t * 170) * 0.3) * exp(-t * 14)
			"empty": sample = n * exp(-t * 110) * 0.22
			"casing": sample = (sin(t * 2600) + sin(t * 3700) * 0.45) * exp(-t * 70) * 0.18
			"impact_metal": sample = (sin(t * 1800) + sin(t * 2740) * 0.55 + n * 0.3) * exp(-t * 19) * 0.42
			"impact_concrete": sample = (low * 0.9 + n * 0.35) * exp(-t * 31) * 0.43
			"impact_wood": sample = (low * 0.55 + sin(t * 310) * 0.38) * exp(-t * 39) * 0.42
			"impact_glass": sample = (sin(t * 2900) * 0.35 + sin(t * 4100) * 0.22 + n * 0.22) * exp(-t * 13)
		bytes.encode_s16(i * 2, int(clampf(sample * 0.65, -1, 1) * 32767))
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	wav.data = bytes
	return wav

func play(kind: String, volume = 0.0, pitch = 1.0):
	if not enabled or not clips.has(kind):
		return
	var voice = AudioStreamPlayer.new()
	voice.stream = clips[kind]
	voice.volume_db = volume - 7.0
	voice.pitch_scale = pitch
	add_child(voice)
	voice.finished.connect(voice.queue_free)
	voice.play()
