package gmath

import "core:math"

// Vectors are just fixed-size arrays. Odin gives `[N]f32` component-wise
// operators (+ - * /), scalar broadcast (v * 2), and swizzling (v.xyz, v.x)
// for free — so we only hand-write the operations that carry geometric
// meaning. That "understand the math, skip the boilerplate" trade is exactly
// why this project uses Odin.

Vec2 :: [2]f32
Vec3 :: [3]f32
Vec4 :: [4]f32

dot :: proc(a, b: Vec3) -> f32 {
	return a.x * b.x + a.y * b.y + a.z * b.z
}

// Right-handed cross product: cross(x, y) == z.
cross :: proc(a, b: Vec3) -> Vec3 {
	return Vec3{
		a.y * b.z - a.z * b.y,
		a.z * b.x - a.x * b.z,
		a.x * b.y - a.y * b.x,
	}
}

length_squared :: proc(v: Vec3) -> f32 {
	return dot(v, v)
}

length :: proc(v: Vec3) -> f32 {
	return math.sqrt(dot(v, v))
}

// Returns v unchanged if it's the zero vector (avoids divide-by-zero).
normalize :: proc(v: Vec3) -> Vec3 {
	l := length(v)
	if l == 0 {
		return v
	}
	return v / l // scalar divide broadcasts across components
}

lerp :: proc(a, b: Vec3, t: f32) -> Vec3 {
	return a + (b - a) * t
}

// Mirror incident direction `i` about surface normal `n` (n assumed unit).
// This is the specular-reflection workhorse used from step 09 onward.
reflect :: proc(i, n: Vec3) -> Vec3 {
	return i - 2 * dot(i, n) * n
}

// Clamp a scalar to [0, 1]. Shows up everywhere in shading (e.g. max(N·L, 0)).
saturate :: proc(x: f32) -> f32 {
	return clamp(x, 0, 1)
}
