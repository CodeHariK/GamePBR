package utils

import "../fb"
import m "../math"

// Bridge between the packed 8-bit framebuffer color and the float color
// (m.Vec3) used for lighting math. Shading is done in float; we pack to 8-bit
// only at the end. Linear 0..1 for now — sRGB/gamma is step 14.

to_vec3 :: proc(c: fb.Color) -> m.Vec3 {
	return m.Vec3{f32(c.r) / 255, f32(c.g) / 255, f32(c.b) / 255}
}

to_color :: proc(v: m.Vec3) -> fb.Color {
	return fb.Color{
		r = u8(m.saturate(v.x) * 255),
		g = u8(m.saturate(v.y) * 255),
		b = u8(m.saturate(v.z) * 255),
		a = 255,
	}
}
