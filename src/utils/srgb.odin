package utils

import "core:math"
import m "../math"

// --- sRGB transfer functions (step 14) ---
//
// Lighting math must happen on LINEAR values (twice the photons = twice the
// number). Displays and 8-bit images expect sRGB-ENCODED values, which spend
// more code values on darks, where eyes are most sensitive. So:
//     textures authored in sRGB  --decode-->  linear  --shade-->  linear
//     --tonemap--> [0,1] linear  --encode-->  sRGB  --quantize--> 8-bit
// The exact IEC 61966-2-1 curves: a short linear toe, then a 2.4 power.
// (A plain pow(x, 1/2.2) is a close approximation but not the standard.)

linear_to_srgb :: proc(x: f32) -> f32 {
	c := m.saturate(x)
	if c <= 0.0031308 {
		return 12.92 * c
	}
	return 1.055 * math.pow(c, 1.0 / 2.4) - 0.055
}

srgb_to_linear :: proc(x: f32) -> f32 {
	c := m.saturate(x)
	if c <= 0.04045 {
		return c / 12.92
	}
	return math.pow((c + 0.055) / 1.055, 2.4)
}

linear_to_srgb3 :: proc(c: m.Vec3) -> m.Vec3 {
	return m.Vec3{linear_to_srgb(c.x), linear_to_srgb(c.y), linear_to_srgb(c.z)}
}

srgb_to_linear3 :: proc(c: m.Vec3) -> m.Vec3 {
	return m.Vec3{srgb_to_linear(c.x), srgb_to_linear(c.y), srgb_to_linear(c.z)}
}
