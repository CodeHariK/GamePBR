package render

import "core:fmt"
import "core:math"
import "core:testing"
import m "../math"

@(private = "file")
near :: proc(a, b: f32, eps: f32 = 1e-4) -> bool { return abs(a - b) < eps }

@(private = "file")
fill_env :: proc(w, h: int, f: proc(d: m.Vec3) -> m.Vec3) -> EnvMap {
	e := env_create(w, h)
	for y in 0 ..< h {
		for x in 0 ..< w {
			e.px[y * w + x] = f(env_texel_dir(&e, x, y))
		}
	}
	return e
}

// −Z maps to the image centre, and dir → (u,v) → dir is the identity.
@(test)
test_equirect_round_trip :: proc(t: ^testing.T) {
	u, v := dir_to_equirect(m.Vec3{0, 0, -1})
	testing.expect(t, near(u, 0.5) && near(v, 0.5))
	for d in ([]m.Vec3{{1, 0, 0}, {0.3, 0.8, -0.2}, {-0.5, -0.5, 0.7}, {0, 0.2, 1}}) {
		n := m.normalize(d)
		uu, vv := dir_to_equirect(n)
		back := equirect_to_dir(uu, vv)
		testing.expect(t, near(back.x, n.x) && near(back.y, n.y) && near(back.z, n.z))
	}
}

// The texels tile the whole sphere: their solid angles sum to 4π.
@(test)
test_solid_angles_sum_to_4pi :: proc(t: ^testing.T) {
	e := env_create(64, 32)
	defer env_destroy(&e)
	total: f32 = 0
	for y in 0 ..< e.height {
		total += env_texel_solid_angle(&e, y) * f32(e.width)
	}
	testing.expect(t, abs(total - 4 * math.PI) < 0.01 * 4 * math.PI)
}

// A uniform environment of radiance L gives irradiance πL for EVERY normal —
// the cosine-weighted hemisphere integral is π, whichever way you face.
@(test)
test_uniform_env_irradiance_is_pi :: proc(t: ^testing.T) {
	env := fill_env(64, 32, proc(d: m.Vec3) -> m.Vec3 { return {1, 1, 1} })
	defer env_destroy(&env)
	irr := convolve_irradiance(&env, 16, 8)
	defer env_destroy(&irr)
	for p in irr.px {
		testing.expect(t, abs(p.x - math.PI) < 0.015 * math.PI)
	}
}

// Analytic check: a sky of radiance 1 above the horizon and black below. A
// surface tilted α from straight up sees E = π(1 + cos α)/2 = π(1 + N.y)/2:
// π facing up, π/2 facing the horizon, 0 facing the ground.
@(test)
test_half_sky_irradiance :: proc(t: ^testing.T) {
	env := fill_env(128, 64, proc(d: m.Vec3) -> m.Vec3 { return d.y > 0 ? m.Vec3{1, 1, 1} : m.Vec3{} })
	defer env_destroy(&env)
	irr := convolve_irradiance(&env, 16, 8)
	defer env_destroy(&irr)
	worst: f32 = 0
	for y in 0 ..< irr.height {
		for x in 0 ..< irr.width {
			N := env_texel_dir(&irr, x, y)
			want := math.PI * (1 + N.y) / 2
			worst = max(worst, abs(irr.px[y * irr.width + x].x - want))
		}
	}
	fmt.printfln("  [ibl] half-sky irradiance: worst abs error %.4f (of π = 3.1416)", worst)
	testing.expect(t, worst < 0.03)
}

// Box downsampling preserves the mean radiance exactly.
@(test)
test_downsample_preserves_mean :: proc(t: ^testing.T) {
	env := make_sky_env(64, 32, m.Vec3{0.5, 0.5, 0.5})
	defer env_destroy(&env)
	small := env_downsample(&env, 4)
	defer env_destroy(&small)
	mean :: proc(e: ^EnvMap) -> m.Vec3 {
		s := m.Vec3{}
		for p in e.px { s += p }
		return s / f32(len(e.px))
	}
	a := mean(&env); b := mean(&small)
	testing.expect(t, small.width == 16 && small.height == 8)
	testing.expect(t, abs(a.x - b.x) < 1e-3 * a.x)
}

// The procedural sky: the sun is far brighter than the sky, the ground darker.
@(test)
test_sky_layout :: proc(t: ^testing.T) {
	sun := m.normalize(m.Vec3{0.5, 0.5, 0.5})
	env := make_sky_env(256, 128, sun)
	defer env_destroy(&env)
	at_sun := env_sample(&env, sun)
	sky := env_sample(&env, m.normalize(m.Vec3{-0.5, 0.6, -0.5}))
	ground := env_sample(&env, m.Vec3{0, -1, 0})
	testing.expect(t, at_sun.x > 50 * sky.x)
	testing.expect(t, ground.y < sky.y)
}

// The centre pixel's ray is the camera's forward direction.
@(test)
test_camera_ray_centre :: proc(t: ^testing.T) {
	c := Camera{eye = {1, 2, 3}, target = {1, 2, 0}, up = {0, 1, 0}, fov_y = 1, aspect = 1}
	d := camera_ray(c, 50, 50, 101, 101)
	testing.expect(t, near(d.z, -1) && near(d.x, 0) && near(d.y, 0))
}

// Diffuse IBL in a uniform white sky: a rough white dielectric returns (1 − F0)
// of the sky radiance; a metal returns nothing (no diffuse lobe).
@(test)
test_ibl_diffuse_uniform :: proc(t: ^testing.T) {
	env := fill_env(64, 32, proc(d: m.Vec3) -> m.Vec3 { return {1, 1, 1} })
	defer env_destroy(&env)
	irr := convolve_irradiance(&env, 16, 8)
	defer env_destroy(&irr)
	N := m.Vec3{0, 1, 0}; V := N
	white := ibl_diffuse(pbr_material(m.Vec3{1, 1, 1}, 0, 1), N, V, m.Vec3{1, 1, 1}, &irr)
	metal := ibl_diffuse(pbr_material(m.Vec3{1, 1, 1}, 1, 1), N, V, m.Vec3{1, 1, 1}, &irr)
	testing.expect(t, abs(white.x - 0.96) < 0.02)
	testing.expect(t, metal.x < 1e-6)
}
