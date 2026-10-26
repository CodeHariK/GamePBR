package render

import "core:math"
import m "../math"

// --- The split-sum BRDF lookup table (step 16) ---
//
// The specular IBL integral  ∫ L(l) · f(v,l) · (n·l) dl  is split (Karis 2013)
// into   [∫ L(l) over the GGX lobe]  ×  [∫ f(v,l)(n·l) dl  with L = 1].
// The second factor doesn't depend on the environment at all — only on the
// view angle (n·v), the roughness, and F0. Substituting Fresnel-Schlick
//     F = F0 + (1 − F0)(1 − v·h)⁵
// pulls F0 out as a scale and a bias:
//     ∫ f(n·l) dl = F0 · A + B
//     A = ∫ (1 − Fc) · G_vis,   B = ∫ Fc · G_vis,   Fc = (1 − v·h)⁵
// A and B are precomputed once into a 2D table indexed by (n·v, roughness).

BrdfLut :: struct {
	size: int,
	ab:   [][2]f32, // [y * size + x]: x = n·v, y = roughness, both at texel centres
}

// Smith-Schlick G with the IBL remap k = α/2 (α = roughness²). Direct lighting
// used k = (r+1)²/8 — a different remap tuned for punctual lights.
geometry_smith_ibl :: proc(ndotv, ndotl, roughness: f32) -> f32 {
	k := (roughness * roughness) / 2
	return geometry_schlick_ggx(ndotv, k) * geometry_schlick_ggx(ndotl, k)
}

// Integrate (A, B) for one (n·v, roughness) by GGX importance sampling.
// With H drawn ∝ D(h)(n·h), the estimator of f·(n·l) simplifies to
//     G · (v·h) / ((n·h)(n·v))   — the D terms cancel against the pdf.
integrate_brdf :: proc(ndotv, roughness: f32, samples: int) -> m.Vec2 {
	nv := max(ndotv, 1e-4)
	V := m.Vec3{math.sqrt(1 - nv * nv), 0, nv}
	N := m.Vec3{0, 0, 1}
	a, b: f32
	for i in 0 ..< samples {
		H := importance_sample_ggx(hammersley(i, samples), N, roughness)
		L := H * (2 * m.dot(V, H)) - V
		nl := m.saturate(L.z)
		if nl <= 0 { continue }
		nh := m.saturate(H.z)
		vh := m.saturate(m.dot(V, H))
		g_vis := geometry_smith_ibl(nv, nl, roughness) * vh / (nh * nv)
		c := 1 - vh
		fc := c * c * c * c * c
		a += (1 - fc) * g_vis
		b += fc * g_vis
	}
	return m.Vec2{a, b} / f32(samples)
}

make_brdf_lut :: proc(size, samples: int) -> BrdfLut {
	lut := BrdfLut{size = size, ab = make([][2]f32, size * size)}
	for y in 0 ..< size {
		for x in 0 ..< size {
			nv := (f32(x) + 0.5) / f32(size)
			r := (f32(y) + 0.5) / f32(size)
			lut.ab[y * size + x] = integrate_brdf(nv, r, samples)
		}
	}
	return lut
}

brdf_lut_destroy :: proc(lut: ^BrdfLut) {
	delete(lut.ab)
	lut^ = {}
}

// Bilinear lookup of (A, B) at (n·v, roughness), clamped to the table.
brdf_lut_sample :: proc(lut: ^BrdfLut, ndotv, roughness: f32) -> m.Vec2 {
	s := f32(lut.size)
	fx := clamp(ndotv * s - 0.5, 0, s - 1)
	fy := clamp(roughness * s - 0.5, 0, s - 1)
	x0 := int(fx); y0 := int(fy)
	x1 := min(x0 + 1, lut.size - 1); y1 := min(y0 + 1, lut.size - 1)
	tx := fx - f32(x0); ty := fy - f32(y0)
	at :: proc(l: ^BrdfLut, x, y: int) -> m.Vec2 { return m.Vec2(l.ab[y * l.size + x]) }
	top := at(lut, x0, y0) * (1 - tx) + at(lut, x1, y0) * tx
	bot := at(lut, x0, y1) * (1 - tx) + at(lut, x1, y1) * tx
	return top * (1 - ty) + bot * ty
}
