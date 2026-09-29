package fb

// A CPU image we render into. Backend-agnostic: it knows nothing about how it
// reaches the screen or disk. Row-major, origin at the top-left.
Framebuffer :: struct {
	width:  int,
	height: int,
	pixels: []Color, // length == width*height
}

create :: proc(width, height: int) -> Framebuffer {
	return Framebuffer{
		width  = width,
		height = height,
		pixels = make([]Color, width * height),
	}
}

destroy :: proc(f: ^Framebuffer) {
	delete(f.pixels)
	f.pixels = nil
}

clear :: proc(f: ^Framebuffer, c: Color) {
	for &p in f.pixels {
		p = c
	}
}

// Bounds-checked while learning; switch to #no_bounds_check in the hot loop
// once the rasterizer is correct (step 03+).
set :: proc(f: ^Framebuffer, x, y: int, c: Color) {
	if x < 0 || y < 0 || x >= f.width || y >= f.height {
		return
	}
	f.pixels[y * f.width + x] = c
}
