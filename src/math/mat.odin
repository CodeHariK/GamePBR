package gmath

import "core:math"

// Odin has a real `matrix` type: `A * B` is matrix multiply and `M * v` is
// matrix-times-column-vector, both built in. So we only hand-write the
// *constructors* — the part that actually teaches you how a transform is
// assembled. Convention here: column-vector math, so transforms compose as
// M = T * R * S and apply as p' = M * p.
//
// Storage note: Odin stores matrices column-major, but a matrix *literal* is
// written row-major (the intuitive way). The literals below read exactly like
// the math on paper.

Mat4 :: matrix[4, 4]f32

mat4_identity :: proc() -> Mat4 {
	return Mat4{
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		0, 0, 0, 1,
	}
}

mat4_translate :: proc(t: Vec3) -> Mat4 {
	return Mat4{
		1, 0, 0, t.x,
		0, 1, 0, t.y,
		0, 0, 1, t.z,
		0, 0, 0, 1,
	}
}

mat4_scale :: proc(s: Vec3) -> Mat4 {
	return Mat4{
		s.x, 0,   0,   0,
		0,   s.y, 0,   0,
		0,   0,   s.z, 0,
		0,   0,   0,   1,
	}
}

// Axis-angle rotation, angle in radians.
// https://mathworld.wolfram.com/RotationFormula.html
// v' = v·cosθ  +  (k × v)·sinθ  +  k·(k·v)·(1 − cosθ)
mat4_rotate :: proc(axis: Vec3, angle_rad: f32) -> Mat4 {
	a := normalize(axis)
	c := math.cos(angle_rad)
	s := math.sin(angle_rad)
	t := 1 - c
	x, y, z := a.x, a.y, a.z
	return Mat4{
		t*x*x + c,   t*x*y - s*z, t*x*z + s*y, 0,
		t*x*y + s*z, t*y*y + c,   t*y*z - s*x, 0,
		t*x*z - s*y, t*y*z + s*x, t*z*z + c,   0,
		0,           0,           0,           1,
	}
}

// Transform a position: w = 1, so translation applies. No perspective divide
// here — that arrives with the projection matrix in step 05.
mat4_mul_point :: proc(m: Mat4, p: Vec3) -> Vec3 {
	v := m * Vec4{p.x, p.y, p.z, 1}
	return v.xyz
}

// Transform a direction/normal: w = 0, so translation is ignored.
mat4_mul_dir :: proc(m: Mat4, d: Vec3) -> Vec3 {
	v := m * Vec4{d.x, d.y, d.z, 0}
	return v.xyz
}

// (Odin also provides builtin `transpose(m)` and `core:math/linalg.inverse`
//  when we need them later.)
