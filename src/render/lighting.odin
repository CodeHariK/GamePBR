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

// Surface appearance under the baseline model.
//   albedo    – diffuse (Lambert) reflectance
//   specular  – specular tint (white for dielectrics, colored for metals-ish)
//   shininess – Blinn-Phong exponent: higher = tighter, sharper highlight
Material :: struct {
	albedo:    m.Vec3,
	specular:  m.Vec3,
	shininess: f32,
}

// Everything the fragment stage needs to shade a lit surface. `tex`, when set,
// overrides `mat.albedo` with a per-pixel texture sample. `ambient` is a flat
// fill term standing in for all the bounced light this model can't compute.
ShadeCtx :: struct {
	light:   DirLight,
	mat:     Material,
	eye:     m.Vec3,
	ambient: m.Vec3,
	tex:     ^Texture,
}

// A neutral starting material.
material_default :: proc() -> Material {
	return Material{albedo = {0.8, 0.3, 0.25}, specular = {1, 1, 1}, shininess = 32}
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
	ndl := m.saturate(m.dot(N, L))

	diffuse := albedo * ndl

	spec := m.Vec3{}
	if ndl > 0 {
		H := m.normalize(L + V)
		ndh := m.saturate(m.dot(N, H))
		spec = mat.specular * math.pow(ndh, mat.shininess)
	}

	radiance := light.color * light.intensity
	return ambient * albedo + (diffuse + spec) * radiance
}
