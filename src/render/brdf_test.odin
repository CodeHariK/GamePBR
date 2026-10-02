package render

import "core:fmt"
import "core:testing"
import m "../math"

// The Lambert BRDF is constant and equals albedo/π.
@(test)
test_lambert_brdf_value :: proc(t: ^testing.T) {
	f := lambert_brdf(m.Vec3{0.8, 0.8, 0.8})
	want := f32(0.8) / 3.14159265
	testing.expect(t, abs(f.x - want) < 1e-5)
}

// Energy conservation: the directional-hemispherical reflectance of a properly
// normalized Lambert surface integrates back to its albedo — no more, no less.
// This is the numeric proof that the 1/π factor is the right one.
@(test)
test_lambert_reflectance_equals_albedo :: proc(t: ^testing.T) {
	albedo := m.Vec3{0.6, 0.3, 0.9}
	R := lambert_reflectance(albedo, 128)
	fmt.printfln("  [brdf] Lambert reflectance = (%.4f, %.4f, %.4f), albedo = (0.60, 0.30, 0.90)", R.x, R.y, R.z)
	testing.expect(t, abs(R.x - 0.6) < 2e-3)
	testing.expect(t, abs(R.y - 0.3) < 2e-3)
	testing.expect(t, abs(R.z - 0.9) < 2e-3)
}

// A pure-white Lambert surface reflects exactly 1.0 (all incident light), the
// energy-conservation ceiling.
@(test)
test_white_lambert_reflects_unity :: proc(t: ^testing.T) {
	R := lambert_reflectance(m.Vec3{1, 1, 1}, 128)
	testing.expect(t, abs(R.x - 1.0) < 2e-3)
}

// The step-09 Blinn-Phong specular lobe is NOT energy-conserving: at a low
// exponent its reflectance integral blows past 1.0 — the surface returns more
// light than it receives. This is the concrete fault PBR's normalization fixes.
@(test)
test_blinn_phong_violates_energy :: proc(t: ^testing.T) {
	wo := m.Vec3{0, 0, 1} // viewing straight on
	broad := blinn_phong_reflectance(wo, 2, 128)
	tight := blinn_phong_reflectance(wo, 128, 128)
	fmt.printfln("  [brdf] Blinn-Phong reflectance: shininess 2 = %.3f (>1 = energy gain), shininess 128 = %.3f", broad, tight)
	testing.expect(t, broad > 1.0)  // gains energy
	testing.expect(t, tight < 1.0)  // loses energy — brightness untied from input
}
