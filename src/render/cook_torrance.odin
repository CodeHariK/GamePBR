package render

import "core:math"
import m "../math"

// --- Cook-Torrance microfacet BRDF (step 11) ---
//
// The specular BRDF is the microfacet model:
//
//     f_spec = D · G · F / (4 · (N·V) · (N·L))
//
// A surface is modeled as countless tiny mirrors (microfacets). Of them:
//   D  — what fraction are oriented to mirror L into V (the half-vector H),
//   G  — what fraction aren't shadowed or masked by their neighbors,
//   F  — how reflective each one is at this angle (Fresnel).
// The 1/(4 N·V N·L) is the geometric factor that converts between microfacet
// and macro-surface measures. Each term fixes a fault named in step 10.

// D — Trowbridge-Reitz / GGX normal distribution. roughness² = α (Disney
// convention). Normalized so ∫ D·(N·H) dω over the hemisphere = 1.
distribution_ggx :: proc(ndoth, roughness: f32) -> f32 {
	a := roughness * roughness
	a2 := a * a
	d := ndoth * ndoth * (a2 - 1) + 1
	return a2 / (math.PI * d * d)
}

// G — Smith geometry (masking + shadowing) using the Schlick-GGX approximation.
// `k` is the direct-lighting remap of roughness; the two G1 terms account for
// light blocked on the way in (L) and on the way out (V).
geometry_schlick_ggx :: proc(ndotx, k: f32) -> f32 {
	return ndotx / (ndotx * (1 - k) + k)
}
geometry_smith :: proc(ndotv, ndotl, roughness: f32) -> f32 {
	r := roughness + 1
	k := (r * r) / 8.0 // direct-lighting k
	return geometry_schlick_ggx(ndotv, k) * geometry_schlick_ggx(ndotl, k)
}

// F — Fresnel-Schlick: reflectance rises toward 1 at grazing angles. F0 is the
// reflectance at normal incidence.
fresnel_schlick :: proc(cos_theta: f32, F0: m.Vec3) -> m.Vec3 {
	c := m.saturate(1 - cos_theta)
	c5 := c * c * c * c * c
	return F0 + (m.Vec3{1, 1, 1} - F0) * c5
}

// F0 for the metallic-roughness workflow: dielectrics reflect ~4% colorlessly;
// metals have no diffuse and tint their reflection with the albedo. metallic
// blends between the two.
f0_from :: proc(albedo: m.Vec3, metallic: f32) -> m.Vec3 {
	return m.lerp(m.Vec3{0.04, 0.04, 0.04}, albedo, metallic)
}

// Shade one point with Cook-Torrance direct lighting from a single light.
// N, V unit and in world space. Returns outgoing radiance (+ ambient fill).
shade_cook_torrance :: proc(mat: Material, light: DirLight, N, V, albedo, ambient: m.Vec3) -> m.Vec3 {
	L := m.normalize(-light.dir)
	ndl := m.saturate(m.dot(N, L))
	if ndl <= 0 {
		return ambient * albedo
	}
	ndv := m.saturate(m.dot(N, V))
	H := m.normalize(V + L)
	ndh := m.saturate(m.dot(N, H))
	vdh := m.saturate(m.dot(V, H))

	F0 := f0_from(albedo, mat.metallic)
	D := distribution_ggx(ndh, mat.roughness)
	G := geometry_smith(ndv, ndl, mat.roughness)
	F := fresnel_schlick(vdh, F0)

	spec := (D * G) * F / (4 * ndv * ndl + 1e-4) // F is Vec3 -> colored specular

	// Energy split: whatever reflects specularly (F) can't also diffuse, and
	// metals have no diffuse lobe at all.
	kd := (m.Vec3{1, 1, 1} - F) * (1 - mat.metallic)
	diffuse := kd * albedo / math.PI

	radiance := light.color * light.intensity
	return ambient * albedo + (diffuse + spec) * radiance * ndl
}

// Directional-hemispherical reflectance of ONLY the Cook-Torrance specular lobe,
// integrated like the step-10 harness. Unlike raw Blinn-Phong this stays ≤ 1 for
// every view angle and roughness — the point of the whole exercise.
cook_torrance_specular_reflectance :: proc(wo: m.Vec3, roughness, metallic: f32, albedo: m.Vec3, n_side: int) -> f32 {
	n := m.Vec3{0, 0, 1}
	F0 := f0_from(albedo, metallic)
	ndv := m.saturate(m.dot(n, wo))
	acc: f32 = 0
	for i in 0 ..< n_side {
		for j in 0 ..< n_side {
			wi := hemisphere_dir((f32(i) + 0.5) / f32(n_side), (f32(j) + 0.5) / f32(n_side))
			ndl := wi.z
			if ndl <= 0 { continue }
			h := m.normalize(wo + wi)
			ndh := m.saturate(m.dot(n, h))
			vdh := m.saturate(m.dot(wo, h))
			D := distribution_ggx(ndh, roughness)
			G := geometry_smith(ndv, ndl, roughness)
			F := fresnel_schlick(vdh, F0)
			spec := (D * G) * F.x / (4 * ndv * ndl + 1e-4)
			acc += spec * ndl
		}
	}
	return acc * (2 * math.PI / f32(n_side * n_side))
}
