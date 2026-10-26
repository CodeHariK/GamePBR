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

// --- Specular image-based lighting: the split sum (step 16) ---
//
//     Lo_spec ≈ prefiltered(R, roughness) · (F0·A + B),   R = reflect(−V, N)
//
// The first factor is the sky blurred by the GGX lobe (prefilter.odin); the
// second is the BRDF's response under a uniform white sky (brdf_lut.odin).

// Everything precomputed from one environment, built once at load time.
IBLMaps :: struct {
	irradiance:  EnvMap,                   // diffuse (step 15)
	prefiltered: [PREFILTER_LEVELS]EnvMap, // specular, per roughness
	lut:         BrdfLut,                  // specular, (n·v, roughness) -> (A, B)
}

IBLSettings :: struct {
	irr_downsample:    int, // shrink the source before the brute-force irradiance sum
	irr_w, irr_h:      int,
	prefilter_samples: int,
	lut_size:          int,
	lut_samples:       int,
}

ibl_settings_default :: proc() -> IBLSettings {
	return IBLSettings{irr_downsample = 4, irr_w = 32, irr_h = 16,
		prefilter_samples = 256, lut_size = 32, lut_samples = 512}
}

make_ibl_maps :: proc(env: ^EnvMap, s: IBLSettings) -> IBLMaps {
	maps: IBLMaps
	small := env_downsample(env, max(s.irr_downsample, 1))
	defer env_destroy(&small)
	maps.irradiance = convolve_irradiance(&small, s.irr_w, s.irr_h)
	maps.prefiltered = prefilter_env(env, s.prefilter_samples)
	maps.lut = make_brdf_lut(s.lut_size, s.lut_samples)
	return maps
}

ibl_maps_destroy :: proc(maps: ^IBLMaps) {
	env_destroy(&maps.irradiance)
	for &l in maps.prefiltered { env_destroy(&l) }
	brdf_lut_destroy(&maps.lut)
}

// The environment's specular reflection off this surface point.
ibl_specular :: proc(mat: Material, N, V, albedo: m.Vec3, maps: ^IBLMaps) -> m.Vec3 {
	F0 := f0_from(albedo, mat.metallic)
	nv := max(m.dot(N, V), 1e-4)
	R := m.reflect(-V, N)
	pre := sample_prefiltered(&maps.prefiltered, R, mat.roughness)
	ab := brdf_lut_sample(&maps.lut, nv, mat.roughness)
	return pre * (F0 * ab.x + m.Vec3{ab.y, ab.y, ab.y})
}

// Full environment lighting: diffuse (step 15) + specular (step 16).
ibl_total :: proc(mat: Material, N, V, albedo: m.Vec3, maps: ^IBLMaps) -> m.Vec3 {
	return ibl_diffuse(mat, N, V, albedo, &maps.irradiance) + ibl_specular(mat, N, V, albedo, maps)
}
