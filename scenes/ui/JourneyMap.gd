## JourneyMap — end-of-run "business intelligence" recap.
##
## Draws a top-down ribbon of the road you ran, coloured by the biomes you passed
## through (bottom = START, top = where you wrecked), with a pin at your final
## distance and a block of run stats. Pure custom drawing — no assets required.

extends Control

## Biome band colours (keep in sync with Highway.THEMES names).
const BIOME_COLORS := {
	"DOWNTOWN": Color(0.42, 0.52, 0.95),
	"COUNTRYSIDE": Color(0.42, 0.80, 0.45),
	"INDUSTRIAL": Color(0.92, 0.62, 0.30),
	"NEON CITY": Color(0.85, 0.35, 0.92),
}

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func refresh() -> void:
	queue_redraw()


func _dist_to_y(d: float, top_y: float, bottom_y: float, total: float) -> float:
	return lerpf(bottom_y, top_y, clampf(d / total, 0.0, 1.0))


func _draw() -> void:
	var w := size.x
	var h := size.y

	# Panel background.
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.92)
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.40, 0.60, 1.0, 0.5)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))

	draw_string(_font, Vector2(18, 32), "YOUR JOURNEY", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.82, 0.93, 1.0))

	var top_y := 56.0
	var bottom_y := h - 188.0
	var ribbon_x := w * 0.5
	var ribbon_w := 56.0

	var total: float = maxf(GameManager.run_distance, 1.0)
	var log: Array = GameManager.biome_log

	# Biome bands (bottom = start of run, top = final distance).
	for i in log.size():
		var entry: Dictionary = log[i]
		var seg_start: float = float(entry.get("start", 0.0))
		var seg_end: float = total
		if i + 1 < log.size():
			seg_end = float(log[i + 1].get("start", total))
		var y0 := _dist_to_y(seg_end, top_y, bottom_y, total)    # nearer top
		var y1 := _dist_to_y(seg_start, top_y, bottom_y, total)  # nearer bottom
		var col: Color = BIOME_COLORS.get(entry.get("name", ""), Color(0.5, 0.5, 0.55))
		draw_rect(Rect2(ribbon_x - ribbon_w * 0.5, y0, ribbon_w, y1 - y0), col)
		# Biome label beside the band.
		if y1 - y0 > 18.0:
			draw_string(_font, Vector2(ribbon_x + ribbon_w * 0.5 + 8.0, (y0 + y1) * 0.5 + 5.0),
				str(entry.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col.lightened(0.3))

	# Centre dashes down the ribbon.
	var dash_col := Color(1, 1, 1, 0.7)
	var dy := top_y
	while dy < bottom_y:
		draw_rect(Rect2(ribbon_x - 2.0, dy, 4.0, 12.0), dash_col)
		dy += 22.0

	# START marker (bottom).
	draw_string(_font, Vector2(ribbon_x - ribbon_w * 0.5 - 4.0, bottom_y + 22.0), "START", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.7, 0.8, 0.9))

	# "YOU" pin at the final distance (top).
	var pin_y := top_y
	draw_circle(Vector2(ribbon_x, pin_y), 8.0, Color(1.0, 0.85, 0.2))
	draw_circle(Vector2(ribbon_x, pin_y), 4.0, Color(0.2, 0.1, 0.0))
	draw_string(_font, Vector2(ribbon_x + 14.0, pin_y + 5.0), "%dm" % int(GameManager.run_distance), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.4))

	# Stats block.
	_draw_stats(16.0, h - 150.0, w - 32.0)


func _draw_stats(x: float, y: float, w: float) -> void:
	var rows := [
		["DISTANCE", "%d m" % int(GameManager.run_distance)],
		["TIME", "%.1f s" % GameManager.time_elapsed],
		["TOP SPEED", "%d km/h" % int(GameManager.top_speed * 3.6)],
		["DODGES", "%d" % ProgressionManager.dodge_count],
		["GUNS", "%d" % GunManager.owned.size()],
		["COINS", "+%d" % GameManager.last_coins_earned],
	]
	var line_h := 22.0
	var label_col := Color(0.65, 0.75, 0.88)
	var value_col := Color(1.0, 1.0, 1.0)
	for i in rows.size():
		var ry := y + line_h * float(i) + 14.0
		draw_string(_font, Vector2(x, ry), str(rows[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, label_col)
		draw_string(_font, Vector2(x, ry), str(rows[i][1]), HORIZONTAL_ALIGNMENT_RIGHT, w, 15, value_col)
