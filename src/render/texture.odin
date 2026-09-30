package render

import "core:math"
import "../fb"
import m "../math"

Texture :: struct {
	width:  int,
	height: int,
	pixels: []fb.Color,
}

texture_destroy :: proc(t: ^Texture) {
	delete(t.pixels)
	t^ = {}
}

// Nearest-neighbor sample with UV wrap (repeat). v is flipped so uv (0,0) is
// the bottom-left, matching the OBJ texture-coordinate convention.
sample :: proc(t: ^Texture, u, v: f32) -> m.Vec3 {
	if t.width == 0 || t.height == 0 {
		return m.Vec3{1, 0, 1} // magenta = "no texture"
	}
	uu := u - math.floor(u) // wrap to [0,1)
	vv := v - math.floor(v)
	x := int(uu * f32(t.width))
	y := int((1.0 - vv) * f32(t.height))
	if x >= t.width  { x = t.width - 1 }
	if y >= t.height { y = t.height - 1 }
	if x < 0 { x = 0 }
	if y < 0 { y = 0 }
	c := t.pixels[y * t.width + x]
	return m.Vec3{f32(c.r) / 255, f32(c.g) / 255, f32(c.b) / 255}
}

// A checkerboard texture, `checks` cells across each axis.
make_checker :: proc(size, checks: int, c0, c1: fb.Color) -> Texture {
	t := Texture{width = size, height = size, pixels = make([]fb.Color, size * size)}
	cell := max(size / checks, 1)
	for y in 0 ..< size {
		for x in 0 ..< size {
			on := ((x / cell) + (y / cell)) % 2 == 0
			t.pixels[y * size + x] = on ? c0 : c1
		}
	}
	return t
}
