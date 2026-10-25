package render

import "core:math"
import m "../math"

// --- Multiple & typed lights (step 13) ---
//
// Every light answers one question for a surface point P:
//     "from which direction L does your light arrive, and how much radiance?"
// Once that's known, the BRDF doesn't care what kind of light it was — the
// shading loop just sums  brdf(N, V, L) · radiance  over all lights.
//
// Conventions follow glTF KHR_lights_punctual: `dir` is the direction the light
// TRAVELS; point/spot intensity is luminous intensity (W/sr in our unitless
// world), so radiance falls off as intensity / distance².

LightKind :: enum {
	Directional, // sun: parallel rays, no falloff
	Point,       // bulb: radiates from a position, inverse-square falloff
	Spot,        // flashlight: a point light masked to a cone
}

Light :: struct {
	kind:      LightKind,
	color:     m.Vec3,
	intensity: f32,
	pos:       m.Vec3, // point, spot
	dir:       m.Vec3, // directional, spot: direction the light travels
	range:     f32,    // point, spot: 0 = infinite (pure inverse-square)
	inner:     f32,    // spot: cone half-angle (radians) of full intensity
	outer:     f32,    // spot: cone half-angle beyond which it's dark
}

directional_light :: proc(dir, color: m.Vec3, intensity: f32) -> Light {
	return Light{kind = .Directional, dir = m.normalize(dir), color = color, intensity = intensity}
}

point_light :: proc(pos, color: m.Vec3, intensity: f32, range: f32 = 0) -> Light {
	return Light{kind = .Point, pos = pos, color = color, intensity = intensity, range = range}
}

spot_light :: proc(pos, dir, color: m.Vec3, intensity, inner, outer: f32, range: f32 = 0) -> Light {
	return Light{kind = .Spot, pos = pos, dir = m.normalize(dir), color = color,
		intensity = intensity, inner = inner, outer = outer, range = range}
}

// Direction to the light (unit) and the radiance it delivers at point p.
light_sample :: proc(l: Light, p: m.Vec3) -> (L: m.Vec3, radiance: m.Vec3) {
	if l.kind == .Directional {
		return m.normalize(-l.dir), l.color * l.intensity
	}
	d := l.pos - p
	dist2 := max(m.dot(d, d), 1e-4) // avoid the singularity at the light itself
	L = d / math.sqrt(dist2)
	att := range_window(dist2, l.range) / dist2 // inverse-square, windowed
	if l.kind == .Spot {
		att *= spot_cone(l, L)
	}
	radiance = l.color * (l.intensity * att)
	return
}

// Inverse-square never reaches zero, so a light with a finite `range` is faded
// smoothly to exactly 0 at that distance (the window from UE4 / glTF):
//     w = saturate(1 − (d/r)⁴)²
// Close in it's ≈1 and leaves the physical falloff alone.
range_window :: proc(dist2, range: f32) -> f32 {
	if range <= 0 {
		return 1
	}
	r2 := dist2 / (range * range) // (d/r)²
	w := m.saturate(1 - r2 * r2)  // 1 − (d/r)⁴
	return w * w
}

// Spot mask: 1 inside the inner cone, 0 outside the outer cone, with a smooth
// (squared) ramp between — interpolated in cosine space, as glTF specifies.
spot_cone :: proc(l: Light, L: m.Vec3) -> f32 {
	cd := m.dot(-L, l.dir) // cos of angle between spot axis and the ray to p
	ci := math.cos(l.inner)
	co := math.cos(l.outer)
	t := m.saturate((cd - co) / max(ci - co, 1e-4))
	return t * t
}

// The per-light term for whichever shading model the context selects.
brdf_eval :: proc(model: ShadeModel, mat: Material, N, V, L, albedo: m.Vec3) -> m.Vec3 {
	switch model {
	case .PBR:
		return brdf_cook_torrance(mat, N, V, L, albedo)
	case .Baseline:
		return brdf_blinn_phong(mat, N, V, L, albedo)
	}
	return {}
}

// Outgoing radiance at surface point P: emission + ambient fill + the sum over
// every light of brdf · radiance. A context with no `lights` falls back to its
// single directional `light`, so every step-09..12 context renders unchanged.
shade_surface :: proc(sh: ^ShadeCtx, mat: Material, N, V, P, albedo: m.Vec3) -> m.Vec3 {
	col := mat.emissive
	if sh.env_irr != nil && sh.model == .PBR {
		col += ibl_diffuse(mat, N, V, albedo, sh.env_irr) // the sky, replacing ambient
	} else {
		col += sh.ambient * albedo
	}
	if len(sh.lights) == 0 {
		L := m.normalize(-sh.light.dir)
		return col + brdf_eval(sh.model, mat, N, V, L, albedo) * (sh.light.color * sh.light.intensity)
	}
	for l in sh.lights {
		L, radiance := light_sample(l, P)
		col += brdf_eval(sh.model, mat, N, V, L, albedo) * radiance
	}
	return col
}
