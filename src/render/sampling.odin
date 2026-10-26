package render

import "core:math"
import m "../math"

// --- Low-discrepancy + importance sampling (step 16) ---
//
// Specular integrals are dominated by a narrow lobe around the reflection
// direction. Sampling the whole hemisphere uniformly (as in step 10) wastes
// almost every sample on directions where the BRDF is ~0. Importance sampling
// draws directions *in proportion to* the GGX lobe instead, so every sample
// counts. Hammersley points spread those samples evenly (no random clumps).

// Van der Corput radical inverse in base 2: mirror the bits of i around the
// binary point. 1 → 0.5, 2 → 0.25, 3 → 0.75, 4 → 0.125, ...
radical_inverse_vdc :: proc(i: u32) -> f32 {
	b := i
	b = (b << 16) | (b >> 16)
	b = ((b & 0x55555555) << 1) | ((b & 0xAAAAAAAA) >> 1)
	b = ((b & 0x33333333) << 2) | ((b & 0xCCCCCCCC) >> 2)
	b = ((b & 0x0F0F0F0F) << 4) | ((b & 0xF0F0F0F0) >> 4)
	b = ((b & 0x00FF00FF) << 8) | ((b & 0xFF00FF00) >> 8)
	return f32(b) * 2.3283064365386963e-10 // / 2^32
}

// The i-th of n Hammersley points in [0,1)²: evenly spaced in x, bit-reversed in y.
hammersley :: proc(i, n: int) -> m.Vec2 {
	return m.Vec2{f32(i) / f32(n), radical_inverse_vdc(u32(i))}
}

// An orthonormal basis (T, B) around unit vector N.
tangent_basis :: proc(N: m.Vec3) -> (T, B: m.Vec3) {
	up := abs(N.z) < 0.999 ? m.Vec3{0, 0, 1} : m.Vec3{1, 0, 0}
	T = m.normalize(m.cross(up, N))
	B = m.cross(N, T)
	return
}

// Draw a half-vector H around N distributed like the GGX D(h)·(N·h) — the
// inversion of GGX's CDF in θ (φ is uniform). α = roughness², as in D.
importance_sample_ggx :: proc(xi: m.Vec2, N: m.Vec3, roughness: f32) -> m.Vec3 {
	a := roughness * roughness
	phi := 2 * math.PI * xi.x
	cos_t := math.sqrt((1 - xi.y) / (1 + (a * a - 1) * xi.y))
	sin_t := math.sqrt(max(0, 1 - cos_t * cos_t))
	T, B := tangent_basis(N)
	return m.normalize(T * (math.cos(phi) * sin_t) + B * (math.sin(phi) * sin_t) + N * cos_t)
}
