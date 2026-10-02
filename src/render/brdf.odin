package render

import "core:math"
import m "../math"

// --- Radiometry & BRDF foundations (step 10) ---
//
// A BRDF f(wo, wi) says what fraction of light arriving from direction wi leaves
// toward wo, per unit solid angle. The rendering equation sums that over every
// incoming direction on the hemisphere:
//
//     Lo(wo) = ∫_Ω  f(wo, wi) · Li(wi) · (N·wi)  dwi
//
// Two hard constraints make a BRDF *physical*: it must be non-negative, and it
// must conserve energy — the directional-hemispherical reflectance
//
//     R(wo) = ∫_Ω  f(wo, wi) · (N·wi)  dwi
//
// (what fraction of incident light is reflected, integrated over all outgoing-
// er, incoming directions) must be ≤ 1 for every wo. The procedures below let a
// test *measure* R numerically, so we can show which models obey that bound.

// Lambert diffuse BRDF: the same value in every direction, albedo / π. The 1/π
// is exactly the normalization the step-09 baseline omitted; it is what makes a
// fully diffuse white surface reflect 100% (and no more) of what hits it.
lambert_brdf :: proc(albedo: m.Vec3) -> m.Vec3 {
	return albedo / math.PI
}

// A direction on the +Z hemisphere from stratified coordinates (u1,u2) in (0,1),
// sampled uniformly in solid angle: pdf = 1/(2π), with cosθ = u1.
hemisphere_dir :: proc(u1, u2: f32) -> m.Vec3 {
	z := u1
	r := math.sqrt(max(0, 1 - z * z))
	phi := 2 * math.PI * u2
	return m.Vec3{r * math.cos(phi), r * math.sin(phi), z}
}

// Directional-hemispherical reflectance of the Lambert BRDF, integrated by
// deterministic stratified quadrature over the hemisphere (n_side × n_side
// samples). The weight per sample is 1/pdf = 2π. For an energy-conserving
// diffuse this converges to `albedo` — never more.
lambert_reflectance :: proc(albedo: m.Vec3, n_side: int) -> m.Vec3 {
	f := lambert_brdf(albedo)
	acc := m.Vec3{}
	for i in 0 ..< n_side {
		for j in 0 ..< n_side {
			u1 := (f32(i) + 0.5) / f32(n_side)
			u2 := (f32(j) + 0.5) / f32(n_side)
			wi := hemisphere_dir(u1, u2)
			acc += f * wi.z
		}
	}
	return acc * (2 * math.PI / f32(n_side * n_side))
}

// Reflectance of the RAW Blinn-Phong specular lobe from step 09 — fr = (N·H)^s,
// H = normalize(wo + wi) — treated as if it were a BRDF and integrated the same
// way. It is not energy-conserving: for low exponents this integral exceeds 1
// (the surface "reflects" more than it receives), and for high exponents it
// collapses — the brightness is untethered from incident energy. Step 11's GGX
// lobe carries a normalization factor precisely to keep this at ≤ 1.
blinn_phong_reflectance :: proc(wo: m.Vec3, shininess: f32, n_side: int) -> f32 {
	n := m.Vec3{0, 0, 1}
	acc: f32 = 0
	for i in 0 ..< n_side {
		for j in 0 ..< n_side {
			u1 := (f32(i) + 0.5) / f32(n_side)
			u2 := (f32(j) + 0.5) / f32(n_side)
			wi := hemisphere_dir(u1, u2)
			h := m.normalize(wo + wi)
			ndh := m.saturate(m.dot(n, h))
			acc += math.pow(ndh, shininess) * wi.z
		}
	}
	return acc * (2 * math.PI / f32(n_side * n_side))
}
