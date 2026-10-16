extends RefCounted
## مواد وخامات إجرائية (بدون ملفات صور): تمويه، خرسانة، أرض، زجاج...

static var _cache := {}


static func solid(col: Color, rough := 0.75, metal := 0.0) -> StandardMaterial3D:
	var key := "s%s_%s_%s" % [col.to_html(), rough, metal]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	_cache[key] = m
	return m


static func emissive(col: Color, energy := 2.0) -> StandardMaterial3D:
	var key := "e%s_%s" % [col.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


static func glass() -> StandardMaterial3D:
	if _cache.has("glass"):
		return _cache["glass"]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.16, 0.2, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.metallic = 0.7
	m.roughness = 0.08
	_cache["glass"] = m
	return m


static func _tex_material(img: Image, uv_scale: float, rough: float, metal := 0.0) -> StandardMaterial3D:
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * uv_scale
	m.roughness = rough
	m.metallic = metal
	return m


static func _noise_img(seed_v: int, freq: float, size: int) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	n.seed = seed_v
	return n.get_seamless_image(size, size)


static func ground(c0: Color, c1: Color, uv_scale := 0.1, freq := 0.03) -> StandardMaterial3D:
	var key := "g%s%s%s" % [c0.to_html(), c1.to_html(), uv_scale]
	if _cache.has(key):
		return _cache[key]
	var size := 128
	var a := _noise_img(11, freq, size)
	var b := _noise_img(23, freq * 4.0, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var v: float = a.get_pixel(x, y).r * 0.7 + b.get_pixel(x, y).r * 0.3
			img.set_pixel(x, y, c0.lerp(c1, v))
	var m := _tex_material(img, uv_scale, 1.0)
	_cache[key] = m
	return m


static func camo(palette := "woodland") -> StandardMaterial3D:
	var key := "c" + palette
	if _cache.has(key):
		return _cache[key]
	var pal: Array = [Color(0.50, 0.54, 0.34), Color(0.74, 0.63, 0.43), Color(0.26, 0.32, 0.20), Color(0.13, 0.13, 0.11)]
	if palette == "desert":
		pal = [Color(0.76, 0.65, 0.45), Color(0.62, 0.50, 0.34), Color(0.47, 0.38, 0.27), Color(0.32, 0.26, 0.19)]
	elif palette == "digital":
		pal = [Color(0.36, 0.41, 0.29), Color(0.29, 0.33, 0.23), Color(0.46, 0.46, 0.36), Color(0.16, 0.18, 0.13)]
	var size := 128
	var i1 := _noise_img(3, 0.035, size)
	var i2 := _noise_img(9, 0.05, size)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in size:
		for x in size:
			var a: float = i1.get_pixel(x, y).r
			var b: float = i2.get_pixel(x, y).r
			var c: Color = pal[0]
			if a > 0.62:
				c = pal[1]
			if b > 0.66:
				c = pal[2]
			if a < 0.16:
				c = pal[3]
			img.set_pixel(x, y, c)
	var m := _tex_material(img, 0.2 if palette != "digital" else 1.6, 0.85, 0.08)
	_cache[key] = m
	return m


## جدار مبنى بنوافذ (يتكرر كل 3 أمتار بالإحداثيات العالمية)
static func building(base: Color) -> StandardMaterial3D:
	var key := "b" + base.to_html()
	if _cache.has(key):
		return _cache[key]
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var n := _noise_img(5, 0.08, size)
	for y in size:
		for x in size:
			var g: float = n.get_pixel(x, y).r
			img.set_pixel(x, y, base.darkened(g * 0.22))
	for y in range(14, 46):
		for x in range(18, 46):
			img.set_pixel(x, y, Color(0.06, 0.08, 0.1))
	for x in range(16, 48):
		img.set_pixel(x, 46, base.lightened(0.2))
		img.set_pixel(x, 47, base.lightened(0.2))
		img.set_pixel(x, 12, base.darkened(0.3))
	var m := _tex_material(img, 1.0 / 3.0, 0.95)
	_cache[key] = m
	return m
