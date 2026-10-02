package render

import "core:fmt"
import "core:math"
import "core:testing"
import m "../math"

// Fresnel-Schlick endpoints: at normal incidence F = F0; at grazing (cosθ→0)
// every surface approaches a perfect mirror, F → 1.
@(test)
test_fresnel_endpoints :: proc(t: ^testing.T) {
	F0 := m.Vec3{0.04, 0.04, 0.04}
	head := fresnel_schlick(1.0, F0)
	graze := fresnel_schlick(0.0, F0)
	testing.expect(t, abs(head.x - 0.04) < 1e-6)
	testing.expect(t, abs(graze.x - 1.0) < 1e-6)
}

// F0: a dielectric reflects ~4% uncolored; a pure metal takes its albedo as F0.
@(test)
test_f0_metallic_blend :: proc(t: ^testing.T) {
	a := m.Vec3{0.9, 0.6, 0.3}
	di := f0_from(a, 0)
	me := f0_from(a, 1)
	testing.expect(t, abs(di.x - 0.04) < 1e-6)
	testing.expect(t, abs(me.x - 0.9) < 1e-6 && abs(me.y - 0.6) < 1e-6)
}

// The GGX distribution is normalized: ∫_Ω D(h)·(N·h) dω = 1. Verified by
// numerically integrating over the hemisphere of half-vector directions.
@(test)
test_ggx_normalized :: proc(t: ^testing.T) {
	for rough in ([]f32{0.4, 0.6, 0.85}) {
		acc: f32 = 0
		M := 200
		for i in 0 ..< M {
			for j in 0 ..< M {
				h := hemisphere_dir((f32(i) + 0.5) / f32(M), (f32(j) + 0.5) / f32(M))
				acc += distribution_ggx(h.z, rough) * h.z
			}
		}
		integral := acc * (2 * math.PI / f32(M * M))
		fmt.printfln("  [ct] ∫D·cosθ dω (roughness %.2f) = %.4f (want 1.0)", rough, integral)
		testing.expect(t, abs(integral - 1.0) < 3e-2)
	}
}

// The Smith geometry term is a valid attenuation factor: always in (0, 1].
@(test)
test_geometry_bounded :: proc(t: ^testing.T) {
	for ndv in ([]f32{0.1, 0.5, 1.0}) {
		for ndl in ([]f32{0.1, 0.5, 1.0}) {
			g := geometry_smith(ndv, ndl, 0.5)
			testing.expect(t, g > 0 && g <= 1.0)
		}
	}
}

// The headline result: unlike the raw Blinn-Phong lobe (which reflected 2.6× the
// incident light), the Cook-Torrance specular lobe conserves energy — its
// hemispherical reflectance stays below 1 at every roughness.
@(test)
test_cook_torrance_conserves_energy :: proc(t: ^testing.T) {
	wo := m.Vec3{0, 0, 1}
	albedo := m.Vec3{1, 1, 1}
	for rough in ([]f32{0.1, 0.3, 0.6, 1.0}) {
		R := cook_torrance_specular_reflectance(wo, rough, 0.0, albedo, 160)
		fmt.printfln("  [ct] CT specular reflectance (roughness %.2f, dielectric) = %.3f", rough, R)
		testing.expect(t, R < 1.0)
	}
}
