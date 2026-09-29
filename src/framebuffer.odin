package main

// A CPU-side image we render into. Backend-agnostic on purpose: it knows
// nothing about raylib, WebGPU, or how it eventually reaches the screen.
// `Color` is laid out R,G,B,A as four bytes so it maps 1:1 onto an
// R8G8B8A8 GPU texture with no conversion.

Color :: struct {
	r, g, b, a: u8,
}

Framebuffer :: struct {
	width:  int,
	height: int,
	pixels: []Color, // row-major, length == width*height
}

framebuffer_create :: proc(width, height: int) -> Framebuffer {
	return Framebuffer{
		width  = width,
		height = height,
		pixels = make([]Color, width * height),
	}
}

framebuffer_destroy :: proc(fb: ^Framebuffer) {
	delete(fb.pixels)
	fb.pixels = nil
}

framebuffer_clear :: proc(fb: ^Framebuffer, c: Color) {
	for &p in fb.pixels {
		p = c
	}
}

// Bounds-checked on purpose while learning; swap to `#no_bounds_check`
// in the hot loop once the rasterizer is correct (step 03+).
framebuffer_set :: proc(fb: ^Framebuffer, x, y: int, c: Color) {
	if x < 0 || y < 0 || x >= fb.width || y >= fb.height {
		return
	}
	fb.pixels[y * fb.width + x] = c
}
