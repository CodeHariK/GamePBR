package render

import "../fb"
import m "../math"

// --- Metallic-roughness workflow, textured (step 12) ---
//
// Follows the glTF 2.0 convention so real assets drop in later:
//   * albedo ("baseColor") map: RGB, MULTIPLIED by the material's albedo factor
//   * metallic-roughness map:   G = roughness, B = metallic (R is free — often AO)
//     each MULTIPLIED by the material's roughness / metallic factor
// So a material driven entirely by maps uses factors of 1. Constants-only
// materials (no maps) behave exactly as in step 11.

// GGX's D term is a delta at roughness 0 — the highlight collapses to a single
// sample and aliases. Clamp to a small floor (common engine practice).
MIN_ROUGHNESS :: f32(0.04)

// Resolve the material at one surface point: factors × texture samples.
resolve_material :: proc(base: Material, albedo_tex, mr_tex: ^Texture, u, v: f32) -> (mat: Material, albedo: m.Vec3) {
	mat = base
	albedo = base.albedo
	if albedo_tex != nil {
		albedo = sample(albedo_tex, u, v) * base.albedo
	}
	if mr_tex != nil {
		mr := sample(mr_tex, u, v)
		mat.roughness = base.roughness * mr.y // G
		mat.metallic  = base.metallic * mr.z  // B
	}
	mat.roughness = max(mat.roughness, MIN_ROUGHNESS)
	mat.albedo = albedo
	return
}

// Tangent-space normal → world space, given the interpolated world N and T.
// T is re-orthonormalized against N (Gram-Schmidt) since interpolation skews it.
perturb_normal :: proc(N, T, sn: m.Vec3) -> m.Vec3 {
	t := m.normalize(T - N * m.dot(N, T))
	b := m.cross(N, t)
	return m.normalize(sn.x * t + sn.y * b + sn.z * N)
}

// Encode material channels into a glTF metallic-roughness texel.
encode_mr :: proc(roughness, metallic: f32) -> fb.Color {
	return fb.Color{255, u8(m.saturate(roughness) * 255), u8(m.saturate(metallic) * 255), 255}
}

encode_rgb :: proc(c: m.Vec3) -> fb.Color {
	return fb.Color{u8(m.saturate(c.x) * 255), u8(m.saturate(c.y) * 255), u8(m.saturate(c.z) * 255), 255}
}

// A procedural "panel" material: a tiles × tiles grid, checkered between gold
// metal and painted (dielectric) teal, separated by rough dark grout. Roughness
// sweeps across the grid (metal: by column, paint: by row) so one surface shows
// the whole roughness range.
PanelMaps :: struct {
	albedo: Texture,
	mr:     Texture,
}

PANEL_GOLD  :: m.Vec3{1.00, 0.77, 0.34}
PANEL_PAINT :: m.Vec3{0.10, 0.45, 0.55}
PANEL_GROUT :: m.Vec3{0.06, 0.06, 0.06}
PANEL_GROUT_WIDTH :: f32(0.07) // fraction of a tile

make_panel_maps :: proc(size, tiles: int) -> PanelMaps {
	p := PanelMaps{
		albedo = Texture{width = size, height = size, pixels = make([]fb.Color, size * size)},
		mr     = Texture{width = size, height = size, pixels = make([]fb.Color, size * size)},
	}
	span := f32(max(tiles - 1, 1))
	for y in 0 ..< size {
		for x in 0 ..< size {
			tx := f32(x) * f32(tiles) / f32(size)
			ty := f32(y) * f32(tiles) / f32(size)
			cx := int(tx); cy := int(ty)
			fx := tx - f32(cx); fy := ty - f32(cy)
			idx := y * size + x

			if fx < PANEL_GROUT_WIDTH || fy < PANEL_GROUT_WIDTH {
				p.albedo.pixels[idx] = encode_rgb(PANEL_GROUT)
				p.mr.pixels[idx] = encode_mr(0.9, 0)
			} else if (cx + cy) % 2 == 0 {
				rough := 0.08 + 0.62 * f32(cx) / span // metal: smooth → rough by column
				p.albedo.pixels[idx] = encode_rgb(PANEL_GOLD)
				p.mr.pixels[idx] = encode_mr(rough, 1)
			} else {
				rough := 0.15 + 0.70 * f32(cy) / span // paint: glossy → matte by row
				p.albedo.pixels[idx] = encode_rgb(PANEL_PAINT)
				p.mr.pixels[idx] = encode_mr(rough, 0)
			}
		}
	}
	return p
}

panel_maps_destroy :: proc(p: ^PanelMaps) {
	texture_destroy(&p.albedo)
	texture_destroy(&p.mr)
}
