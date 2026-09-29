package main

import m "math"

// Bridge between the packed 8-bit framebuffer `Color` and the float color
// (`m.Vec3`) used for lighting math. Shading happens in float; we only pack to
// 8-bit at the very end (present).
//
// This lives in `main`, NOT in the pure `math` package, because it depends on
// `Color` (from the framebuffer). Keeping it out leaves `math` dependency-free:
// math <- framebuffer <- main.
//
// NOTE: linear 0..1 mapping for now. Correct sRGB <-> linear (gamma) conversion
// is its own milestone — see step 14.

color_to_vec3 :: proc(c: Color) -> m.Vec3 {
	return m.Vec3{f32(c.r) / 255, f32(c.g) / 255, f32(c.b) / 255}
}

vec3_to_color :: proc(v: m.Vec3) -> Color {
	return Color{
		r = u8(m.saturate(v.x) * 255),
		g = u8(m.saturate(v.y) * 255),
		b = u8(m.saturate(v.z) * 255),
		a = 255,
	}
}
