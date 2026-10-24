package utils

import "core:math"
import "../fb"
import m "../math"

// --- Tonemapping: HDR radiance -> displayable [0,1] (step 14) ---
//
// The renderer produces radiance with no upper bound (a point light's 1/d²
// goes to infinity near the bulb). A display shows [0,1]. A tonemap operator
// is the curve that squeezes [0,∞) into [0,1) gracefully instead of clipping.
// Order of operations, per pixel:
//     exposure (×2^EV)  ->  tonemap operator  ->  sRGB encode  ->  8-bit

Tonemap :: enum {
	Clamp,    // no tonemapping: values > 1 clip to white (steps 09-13)
	Reinhard, // x / (1 + x): never clips, but flat and greyish
	ACES,     // filmic S-curve (Narkowicz fit): toe, mid contrast, soft shoulder
}

Display :: struct {
	op:          Tonemap,
	exposure_ev: f32,  // photographic stops: +1 doubles the light, -1 halves it
	srgb:        bool, // encode for display (false = the old "linear" look)
}

display_default :: proc() -> Display {
	return Display{op = .ACES, exposure_ev = 0, srgb = true}
}

// Reinhard, per channel: maps 0→0, 1→0.5, ∞→1. Monotonic and simple, but it
// compresses everything, so images look low-contrast.
tonemap_reinhard :: proc(c: m.Vec3) -> m.Vec3 {
	return m.Vec3{c.x / (1 + c.x), c.y / (1 + c.y), c.z / (1 + c.z)}
}

// Krzysztof Narkowicz's rational fit of the ACES filmic curve, per channel.
// A dark toe (deeper blacks), contrast through the mids, and a soft roll-off
// into white — the "film" look most engines default to.
tonemap_aces :: proc(c: m.Vec3) -> m.Vec3 {
	f :: proc(x: f32) -> f32 {
		a :: 2.51; b :: 0.03; cc :: 2.43; d :: 0.59; e :: 0.14
		return m.saturate((x * (a * x + b)) / (x * (cc * x + d) + e))
	}
	return m.Vec3{f(c.x), f(c.y), f(c.z)}
}

// HDR linear radiance -> display value in [0,1] (still before quantization).
display_transform :: proc(hdr: m.Vec3, d: Display) -> m.Vec3 {
	c := hdr * math.pow(f32(2), d.exposure_ev)
	switch d.op {
	case .Clamp:
		c = m.Vec3{m.saturate(c.x), m.saturate(c.y), m.saturate(c.z)}
	case .Reinhard:
		c = tonemap_reinhard(c)
	case .ACES:
		c = tonemap_aces(c)
	}
	if d.srgb {
		c = linear_to_srgb3(c)
	}
	return c
}

// Quantize to 8 bits, ROUNDING (to_color truncates, which biases dark by half a
// code value — invisible before, but it's the last step of the chain now).
encode_pixel :: proc(hdr: m.Vec3, d: Display) -> fb.Color {
	c := display_transform(hdr, d)
	q :: proc(x: f32) -> u8 { return u8(m.saturate(x) * 255 + 0.5) }
	return fb.Color{q(c.x), q(c.y), q(c.z), 255}
}

// Rewrite the 8-bit pixels from the HDR buffer through the display transform.
// Cheap and repeatable: the same render can be resolved many ways.
resolve :: proc(f: ^fb.Framebuffer, d: Display) {
	for h, i in f.hdr {
		f.pixels[i] = encode_pixel(m.Vec3(h), d)
	}
}
