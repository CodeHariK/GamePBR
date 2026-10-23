package render

import "core:math"
import "core:testing"
import m "../math"

@(private = "file")
near :: proc(a, b: f32, eps: f32 = 1e-4) -> bool { return abs(a - b) < eps }

// A directional light is the same everywhere: L = −dir, radiance = color·I.
@(test)
test_directional_sample :: proc(t: ^testing.T) {
	l := directional_light(m.Vec3{0, -1, 0}, m.Vec3{1, 0.5, 0.25}, 2)
	for p in ([]m.Vec3{{0, 0, 0}, {100, -3, 7}}) {
		L, rad := light_sample(l, p)
		testing.expect(t, near(L.y, 1) && near(rad.x, 2) && near(rad.y, 1) && near(rad.z, 0.5))
	}
}

// Inverse-square: radiance = I / d², so doubling the distance quarters it.
@(test)
test_point_inverse_square :: proc(t: ^testing.T) {
	l := point_light(m.Vec3{0, 0, 0}, m.Vec3{1, 1, 1}, 8)
	L, r2 := light_sample(l, m.Vec3{0, 0, 2})
	_, r4 := light_sample(l, m.Vec3{0, 0, 4})
	testing.expect(t, near(L.z, -1))     // points back toward the light
	testing.expect(t, near(r2.x, 8.0 / 4.0))
	testing.expect(t, near(r4.x, r2.x / 4))
}

// A finite range fades to exactly 0 at the range and stays ≈ physical close in.
@(test)
test_point_range_window :: proc(t: ^testing.T) {
	l := point_light(m.Vec3{0, 0, 0}, m.Vec3{1, 1, 1}, 1, 10)
	_, close := light_sample(l, m.Vec3{1, 0, 0})
	_, edge := light_sample(l, m.Vec3{10, 0, 0})
	_, past := light_sample(l, m.Vec3{12, 0, 0})
	testing.expect(t, close.x > 0.99 && close.x <= 1.0) // window ≈ 1 at d = r/10
	testing.expect(t, edge.x == 0 && past.x == 0)
}

// Spot cone: full point-light radiance on axis, 0 outside the outer angle, and
// strictly in between for a direction between inner and outer.
@(test)
test_spot_cone :: proc(t: ^testing.T) {
	inner := math.to_radians_f32(15); outer := math.to_radians_f32(30)
	s := spot_light(m.Vec3{0, 0, 0}, m.Vec3{0, 0, -1}, m.Vec3{1, 1, 1}, 1, inner, outer)
	at := proc(s: Light, deg: f32) -> f32 {
		a := math.to_radians_f32(deg)
		_, r := light_sample(s, m.Vec3{math.sin(a), 0, -math.cos(a)}) // unit distance
		return r.x
	}
	testing.expect(t, near(at(s, 0), 1))
	testing.expect(t, near(at(s, 10), 1)) // inside inner cone
	mid := at(s, 22)
	testing.expect(t, mid > 0 && mid < 1)
	testing.expect(t, at(s, 35) == 0)
}

// Lights add linearly: two identical lights give exactly twice one light.
@(test)
test_lights_sum_linearly :: proc(t: ^testing.T) {
	mat := pbr_material(m.Vec3{0.8, 0.8, 0.8}, 0, 0.5)
	N := m.Vec3{0, 0, 1}; V := N; P := m.Vec3{}
	one := []Light{point_light(m.Vec3{0, 1, 2}, m.Vec3{1, 1, 1}, 4)}
	two := []Light{one[0], one[0]}
	c1 := ShadeCtx{model = .PBR, lights = one}
	c2 := ShadeCtx{model = .PBR, lights = two}
	a := shade_surface(&c1, mat, N, V, P, mat.albedo)
	b := shade_surface(&c2, mat, N, V, P, mat.albedo)
	testing.expect(t, a.x > 0 && near(b.x, 2 * a.x))
}

// No `lights` -> the step-09..12 single directional light path, unchanged.
@(test)
test_legacy_single_light_fallback :: proc(t: ^testing.T) {
	mat := pbr_material(m.Vec3{0.9, 0.4, 0.3}, 0, 0.3)
	dl := DirLight{dir = m.normalize(m.Vec3{-0.4, -0.7, -0.5}), color = {1, 1, 1}, intensity = 3}
	amb := m.Vec3{0.03, 0.03, 0.04}
	N := m.normalize(m.Vec3{0.2, 0.5, 1}); V := m.Vec3{0, 0, 1}
	ctx := ShadeCtx{model = .PBR, light = dl, ambient = amb}
	want := shade_cook_torrance(mat, dl, N, V, mat.albedo, amb)
	got := shade_surface(&ctx, mat, N, V, m.Vec3{}, mat.albedo)
	testing.expect(t, near(got.x, want.x) && near(got.y, want.y) && near(got.z, want.z))
}

// Emission is added on top, unlit — a black, unlit material shows exactly it.
@(test)
test_emissive_unlit :: proc(t: ^testing.T) {
	mat := Material{emissive = m.Vec3{1, 0.6, 0.2}}
	ctx := ShadeCtx{model = .PBR}
	c := shade_surface(&ctx, mat, m.Vec3{0, 0, 1}, m.Vec3{0, 0, 1}, m.Vec3{}, mat.albedo)
	testing.expect(t, near(c.x, 1) && near(c.y, 0.6) && near(c.z, 0.2))
}
