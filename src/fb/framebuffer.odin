package fb

// A CPU render target: a color buffer plus a matching depth buffer, so
// overlapping triangles can be resolved by distance rather than draw order.
// Backend-agnostic. Row-major, origin at the top-left.
Framebuffer :: struct {
	width:  int,
	height: int,
	pixels: []Color,  // length == width*height; display-ready 8-bit
	depth:  []f32,    // length == width*height; smaller = nearer
	hdr:    [][3]f32, // length == width*height; linear radiance, unclamped (step 14)
}

create :: proc(width, height: int) -> Framebuffer {
	return Framebuffer{
		width  = width,
		height = height,
		pixels = make([]Color, width * height),
		depth  = make([]f32, width * height),
		hdr    = make([][3]f32, width * height),
	}
}

destroy :: proc(f: ^Framebuffer) {
	delete(f.pixels)
	delete(f.depth)
	delete(f.hdr)
	f.pixels = nil
	f.depth = nil
	f.hdr = nil
}

// Fill the HDR buffer with a LINEAR radiance (e.g. a background "sky" value).
// Kept separate from clear(): the 8-bit and HDR backgrounds live in different
// color spaces, so the caller states both explicitly.
clear_hdr :: proc(f: ^Framebuffer, c: [3]f32) {
	for &p in f.hdr {
		p = c
	}
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
