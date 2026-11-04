class_name PixelCanvas
extends RefCounted
## Pixel drawing primitives for the placeholder art generator
## (`tools/gen_placeholder_art.gd`).
##
## Every rule in art bible section 8 that a tool CAN enforce is enforced here
## rather than trusted: the outline is derived from the alpha silhouette so it
## is exactly 1 px and never thinner, [method colour_count] can be asserted
## against the per-category cap in 8.3, and nothing is drawn with a float
## coordinate.
##
## Not a renderer. These PNGs are placeholders: correct size, correct palette,
## correct outline, correct pivot. They are deliberately geometric, so nobody
## mistakes them for final art, and they make the whole pipeline real (import
## settings, folders, naming, atlas cells) so hand-drawn sprites are a file
## swap and not a port.

var image: Image
var w: int
var h: int


func _init(width: int, height: int) -> void:
	w = width
	h = height
	image = Image.create(width, height, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))


func px(x: int, y: int, c: Color) -> void:
	if x >= 0 and x < w and y >= 0 and y < h:
		image.set_pixel(x, y, c)


func get_px(x: int, y: int) -> Color:
	if x < 0 or x >= w or y < 0 or y >= h:
		return Color(0, 0, 0, 0)
	return image.get_pixel(x, y)


func rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for j: int in range(y, y + rh):
		for i: int in range(x, x + rw):
			px(i, j, c)


## A filled rect centred on `cx`, which is how a symmetric airframe is built.
func rect_centred(cx: int, y: int, rw: int, rh: int, c: Color) -> void:
	rect(cx - rw / 2, y, rw, rh, c)


func ellipse(cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	if rx <= 0 or ry <= 0:
		return
	for j: int in range(cy - ry, cy + ry + 1):
		for i: int in range(cx - rx, cx + rx + 1):
			var dx := float(i - cx) / float(rx)
			var dy := float(j - cy) / float(ry)
			if dx * dx + dy * dy <= 1.0:
				px(i, j, c)


## A trapezoid: `top_w` wide at `y`, `bottom_w` wide at `y + th`. Wings and
## tailplanes are all trapezoids, which is what keeps the silhouettes chunky
## rather than organic (art bible 3.1).
func trapezoid(cx: int, y: int, top_w: int, bottom_w: int, th: int, c: Color) -> void:
	for j: int in range(th):
		var t := float(j) / float(maxi(1, th - 1))
		var width := roundi(lerpf(float(top_w), float(bottom_w), t))
		rect_centred(cx, y + j, maxi(1, width), 1, c)


## A capsule from (x0,y0) to (x1,y1): the shape a rice or needle bullet is.
func capsule(x0: int, y0: int, x1: int, y1: int, radius: int, c: Color) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0)) + 1
	for s: int in range(steps):
		var t := float(s) / float(maxi(1, steps - 1))
		ellipse(
			roundi(lerpf(float(x0), float(x1), t)),
			roundi(lerpf(float(y0), float(y1), t)),
			radius,
			radius,
			c
		)


## Copies the left half onto the right, so a symmetric sprite is drawn once
## and cannot end up lopsided by a pixel.
func mirror_left_to_right() -> void:
	for y: int in range(h):
		for x: int in range(w / 2):
			var c := get_px(x, y)
			if c.a > 0.0:
				px(w - 1 - x, y, c)


## 1 px outline around the whole silhouette, 8-connected, drawn only into
## transparent pixels so it never eats the body (art bible 5.7: 1 px Ink for
## popcorn, 2 px for large — call it twice for 2 px).
func outline(c: Color) -> void:
	var edge: Array[Vector2i] = []
	for y: int in range(h):
		for x: int in range(w):
			if get_px(x, y).a > 0.0:
				continue
			var touching := false
			for dy: int in range(-1, 2):
				for dx: int in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if get_px(x + dx, y + dy).a > 0.0:
						touching = true
			if touching:
				edge.push_back(Vector2i(x, y))
	for p: Vector2i in edge:
		px(p.x, p.y, c)


## Replaces `from` with `to` wherever it appears. The cheap palette swap the
## art bible's production plan is built on (section 6.3).
func swap(from: Color, to: Color) -> void:
	for y: int in range(h):
		for x: int in range(w):
			if get_px(x, y).is_equal_approx(from):
				px(x, y, to)


## A top-left lit highlight: one tone up on the upper-left face of the body,
## which is the one light direction 1941 and the 1970s use (art bible 6.3).
func highlight_top_left(body: Color, light: Color) -> void:
	for y: int in range(h):
		for x: int in range(w):
			if not get_px(x, y).is_equal_approx(body):
				continue
			if get_px(x - 1, y).a == 0.0 or get_px(x, y - 1).a == 0.0:
				px(x, y, light)


## Ordered 2x2 dither of `c` over the region, for sky and haze only, and the
## generator only ever calls it in the edge zone (art bible 6.3 bans a dot
## grid inside the central lane).
func dither_rect(x: int, y: int, rw: int, rh: int, c: Color) -> void:
	for j: int in range(y, y + rh):
		for i: int in range(x, x + rw):
			if (i + j) % 2 == 0:
				px(i, j, c)


## How many distinct colours the sprite uses, excluding transparent. Checked
## against the 8.3 cap, because a placeholder that breaks the colour budget
## would teach the wrong thing about the pipeline.
func colour_count() -> int:
	var seen := {}
	for y: int in range(h):
		for x: int in range(w):
			var c := get_px(x, y)
			if c.a > 0.0:
				seen[c.to_rgba32()] = true
	return seen.size()


## True if anything is drawn outside the box the size tier allows.
func bounds() -> Rect2i:
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y: int in range(h):
		for x: int in range(w):
			if get_px(x, y).a > 0.0:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


func blit(other: PixelCanvas, at_x: int, at_y: int) -> void:
	for y: int in range(other.h):
		for x: int in range(other.w):
			var c := other.get_px(x, y)
			if c.a > 0.0:
				px(at_x + x, at_y + y, c)


func save(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := image.save_png(path)
	assert(err == OK, "could not write %s" % path)
