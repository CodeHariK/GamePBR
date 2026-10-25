package render

import "core:math"
import m "../math"

// --- Diffuse image-based lighting (step 15) ---
//
// The Lambert term integrated against a whole environment instead of a few
// punctual lights:
//     Lo_diffuse = kd · (albedo/π) · ∫ L(ω)(N·ω) dω = kd · (albedo/π) · E(N)
// E(N) is exactly what convolve_irradiance precomputed, so at shading time
// diffuse IBL is ONE lookup by the surface normal.

// Fresnel for IBL: light arrives from every direction, so there's no single
// half-vector. Use N·V, and cap the grazing boost by roughness — rough surfaces
// don't show a strong Fresnel rim (Sébastien Lagarde's approximation).
fresnel_schlick_roughness :: proc(cos_theta: f32, F0: m.Vec3, roughness: f32) -> m.Vec3 {
	c := m.saturate(1 - cos_theta)
	c5 := c * c * c * c * c
	r := 1 - roughness
	top := m.Vec3{max(r, F0.x), max(r, F0.y), max(r, F0.z)}
	return F0 + (top - F0) * c5
}

// Diffuse radiance from the environment. Same energy split as direct lighting:
// what reflects specularly (F) is removed, and metals have no diffuse at all —
// which is why metals stay dark until specular IBL (step 16).
ibl_diffuse :: proc(mat: Material, N, V, albedo: m.Vec3, irradiance: ^EnvMap) -> m.Vec3 {
	F0 := f0_from(albedo, mat.metallic)
	F := fresnel_schlick_roughness(m.saturate(m.dot(N, V)), F0, mat.roughness)
	kd := (m.Vec3{1, 1, 1} - F) * (1 - mat.metallic)
	return kd * albedo / math.PI * env_sample(irradiance, N)
}
