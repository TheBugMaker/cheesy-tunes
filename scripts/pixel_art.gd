class_name PixelArt
extends RefCounted
## Tiny helper: build crisp pixel-art Texture2D from string-grid patterns.
## Use a single character per pixel; map characters to colors via a palette.

## Build a Texture2D from a string-grid pattern.
##  - pattern: Array of equal-length Strings, one row per entry
##  - palette: Dictionary[String, Color] keyed by single chars
##             unknown chars (e.g. ".") become fully transparent
##  - scale:   integer nearest-neighbour multiplier for chunky display
static func texture_from_pattern(
	pattern: Array, palette: Dictionary, scale: int = 1
) -> Texture2D:
	var h: int = pattern.size()
	var first: String = pattern[0]
	var w: int = first.length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in range(h):
		var row: String = pattern[y]
		for x in range(w):
			var ch: String = row.substr(x, 1)
			var color: Color = palette.get(ch, Color(0, 0, 0, 0))
			img.set_pixel(x, y, color)
	if scale > 1:
		img.resize(w * scale, h * scale, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
