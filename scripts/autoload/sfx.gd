extends Node
## الأصوات: إن وجد ملف حقيقي في res://assets/audio/<name>.ogg|wav|mp3 يُستخدم،
## وإلا يُولَّد الصوت برمجيًا (طلقات، انفجارات، محركات، خطوات...). التوليد موزّع على الإطارات.

const RATE := 22050
var _s := {}
var _q := ["rifle", "step", "explosion", "engine_diesel", "click", "hover", "rocket", "cannon", "mg", "lmg",
	"sniper", "support", "engine_heli", "engine_jet", "tracks", "reload", "door", "hit_flesh", "hit_metal",
	"impact", "death", "collapse", "wind", "fire"]


func _process(_d: float) -> void:
	if _q.is_empty():
		set_process(false)
		return
	_get(_q.pop_front())


func _get(nm: String) -> AudioStream:
	if _s.has(nm):
		return _s[nm]
	var st: AudioStream = _external(nm)
	if st == null:
		st = _gen(nm)
	_s[nm] = st
	return st


func _external(nm: String) -> AudioStream:
	for ext in ["ogg", "wav", "mp3"]:
		var p := "res://assets/audio/%s.%s" % [nm, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


func stream(nm: String) -> AudioStream:
	return _get(nm)


func play3d(nm: String, pos: Vector3, db := 0.0, pitch := 1.0, maxd := 220.0) -> void:
	var tree := get_tree()
	var st := _get(nm)
	if tree.current_scene == null or st == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.volume_db = db
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	p.max_distance = maxd
	p.unit_size = 18.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()


func ui(nm := "click", db := -8.0) -> void:
	var st := _get(nm)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.volume_db = db
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func _gen(nm: String) -> AudioStream:
	match nm:
		"rifle": return _shot(0.25, 28.0, 110.0, 0.65)
		"support": return _shot(0.3, 22.0, 90.0, 0.55)
		"sniper": return _shot(0.8, 10.0, 62.0, 0.4)
		"lmg": return _shot(0.2, 32.0, 120.0, 0.7)
		"mg": return _shot(0.2, 30.0, 100.0, 0.75)
		"cannon": return _shot(1.1, 5.0, 40.0, 0.2)
		"explosion": return _shot(2.2, 2.2, 34.0, 0.1)
		"rocket": return _hiss(1.2)
		"step": return _shot(0.14, 42.0, 70.0, 0.22, 0.6)
		"impact": return _shot(0.16, 38.0, 88.0, 0.3, 0.7)
		"hit_flesh": return _shot(0.12, 55.0, 150.0, 0.3, 0.9)
		"death": return _shot(0.6, 8.0, 55.0, 0.2)
		"hit_metal": return _ring(0.35, 1800.0, 14.0)
		"door": return _ring(0.5, 520.0, 7.0, 0.5)
		"reload": return _reload()
		"click": return _ring(0.06, 1500.0, 60.0, 0.4)
		"hover": return _ring(0.04, 2200.0, 90.0, 0.2)
		"collapse": return _rumble(3.2)
		"engine_diesel": return _engine_diesel()
		"engine_heli": return _engine_heli()
		"engine_jet": return _engine_jet()
		"tracks": return _tracks()
		"wind": return _wind()
		"fire": return _fire()
	return null


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


func _shot(len_s: float, decay: float, thump: float, lp_k: float, gain := 0.9) -> AudioStreamWAV:
	var n := int(RATE * len_s)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	var lp2 := 0.0
	for i in n:
		var t := float(i) / RATE
		var nz := randf_range(-1.0, 1.0)
		lp += (nz - lp) * lp_k
		lp2 += (lp - lp2) * 0.15
		var crack := (nz - lp) * exp(-t * decay * 3.0) * 0.5
		var v := lp * exp(-t * decay) * 1.2 + lp2 * exp(-t * decay * 0.4) * 0.9 + crack + sin(TAU * thump * t * (1.0 - t * 0.3)) * exp(-t * decay * 0.55) * 0.8
		a[i] = v * gain
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


func _ring(len_s: float, f: float, decay: float, gain := 0.7) -> AudioStreamWAV:
	var n := int(RATE * len_s)
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var env := exp(-t * decay)
		a[i] = (sin(TAU * f * t) * 0.6 + sin(TAU * f * 2.76 * t) * 0.25 + randf_range(-0.3, 0.3) * exp(-t * 200.0)) * env * gain
	return _wav(a)


func _reload() -> AudioStreamWAV:
	var n := int(RATE * 1.0)
	var a := PackedFloat32Array()
	a.resize(n)
	for k in [0.0, 0.32, 0.8]:
		var start := int(k * RATE)
		for i in range(int(0.08 * RATE)):
			if start + i >= n:
				break
			var t := float(i) / RATE
			a[start + i] += (sin(TAU * (900.0 + k * 500.0) * t) * 0.5 + randf_range(-0.4, 0.4)) * exp(-t * 70.0) * 0.8
	return _wav(a)


func _rumble(len_s: float) -> AudioStreamWAV:
	var n := int(RATE * len_s)
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp += (randf_range(-1.0, 1.0) - lp) * 0.08
		var crack := 0.0
		if randf() < 0.002:
			crack = randf_range(-1.0, 1.0)
		a[i] = (lp * 1.6 + crack * 0.6 + sin(TAU * 32.0 * t) * 0.4) * minf(t * 6.0, 1.0) * exp(-t * 0.9)
	return _wav(a)


func _engine_diesel() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var fire := pow(maxf(sin(TAU * 15.0 * t), 0.0), 2.0)
		var v := 0.45 * sin(TAU * 30.0 * t) + 0.3 * sin(TAU * 60.0 * t + 1.0) + 0.2 * sin(TAU * 90.0 * t + 2.0) + 0.12 * sin(TAU * 150.0 * t + 0.5)
		a[i] = v * (0.55 + 0.45 * fire) * 0.7
	return _wav(a, true)


func _engine_heli() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var pulse := pow(maxf(sin(TAU * 12.0 * t), 0.0), 6.0)
		var turbine := sin(TAU * 1100.0 * t) * 0.07 + sin(TAU * 1650.0 * t) * 0.05
		var v := pulse * (0.7 * sin(TAU * 50.0 * t) + 0.4 * sin(TAU * 96.0 * t)) + 0.2 * sin(TAU * 220.0 * t) + turbine
		a[i] = v * 0.7
	return _wav(a, true)


func _engine_jet() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	var freqs := []
	var phases := []
	for j in 20:
		freqs.append(2.0 * randi_range(100, 1000))
		phases.append(randf() * TAU)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in 20:
			v += sin(TAU * freqs[j] * t + phases[j])
		a[i] = v / 20.0 * 1.8 + sin(TAU * 60.0 * t) * 0.3 + sin(TAU * 2400.0 * t) * 0.08
	return _wav(a, true)


func _tracks() -> AudioStreamWAV:
	var n := RATE / 2
	var a := PackedFloat32Array()
	a.resize(n)
	for i in n:
		var t := float(i) / RATE
		var p := pow(maxf(sin(TAU * 10.0 * t), 0.0), 8.0)
		var v := (sin(TAU * 900.0 * t) * 0.3 + sin(TAU * 1450.0 * t) * 0.2 + sin(TAU * 60.0 * t) * 0.6) * p
		a[i] = v * 0.6
	return _wav(a, true)


func _wind() -> AudioStreamWAV:
	var n := RATE * 2
	var a := PackedFloat32Array()
	a.resize(n)
	var freqs := []
	var phases := []
	for j in 10:
		freqs.append(0.5 * randi_range(80, 700))
		phases.append(randf() * TAU)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for j in 10:
			v += sin(TAU * freqs[j] * t + phases[j])
		a[i] = v / 10.0 * (0.6 + 0.4 * sin(TAU * 0.5 * t)) * 0.5
	return _wav(a, true)


func _fire() -> AudioStreamWAV:
	var n := RATE * 2
	var a := PackedFloat32Array()
	a.resize(n)
	var lp := 0.0
	for i in n:
		lp += (randf_range(-1.0, 1.0) - lp) * 0.05
		var crack := 0.0
		if randf() < 0.0015:
			crack = randf_range(-1.0, 1.0)
		a[i] = lp * 0.9 + crack * 0.6
	return _wav(a, true)
