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
