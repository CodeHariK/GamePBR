package render

import "core:math"
import m "../math"

// --- Baseline (pre-PBR) direct lighting: Lambert diffuse + Blinn-Phong spec ---
//
// This is the "before" the PBR work: an ad-hoc model that *looks* plausible but
// isn't energy-conserving and has no physical units. Later steps replace the
// diffuse+specular lobes with the Cook-Torrance BRDF. Keeping it isolated here
// makes that swap a one-function change.

// A directional light (sun): parallel rays, no attenuation, no position.
// `dir` is the direction the light TRAVELS, so the vector toward the light is
// L = -dir.
DirLight :: struct {
	dir:       m.Vec3,
	color:     m.Vec3,
	intensity: f32,
}

// Which shading model the fragment stage runs. Baseline is step 09's
// Lambert+Blinn-Phong; PBR is step 11's Cook-Torrance microfacet BRDF.
ShadeModel :: enum {
	Baseline, // zero value -> existing step-09 contexts are unchanged
	PBR,
}

// Surface appearance. The baseline model reads specular/shininess; the PBR model
// reads metallic/roughness (the metallic-roughness workflow). albedo is shared:
// for a dielectric it's the diffuse color, for a metal it tints the reflection.
Material :: struct {
	albedo:    m.Vec3,
	// baseline (Blinn-Phong)
	specular:  m.Vec3,
	shininess: f32,
	// PBR (Cook-Torrance)
	metallic:  f32,
	roughness: f32,
	// light the surface itself gives off, added unlit (glTF emissiveFactor)
	emissive:  m.Vec3,
}

// Everything the fragment stage needs to shade a lit surface. `model` picks the
// shading model; `ambient` is a flat fill standing in for bounced light.
// Optional maps (glTF semantics, see material_maps.odin):
//   tex     – albedo map, multiplied by mat.albedo
//   mr_tex  – metallic-roughness map (G = roughness, B = metallic), × factors
//   nrm_tex – tangent-space normal map (needs mesh tangents)
ShadeCtx :: struct {
	model:   ShadeModel,
	light:   DirLight, // used only when `lights` is empty (steps 09-12)
	lights:  []Light,  // any mix of directional / point / spot (step 13)
	mat:     Material,
	eye:     m.Vec3,
	ambient: m.Vec3,
	tex:     ^Texture,
	mr_tex:  ^Texture,
	nrm_tex: ^Texture,
	env_irr: ^EnvMap, // irradiance map; when set (PBR), replaces `ambient` (step 15)
}

// A neutral baseline material.
material_default :: proc() -> Material {
	return Material{albedo = {0.8, 0.3, 0.25}, specular = {1, 1, 1}, shininess = 32}
}

// A PBR (metallic-roughness) material.
pbr_material :: proc(albedo: m.Vec3, metallic, roughness: f32) -> Material {
	return Material{albedo = albedo, metallic = metallic, roughness = roughness}
}

// Shade one point. N and V must be unit; N is the (possibly perturbed) surface
// normal, V the direction from the surface toward the eye, both in world space.
//
//   diffuse  = albedo * max(N·L, 0)                         (Lambert)
//   specular = specTint * max(N·H, 0)^shininess             (Blinn-Phong)
//   H        = normalize(L + V)                             (half vector)
//   out      = ambient*albedo + (diffuse + specular) * lightRadiance
//
// Specular is gated on N·L > 0 so highlights never appear on unlit back-faces.
shade_blinn_phong :: proc(mat: Material, light: DirLight, N, V, albedo, ambient: m.Vec3) -> m.Vec3 {
	L := m.normalize(-light.dir)
	return ambient * albedo + brdf_blinn_phong(mat, N, V, L, albedo) * (light.color * light.intensity)
}

// Per-light baseline term for one incoming direction L (multiply by radiance).
brdf_blinn_phong :: proc(mat: Material, N, V, L, albedo: m.Vec3) -> m.Vec3 {
	ndl := m.saturate(m.dot(N, L))
	diffuse := albedo * ndl
	spec := m.Vec3{}
	if ndl > 0 {
		H := m.normalize(L + V)
		ndh := m.saturate(m.dot(N, H))
		spec = mat.specular * math.pow(ndh, mat.shininess)
	}
	return diffuse + spec
}
