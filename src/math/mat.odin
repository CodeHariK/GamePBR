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

// --- Camera matrices (added in step 05) ---

// Right-handed orthographic projection with NDC z in [0, 1] (matches our depth
// convention and WebGPU/Metal). Maps the box [left,right] x [bottom,top] x
// [-near,-far] onto the cube [-1,1]^2 x [0,1]. No perspective divide: w stays 1,
// so parallel lines stay parallel and size is independent of distance.
mat4_orthographic :: proc(left, right, bottom, top, near, far: f32) -> Mat4 {
	return Mat4{
		2 / (right - left), 0,                  0,                -(right + left) / (right - left),
		0,                  2 / (top - bottom), 0,                -(top + bottom) / (top - bottom),
		0,                  0,                  -1 / (far - near), -near / (far - near),
		0,                  0,                  0,                 1,
	}
}

// Right-handed perspective projection with NDC z in [0, 1] (matches our depth
// convention and WebGPU/Metal). fov_y is the vertical field of view in radians;
// aspect = width/height. The camera looks down its local -z.
mat4_perspective :: proc(fov_y, aspect, near, far: f32) -> Mat4 {
	f := 1.0 / math.tan(fov_y * 0.5)
	return Mat4{
		f / aspect, 0, 0,                  0,
		0,          f, 0,                  0,
		0,          0, far / (near - far), (far * near) / (near - far),
		0,          0, -1,                 0,
	}
}

// p_cam = view · p_world = Rᵀ · T(−eye) · p_world = Rᵀ · (p_world − eye)
// Right-handed look-at view matrix: camera at `eye` looking toward `target`,
// with `up` giving roll. Rows are the camera's right / up / -forward axes plus
// the translation that moves the eye to the origin.
mat4_look_at :: proc(eye, target, up: Vec3) -> Mat4 {
	f := normalize(target - eye) // forward
	s := normalize(cross(f, up)) // right
	u := cross(s, f)             // true up
	return Mat4{
		 s.x,  s.y,  s.z, -dot(s, eye),
		 u.x,  u.y,  u.z, -dot(u, eye),
		-f.x, -f.y, -f.z,  dot(f, eye),
		 0,    0,    0,     1,
	}
}

// --- 3x3 matrices & the normal matrix (added in step 08) ---

Mat3 :: matrix[3, 3]f32

// Upper-left 3x3 of a 4x4 (drops translation).
mat3_from_mat4 :: proc(m: Mat4) -> Mat3 {
	return Mat3{
		m[0, 0], m[0, 1], m[0, 2],
		m[1, 0], m[1, 1], m[1, 2],
		m[2, 0], m[2, 1], m[2, 2],
	}
}

// Closed-form 3x3 inverse (returns the input unchanged if singular).
mat3_inverse :: proc(m: Mat3) -> Mat3 {
	a := m[0, 0]; b := m[0, 1]; c := m[0, 2]
	d := m[1, 0]; e := m[1, 1]; f := m[1, 2]
	g := m[2, 0]; h := m[2, 1]; i := m[2, 2]

	det := a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
	if det == 0 {
		return m
	}
	inv := 1.0 / det
	return Mat3{
		(e * i - f * h) * inv, (c * h - b * i) * inv, (b * f - c * e) * inv,
		(f * g - d * i) * inv, (a * i - c * g) * inv, (c * d - a * f) * inv,
		(d * h - e * g) * inv, (b * g - a * h) * inv, (a * e - b * d) * inv,
	}
}

mat3_transpose :: proc(m: Mat3) -> Mat3 {
	return Mat3{
		m[0, 0], m[1, 0], m[2, 0],
		m[0, 1], m[1, 1], m[2, 1],
		m[0, 2], m[1, 2], m[2, 2],
	}
}

// The normal matrix: inverse-transpose of the model's upper-3x3. Transforming a
// normal by this (then normalizing) keeps it perpendicular to the surface even
// under non-uniform scale, where the plain model matrix would skew it.
normal_matrix :: proc(model: Mat4) -> Mat3 {
	return mat3_transpose(mat3_inverse(mat3_from_mat4(model)))
}
