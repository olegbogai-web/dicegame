extends RefCounted
class_name DiceIconLibrary

const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

var _cache: Dictionary = {}

func build_icon_texture(icon_id: StringName, color: Color, size: int = 256) -> Texture2D:
	var cache_key := "%s|%s|%s" % [String(icon_id), color.to_html(), size]
	if _cache.has(cache_key):
		return _cache[cache_key]

	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(TRANSPARENT)

	match String(icon_id):
		"shield":
			_draw_shield(image, color)
		"diamond":
			_draw_diamond(image, color)
		"sword":
			_draw_sword(image, color)
		"cross":
			_draw_cross(image, color)
		_:
			_draw_star(image, color)

	var texture := ImageTexture.create_from_image(image)
	_cache[cache_key] = texture
	return texture

func _draw_star(image: Image, color: Color) -> void:
	var points := PackedVector2Array()
	var center := Vector2(image.get_width(), image.get_height()) * 0.5
	var outer_radius := image.get_width() * 0.34
	var inner_radius := image.get_width() * 0.15

	for point_index in 10:
		var angle := -PI * 0.5 + point_index * PI / 5.0
		var radius := outer_radius if point_index % 2 == 0 else inner_radius
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)

	_fill_polygon(image, points, color)

func _draw_diamond(image: Image, color: Color) -> void:
	var size := Vector2(image.get_width(), image.get_height())
	var center := size * 0.5
	var points := PackedVector2Array([
		Vector2(center.x, size.y * 0.18),
		Vector2(size.x * 0.82, center.y),
		Vector2(center.x, size.y * 0.82),
		Vector2(size.x * 0.18, center.y),
	])
	_fill_polygon(image, points, color)

func _draw_shield(image: Image, color: Color) -> void:
	var size := Vector2(image.get_width(), image.get_height())
	var points := PackedVector2Array([
		Vector2(size.x * 0.32, size.y * 0.18),
		Vector2(size.x * 0.68, size.y * 0.18),
		Vector2(size.x * 0.78, size.y * 0.35),
		Vector2(size.x * 0.72, size.y * 0.62),
		Vector2(size.x * 0.5, size.y * 0.86),
		Vector2(size.x * 0.28, size.y * 0.62),
		Vector2(size.x * 0.22, size.y * 0.35),
	])
	_fill_polygon(image, points, color)

func _draw_sword(image: Image, color: Color) -> void:
	var size := Vector2(image.get_width(), image.get_height())
	_fill_polygon(image, PackedVector2Array([
		Vector2(size.x * 0.45, size.y * 0.18),
		Vector2(size.x * 0.55, size.y * 0.18),
		Vector2(size.x * 0.58, size.y * 0.58),
		Vector2(size.x * 0.42, size.y * 0.58),
	]), color)
	_fill_polygon(image, PackedVector2Array([
		Vector2(size.x * 0.3, size.y * 0.55),
		Vector2(size.x * 0.7, size.y * 0.55),
		Vector2(size.x * 0.62, size.y * 0.66),
		Vector2(size.x * 0.38, size.y * 0.66),
	]), color)
	_fill_polygon(image, PackedVector2Array([
		Vector2(size.x * 0.47, size.y * 0.66),
		Vector2(size.x * 0.53, size.y * 0.66),
		Vector2(size.x * 0.6, size.y * 0.82),
		Vector2(size.x * 0.4, size.y * 0.82),
	]), color)
	_fill_polygon(image, PackedVector2Array([
		Vector2(size.x * 0.42, size.y * 0.18),
		Vector2(size.x * 0.5, size.y * 0.07),
		Vector2(size.x * 0.58, size.y * 0.18),
	]), color)

func _draw_cross(image: Image, color: Color) -> void:
	var size := Vector2(image.get_width(), image.get_height())
	_fill_polygon(image, PackedVector2Array([
		Vector2(size.x * 0.42, size.y * 0.18),
		Vector2(size.x * 0.58, size.y * 0.18),
		Vector2(size.x * 0.58, size.y * 0.42),
		Vector2(size.x * 0.82, size.y * 0.42),
		Vector2(size.x * 0.82, size.y * 0.58),
		Vector2(size.x * 0.58, size.y * 0.58),
		Vector2(size.x * 0.58, size.y * 0.82),
		Vector2(size.x * 0.42, size.y * 0.82),
		Vector2(size.x * 0.42, size.y * 0.58),
		Vector2(size.x * 0.18, size.y * 0.58),
		Vector2(size.x * 0.18, size.y * 0.42),
		Vector2(size.x * 0.42, size.y * 0.42),
	]), color)

func _fill_polygon(image: Image, points: PackedVector2Array, color: Color) -> void:
	var min_y := int(floor(_get_min_y(points)))
	var max_y := int(ceil(_get_max_y(points)))

	for y in range(clamp(min_y, 0, image.get_height() - 1), clamp(max_y, 0, image.get_height() - 1) + 1):
		var intersections: Array[float] = []
		for point_index in points.size():
			var a := points[point_index]
			var b := points[(point_index + 1) % points.size()]
			if is_equal_approx(a.y, b.y):
				continue
			var is_between := (y >= min(a.y, b.y)) and (y < max(a.y, b.y))
			if not is_between:
				continue
			var ratio := (y - a.y) / (b.y - a.y)
			intersections.append(a.x + (b.x - a.x) * ratio)

		intersections.sort()
		for intersection_index in range(0, intersections.size(), 2):
			if intersection_index + 1 >= intersections.size():
				break
			var start_x := int(floor(intersections[intersection_index]))
			var end_x := int(ceil(intersections[intersection_index + 1]))
			for x in range(clamp(start_x, 0, image.get_width() - 1), clamp(end_x, 0, image.get_width() - 1) + 1):
				image.set_pixel(x, y, color)

func _get_min_y(points: PackedVector2Array) -> float:
	var value := INF
	for point in points:
		value = min(value, point.y)
	return value

func _get_max_y(points: PackedVector2Array) -> float:
	var value := -INF
	for point in points:
		value = max(value, point.y)
	return value
