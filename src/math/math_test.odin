package gmath

import "core:testing"

// Run with `make test` (odin test src). Cheap invariants that would catch a
// typo in the math the whole renderer depends on.

@(test)
test_dot :: proc(t: ^testing.T) {
	testing.expect_value(t, dot(Vec3{1, 0, 0}, Vec3{1, 0, 0}), f32(1))
	testing.expect_value(t, dot(Vec3{1, 0, 0}, Vec3{0, 1, 0}), f32(0))
}

@(test)
test_cross_right_handed :: proc(t: ^testing.T) {
	testing.expect(t, cross(Vec3{1, 0, 0}, Vec3{0, 1, 0}) == Vec3{0, 0, 1})
}

@(test)
test_normalize_is_unit :: proc(t: ^testing.T) {
	n := normalize(Vec3{0, 3, 4}) // length 5
	testing.expect(t, abs(length(n) - 1) < 1e-6)
}

@(test)
test_reflect :: proc(t: ^testing.T) {
	// straight down onto a floor bounces straight up
	r := reflect(Vec3{0, -1, 0}, Vec3{0, 1, 0})
	testing.expect(t, r == Vec3{0, 1, 0})
}

@(test)
test_identity_point :: proc(t: ^testing.T) {
	testing.expect(t, mat4_mul_point(mat4_identity(), Vec3{2, 3, 4}) == Vec3{2, 3, 4})
}

@(test)
test_translate_point :: proc(t: ^testing.T) {
	testing.expect(t, mat4_mul_point(mat4_translate(Vec3{1, 2, 3}), Vec3{0, 0, 0}) == Vec3{1, 2, 3})
}

@(test)
test_translate_ignores_direction :: proc(t: ^testing.T) {
	// directions have w=0, so translation must not move them
	testing.expect(t, mat4_mul_dir(mat4_translate(Vec3{9, 9, 9}), Vec3{1, 0, 0}) == Vec3{1, 0, 0})
}

@(test)
test_look_at_eye_to_origin :: proc(t: ^testing.T) {
	view := mat4_look_at(Vec3{0, 0, 5}, Vec3{0, 0, 0}, Vec3{0, 1, 0})
	testing.expect(t, length(mat4_mul_point(view, Vec3{0, 0, 5})) < 1e-5) // eye maps to origin
}

@(test)
test_look_at_target_in_front :: proc(t: ^testing.T) {
	view := mat4_look_at(Vec3{0, 0, 5}, Vec3{0, 0, 0}, Vec3{0, 1, 0})
	p := mat4_mul_point(view, Vec3{0, 0, 0}) // target sits 5 units down -z
	testing.expect(t, abs(p.x) < 1e-5 && abs(p.y) < 1e-5 && abs(p.z + 5) < 1e-5)
}

@(test)
test_perspective_depth_range :: proc(t: ^testing.T) {
	proj := mat4_perspective(1.0472, 1.0, 1.0, 10.0)
	cn := proj * Vec4{0, 0, -1, 1}   // near plane -> ndc.z ~ 0
	cf := proj * Vec4{0, 0, -10, 1}  // far plane  -> ndc.z ~ 1
	testing.expect(t, abs(cn.z / cn.w - 0) < 1e-4)
	testing.expect(t, abs(cf.z / cf.w - 1) < 1e-4)
}

@(test)
test_orthographic_corners :: proc(t: ^testing.T) {
	proj := mat4_orthographic(-2, 2, -1.5, 1.5, 1, 10)
	// ortho keeps w = 1, so mat4_mul_point gives NDC directly (no divide).
	lo := mat4_mul_point(proj, Vec3{-2, -1.5, -1})   // left/bottom/near -> (-1,-1,0)
	hi := mat4_mul_point(proj, Vec3{ 2,  1.5, -10})  // right/top/far    -> ( 1, 1,1)
	testing.expect(t, length(lo - Vec3{-1, -1, 0}) < 1e-5)
	testing.expect(t, length(hi - Vec3{ 1,  1, 1}) < 1e-5)
}

@(test)
test_normal_matrix_rotation :: proc(t: ^testing.T) {
	// for a pure rotation (orthonormal), inverse-transpose == the matrix itself
	r := mat4_rotate(Vec3{0, 1, 0}, 0.9)
	nm := normal_matrix(r)
	rm := mat3_from_mat4(r)
	diff: f32 = 0
	for i in 0 ..< 3 {
		for j in 0 ..< 3 {
			diff += abs(nm[i, j] - rm[i, j])
		}
	}
	testing.expect(t, diff < 1e-4)
}

@(test)
test_normal_matrix_nonuniform_scale :: proc(t: ^testing.T) {
	// a surface normal (1,0,0) and in-plane tangent (0,1,0) under scale(2,1,1):
	// the normal-matrix'd normal must stay perpendicular to the scaled tangent.
	model := mat4_scale(Vec3{2, 1, 1})
	nm := normal_matrix(model)
	n := normalize(nm * Vec3{1, 0, 0})     // transformed normal
	tan := mat3_from_mat4(model) * Vec3{0, 1, 0} // tangent scaled by the model
	testing.expect(t, abs(dot(n, tan)) < 1e-5)
}
