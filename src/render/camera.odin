package render

import m "../math"

// A simple perspective camera.
Camera :: struct {
	eye:    m.Vec3,
	target: m.Vec3,
	up:     m.Vec3,
	fov_y:  f32, // vertical field of view, radians
	aspect: f32, // width / height
	near:   f32,
	far:    f32,
}

// projection * view. Multiply by a model matrix to get the full MVP:
//   mvp = camera_view_proj(cam) * model
camera_view_proj :: proc(c: Camera) -> m.Mat4 {
	return m.mat4_perspective(c.fov_y, c.aspect, c.near, c.far) * m.mat4_look_at(c.eye, c.target, c.up)
}
