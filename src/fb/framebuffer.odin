package fb

// A CPU render target: a color buffer plus a matching depth buffer, so
// overlapping triangles can be resolved by distance rather than draw order.
// Backend-agnostic. Row-major, origin at the top-left.
Framebuffer :: struct {
	width:  int,
	height: int,
	pixels: []Color, // length == width*height
	depth:  []f32,   // length == width*height; smaller = nearer
}

create :: proc(width, height: int) -> Framebuffer {
	return Framebuffer{
		width  = width,
		height = height,
		pixels = make([]Color, width * height),
		depth  = make([]f32, width * height),
	}
}

destroy :: proc(f: ^Framebuffer) {
	delete(f.pixels)
	delete(f.depth)
	f.pixels = nil
	f.depth = nil
}

clear :: proc(f: ^Framebuffer, c: Color) {
	for &p in f.pixels {
		p = c
	}
}

// Reset every depth to `value` (the far plane, e.g. 1.0). Do this each frame
// before drawing, alongside clear().
clear_depth :: proc(f: ^Framebuffer, value: f32) {
	for &d in f.depth {
		d = value
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
