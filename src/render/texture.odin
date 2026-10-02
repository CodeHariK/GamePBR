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

// A tangent-space normal map: an "egg-carton" bump field, with each texel the
// surface normal encoded as RGB = normal*0.5 + 0.5.
make_normal_map :: proc(size, bumps: int) -> Texture {
	t := Texture{width = size, height = size, pixels = make([]fb.Color, size * size)}
	freq := f32(bumps) * 2 * math.PI / f32(size)
	slope := f32(0.8)
	for y in 0 ..< size {
		for x in 0 ..< size {
			fx := freq * f32(x)
			fy := freq * f32(y)
			// height h = sin(fx)*sin(fy); normal = normalize(-dh/dx, -dh/dy, 1)
			n := m.normalize(m.Vec3{-slope * math.cos(fx) * math.sin(fy), -slope * math.sin(fx) * math.cos(fy), 1})
			e := n * 0.5 + m.Vec3{0.5, 0.5, 0.5}
			t.pixels[y * size + x] = fb.Color{u8(e.x * 255), u8(e.y * 255), u8(e.z * 255), 255}
		}
	}
	return t
}

// Decode a normal-map texel to a tangent-space normal in [-1,1].
sample_normal :: proc(t: ^Texture, u, v: f32) -> m.Vec3 {
	c := sample(t, u, v) // [0,1]
	return m.normalize(c * 2 - m.Vec3{1, 1, 1})
}
