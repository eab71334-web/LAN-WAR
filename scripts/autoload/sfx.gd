extends Node
## أصوات مولّدة برمجيًا (طلقات، انفجارات، محركات) — لا حاجة لملفات صوت.

const RATE := 22050
var _s := {}


func _ready() -> void:
	_s["rifle"] = _shot(0.25, 28.0, 110.0, 0.65)
	_s["support"] = _shot(0.3, 22.0, 90.0, 0.55)
	_s["sniper"] = _shot(0.7, 11.0, 65.0, 0.45)
	_s["lmg"] = _shot(0.2, 32.0, 120.0, 0.7)
	_s["mg"] = _shot(0.2, 30.0, 100.0, 0.75)
	_s["cannon"] = _shot(1.0, 5.5, 42.0, 0.22)
	_s["explosion"] = _shot(2.0, 2.4, 36.0, 0.1)
	_s["rocket"] = _hiss(1.2)
	_s["engine_diesel"] = _engine_diesel()
	_s["engine_heli"] = _engine_heli()
	_s["engine_jet"] = _engine_jet()


func stream(nm: String) -> AudioStream:
	return _s.get(nm)


func play3d(nm: String, pos: Vector3, db := 0.0, pitch := 1.0, maxd := 220.0) -> void:
	var tree := get_tree()
	if tree.current_scene == null or not _s.has(nm):
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = _s[nm]
	p.volume_db = db
	p.pitch_scale = pitch
	p.max_distance = maxd
	p.unit_size = 18.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func _wav(a: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	var b := PackedByteArray()
	b.resize(a.size() * 2)
	for i in a.size():
		b.encode_s16(i * 2, int(clampf(a[i], -1.0, 1.0) * 32000.0))
	s.data = b
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = a.size()
	return s


func _shot(len_s: float, decay: float, thump: float, lp_k: float) -> AudioStreamWAV:
	var n := int(RATE * len_s)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * lp_k
		var v := lp * exp(-t * decay) * 1.3 + sin(TAU * thump * t) * exp(-t * decay * 0.55) * 0.8
		a[i] = v * 0.9
	return _wav(a)


func _hiss(len_s: float) -> AudioStreamWAV:
	var n := int(RATE * len_s)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t * 12.0, 1.0) * exp(-t * 2.2)
		lp += (randf_range(-1.0, 1.0) - lp) * 0.35
		a[i] = lp * env * 0.9 + sin(TAU * 70.0 * t) * env * 0.25
	return _wav(a)


func _engine_diesel() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.5 * sin(TAU * 40.0 * t) + 0.3 * sin(TAU * 80.0 * t + 1.0) + 0.2 * sin(TAU * 120.0 * t + 2.0)
		v *= 0.7 + 0.3 * sin(TAU * 10.0 * t)
		a[i] = v * 0.6
	return _wav(a, true)


func _engine_heli() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var pulse := pow(maxf(sin(TAU * 12.0 * t), 0.0), 6.0)
		var v := pulse * (0.7 * sin(TAU * 50.0 * t) + 0.4 * sin(TAU * 96.0 * t)) + 0.2 * sin(TAU * 220.0 * t)
		a[i] = v * 0.7
	return _wav(a, true)


func _engine_jet() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	var freqs := []
	var phases := []
	for j in 24:
		freqs.append(2.0 * randi_range(120, 1100))
		phases.append(randf() * TAU)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in 24:
			v += sin(TAU * freqs[j] * t + phases[j])
		a[i] = v / 24.0 * 1.6 + sin(TAU * 60.0 * t) * 0.3
	return _wav(a, true)
