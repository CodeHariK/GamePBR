package utils

import "core:testing"
import "../fb"
import m "../math"

@(private = "file")
near :: proc(a, b: f32, eps: f32 = 1e-4) -> bool { return abs(a - b) < eps }

// Known points on the standard sRGB curve, and the toe/power seam.
@(test)
test_srgb_known_values :: proc(t: ^testing.T) {
	testing.expect(t, near(linear_to_srgb(0), 0))
	testing.expect(t, near(linear_to_srgb(1), 1))
	testing.expect(t, near(linear_to_srgb(0.0031308), 0.04045, 1e-4))
	testing.expect(t, near(linear_to_srgb(0.5), 0.7354, 1e-3)) // mid-grey reads bright
	testing.expect(t, near(srgb_to_linear(0.5), 0.2140, 1e-3)) // and vice versa
}

// Decode ∘ encode is the identity across the range.
@(test)
test_srgb_round_trip :: proc(t: ^testing.T) {
	for i in 0 ..= 100 {
		x := f32(i) / 100
		testing.expect(t, near(srgb_to_linear(linear_to_srgb(x)), x, 1e-5))
	}
}

// Reinhard: 0→0, 1→½, monotonic, and never reaches 1 (no clipping).
@(test)
test_reinhard_curve :: proc(t: ^testing.T) {
	testing.expect(t, near(tonemap_reinhard(m.Vec3{0, 0, 0}).x, 0))
	testing.expect(t, near(tonemap_reinhard(m.Vec3{1, 1, 1}).x, 0.5))
	prev: f32 = -1
	for x in ([]f32{0.1, 0.5, 1, 4, 16, 1000}) {
		y := tonemap_reinhard(m.Vec3{x, x, x}).x
		testing.expect(t, y > prev && y < 1)
		prev = y
	}
}

// ACES fit: near-black at 0, monotonic, and saturates to white for very bright
// input instead of clipping a whole region abruptly.
@(test)
test_aces_curve :: proc(t: ^testing.T) {
	testing.expect(t, tonemap_aces(m.Vec3{0, 0, 0}).x < 1e-6)
	prev: f32 = -1
	for x in ([]f32{0.05, 0.18, 0.5, 1, 2, 4}) {
		y := tonemap_aces(m.Vec3{x, x, x}).x
		testing.expect(t, y > prev)
		prev = y
	}
	testing.expect(t, near(tonemap_aces(m.Vec3{100, 100, 100}).x, 1, 1e-3))
}

// Exposure is in stops: +1 EV doubles the radiance before the operator.
@(test)
test_exposure_stops :: proc(t: ^testing.T) {
	d := Display{op = .Clamp, exposure_ev = 1, srgb = false}
	testing.expect(t, near(display_transform(m.Vec3{0.25, 0.25, 0.25}, d).x, 0.5))
	d.exposure_ev = -2
	testing.expect(t, near(display_transform(m.Vec3{0.8, 0.8, 0.8}, d).x, 0.2))
}

// A background stored as srgb_to_linear(bg) resolves back to exactly bg under
// clamp + sRGB — the round trip the scenes rely on.
@(test)
test_resolve_background_round_trip :: proc(t: ^testing.T) {
	f := fb.create(4, 2)
	defer fb.destroy(&f)
	bg := fb.Color{10, 10, 14, 255}
	fb.clear_hdr(&f, srgb_to_linear3(to_vec3(bg)))
	resolve(&f, Display{op = .Clamp, srgb = true})
	for p in f.pixels {
		testing.expect(t, p == bg)
	}
}
