package render

import "core:fmt"
import "core:testing"
import m "../math"

@(private = "file")
uniform_env :: proc(w, h: int, v: f32) -> EnvMap {
	e := env_create(w, h)
	for &p in e.px { p = m.Vec3{v, v, v} }
	return e
}

// Van der Corput: mirror the bits around the binary point.
@(test)
test_radical_inverse :: proc(t: ^testing.T) {
	testing.expect(t, radical_inverse_vdc(0) == 0)
	testing.expect(t, radical_inverse_vdc(1) == 0.5)
	testing.expect(t, radical_inverse_vdc(2) == 0.25)
	testing.expect(t, radical_inverse_vdc(3) == 0.75)
	testing.expect(t, radical_inverse_vdc(4) == 0.125)
}

// GGX samples are unit half-vectors in N's hemisphere, and they bunch toward N
// as the surface gets smoother.
@(test)
test_ggx_samples :: proc(t: ^testing.T) {
	N := m.normalize(m.Vec3{0.3, 0.8, -0.5})
	mean_cos :: proc(N: m.Vec3, r: f32) -> f32 {
		s: f32 = 0
		for i in 0 ..< 256 {
			H := importance_sample_ggx(hammersley(i, 256), N, r)
			s += m.dot(N, H)
		}
		return s / 256
	}
	for i in 0 ..< 64 {
		H := importance_sample_ggx(hammersley(i, 64), N, 0.6)
		testing.expect(t, abs(m.length(H) - 1) < 1e-4 && m.dot(N, H) > 0)
	}
	smooth := mean_cos(N, 0.05); mid := mean_cos(N, 0.5); rough := mean_cos(N, 1)
	testing.expect(t, smooth > 0.999 && smooth > mid && mid > rough)
}

// The LUT is a reflectance: F0·A + B with F0 = 1 is the specular albedo, never
// above 1. Smooth surfaces seen head-on reflect ~everything (A ≈ 1, B ≈ 0);
// rough ones lose some to single-scattering (a known limitation of the model).
@(test)
test_brdf_lut_bounds :: proc(t: ^testing.T) {
	lut := make_brdf_lut(16, 256)
	defer brdf_lut_destroy(&lut)
	for ab in lut.ab {
		testing.expect(t, ab.x >= 0 && ab.y >= 0 && ab.x + ab.y <= 1.01)
	}
	smooth := integrate_brdf(0.95, 0.05, 1024)
	rough := integrate_brdf(0.95, 1.0, 1024)
	fmt.printfln("  [ibl] LUT (n·v .95): r=.05 A=%.3f B=%.3f | r=1 A=%.3f B=%.3f",
		smooth.x, smooth.y, rough.x, rough.y)
	testing.expect(t, smooth.x + smooth.y > 0.95 && smooth.y < 0.05)
	testing.expect(t, rough.x + rough.y < smooth.x + smooth.y)
}

// Prefiltering a uniform sky changes nothing (a blur of a constant is that
// constant), and level 0 — a perfect mirror — is the environment itself.
@(test)
test_prefilter_uniform_and_mirror :: proc(t: ^testing.T) {
	env := uniform_env(32, 16, 2)
	defer env_destroy(&env)
	levels := prefilter_env(&env, 64)
	defer for &l in levels { env_destroy(&l) }
	for l, i in levels {
		for p in l.px {
			testing.expect(t, abs(p.x - 2) < 0.04, fmt.tprintf("level %d: %.4f", i, p.x))
		}
	}
	testing.expect(t, levels[0].width == env.width && levels[0].px[5] == env.px[5])
}

// White furnace: in a uniform white sky (L = 1 everywhere) a surface can at
// most return all of it. Total IBL (diffuse + specular) must never exceed 1 —
// the energy-conservation check for the whole IBL. Smooth surfaces return ~all
// of it. Rough METALS return noticeably less: single-scattering GGX drops the
// light that bounces between microfacets more than once (≈ 65% lost at
// roughness 1 — verified against a brute-force integral, see docs/16). For a
// metal (F0 = 1, no diffuse) the furnace value is exactly the LUT's A + B.
@(test)
test_white_furnace :: proc(t: ^testing.T) {
	env := uniform_env(32, 16, 1)
	defer env_destroy(&env)
	s := IBLSettings{irr_downsample = 1, irr_w = 16, irr_h = 8, prefilter_samples = 64, lut_size = 16, lut_samples = 256}
	maps := make_ibl_maps(&env, s)
	defer ibl_maps_destroy(&maps)
	N := m.Vec3{0, 1, 0}
	V := m.normalize(m.Vec3{0.3, 1, 0.2}) // slightly off-normal
	white := m.Vec3{1, 1, 1}
	for metal in ([]f32{0, 1}) {
		for r in ([]f32{0.05, 0.5, 1}) {
			c := ibl_total(pbr_material(white, metal, r), N, V, white, &maps)
			fmt.printfln("  [ibl] furnace metal=%.0f rough=%.2f -> %.3f", metal, r, c.x)
			testing.expect(t, c.x <= 1.02)                // never gains energy
			if r < 0.1 { testing.expect(t, c.x > 0.97) } // smooth: returns ~all
			if metal == 1 {
				ab := brdf_lut_sample(&maps.lut, m.dot(N, V), r)
				testing.expect(t, abs(c.x - (ab.x + ab.y)) < 0.02) // = specular albedo
			}
		}
	}
}
