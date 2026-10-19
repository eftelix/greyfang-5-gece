class_name Mats
extends RefCounted
## Material factory with caching. World surfaces use world-triplanar mapping so
## boxes of any size tile textures consistently.

static var _cache: Dictionary = {}
static var _tex: Dictionary = {}


static func tex(n: String) -> Texture2D:
	if _tex.has(n):
		return _tex[n]
	var path := "res://assets/textures/%s" % n
	if not n.contains("."):
		path += ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path)
	_tex[n] = t
	return t


static func surface(key: String, tex_name: String, tint: Color = Color.WHITE, scale: float = 0.5, rough: float = 0.85, metal: float = 0.0) -> StandardMaterial3D:
	var k := "s:%s:%s:%s:%s" % [key, tex_name, tint.to_html(), scale]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name)
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = rough
	m.metallic = metal
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_cache[k] = m
	return m


static func color(c: Color, rough: float = 0.8, metal: float = 0.0, key: String = "") -> StandardMaterial3D:
	var k := "c:%s:%s:%s:%s" % [c.to_html(), rough, metal, key]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_cache[k] = m
	return m


## Fur-like material for animatronic suits (local triplanar noise detail)
static func fur(c: Color, scale: float = 3.0, rough: float = 0.95) -> StandardMaterial3D:
	var k := "f:%s:%s" % [c.to_html(), scale]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex("fur")
	m.albedo_color = c
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(scale, scale, scale)
	m.roughness = rough
	_cache[k] = m
	return m


static func emissive(c: Color, energy: float = 2.0, key: String = "") -> StandardMaterial3D:
	var k := "e:%s:%s:%s" % [c.to_html(), energy, key]
	if _cache.has(k) and key == "":
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	if key == "":
		_cache[k] = m
	return m


static func unique_emissive(c: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func image(tex_name: String, rough: float = 0.9, unshaded: bool = false) -> StandardMaterial3D:
	var k := "i:%s:%s" % [tex_name, unshaded]
	if _cache.has(k):
		return _cache[k]
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(tex_name)
	m.roughness = rough
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cache[k] = m
	return m
