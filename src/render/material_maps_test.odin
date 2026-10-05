package render

import "core:testing"
import "../fb"
import m "../math"

@(private = "file")
one_texel :: proc(c: fb.Color) -> Texture {
	t := Texture{width = 1, height = 1, pixels = make([]fb.Color, 1)}
	t.pixels[0] = c
	return t
}

// glTF channel packing: G = roughness, B = metallic; R is ignored.
@(test)
test_mr_channels_decode :: proc(t: ^testing.T) {
	mr := one_texel(fb.Color{0, 128, 255, 255})
	defer texture_destroy(&mr)
	base := pbr_material(m.Vec3{1, 1, 1}, 1, 1) // factors of 1 = "map decides"
	mat, _ := resolve_material(base, nil, &mr, 0.5, 0.5)
	testing.expect(t, abs(mat.roughness - 128.0 / 255.0) < 1e-4)
	testing.expect(t, abs(mat.metallic - 1.0) < 1e-4)
}

// Factors multiply the texture (glTF): a 0.5 roughness factor halves the map.
@(test)
test_factors_multiply_maps :: proc(t: ^testing.T) {
	alb := one_texel(fb.Color{255, 128, 0, 255})
	mr := one_texel(fb.Color{0, 255, 255, 255})
	defer texture_destroy(&alb)
	defer texture_destroy(&mr)
	base := pbr_material(m.Vec3{0.5, 1, 1}, 0.25, 0.5)
	mat, albedo := resolve_material(base, &alb, &mr, 0.5, 0.5)
	testing.expect(t, abs(albedo.x - 0.5) < 1e-4)           // 1.0 × 0.5
	testing.expect(t, abs(albedo.y - 128.0 / 255.0) < 1e-4) // 0.502 × 1
	testing.expect(t, abs(mat.roughness - 0.5) < 1e-4)
	testing.expect(t, abs(mat.metallic - 0.25) < 1e-4)
}

// No maps -> constants pass straight through (step-11 behavior), except the
// roughness floor that keeps GGX finite.
@(test)
test_constants_and_roughness_floor :: proc(t: ^testing.T) {
	mat, albedo := resolve_material(pbr_material(m.Vec3{0.2, 0.3, 0.4}, 1, 0), nil, nil, 0, 0)
	testing.expect(t, abs(albedo.z - 0.4) < 1e-6)
	testing.expect(t, abs(mat.roughness - MIN_ROUGHNESS) < 1e-6)
}

// A flat tangent-space sample (0,0,1) leaves the normal unchanged; a sample
// leaning +X leans the result toward the tangent.
@(test)
test_perturb_normal :: proc(t: ^testing.T) {
	N := m.Vec3{0, 0, 1}; T := m.Vec3{1, 0, 0}
	flat := perturb_normal(N, T, m.Vec3{0, 0, 1})
	testing.expect(t, abs(flat.z - 1) < 1e-6)
	lean := perturb_normal(N, T, m.normalize(m.Vec3{0.5, 0, 1}))
	testing.expect(t, lean.x > 0.4 && abs(m.length(lean) - 1) < 1e-5)
}

// The panel generator lays out the checker it promises: tile (0,0) is metal,
// tile (1,0) is paint, and the tile corner is rough non-metal grout.
@(test)
test_panel_layout :: proc(t: ^testing.T) {
	p := make_panel_maps(64, 4) // 16 px tiles
	defer panel_maps_destroy(&p)
	at :: proc(tex: ^Texture, x, y: int) -> fb.Color { return tex.pixels[y * tex.width + x] }
	testing.expect_value(t, at(&p.mr, 8, 8).b, 255)  // metal tile centre
	testing.expect_value(t, at(&p.mr, 24, 8).b, 0)   // paint tile centre
	grout := at(&p.mr, 0, 0)
	testing.expect(t, grout.b == 0 && grout.g > 220) // rough dielectric grout
}
