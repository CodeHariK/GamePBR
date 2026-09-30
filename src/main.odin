package main

import "core:fmt"
import "fb"
import m "math"
import "mesh"
import "render"
import "utils"

WIDTH  :: 800
HEIGHT :: 600

main :: proc() {
	tex := render.make_checker(256, 8, fb.Color{235, 235, 240, 255}, fb.Color{40, 46, 66, 255})
	defer render.texture_destroy(&tex)

	mh, ok := mesh.load_obj("assets/torus.obj")
	if !ok {
		fmt.eprintln("failed to load assets/torus.obj (run from the repo root)")
		return
	}
	defer mesh.destroy(&mh)

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	// --- perspective correctness: a checker floor, affine vs correct ---
	floor_cam := render.Camera{
		eye    = {0, 1.25, 3.5},
		target = {0, 0, -3},
		up     = {0, 1, 0},
		fov_y  = 1.0472,
		aspect = f32(WIDTH) / f32(HEIGHT),
		near   = 0.1,
		far    = 100,
	}
	draw_floor(&f, floor_cam, &tex, false)
	if utils.write_png(&f, "floor_affine.png") {
		fmt.println("wrote floor_affine.png")
	}
	draw_floor(&f, floor_cam, &tex, true)
	if utils.write_png(&f, "floor_correct.png") {
		fmt.println("wrote floor_correct.png")
	}

	// --- textured mesh ---
	cam := render.Camera{
		eye    = {0, 1.3, 3.1},
		target = {0, 0, 0},
		up     = {0, 1, 0},
		fov_y  = 1.0472,
		aspect = f32(WIDTH) / f32(HEIGHT),
		near   = 0.1,
		far    = 100,
	}
	base := fit_transform(&mh)
	draw_torus(&f, cam, &mh, &tex, base, 0.6)
	if utils.write_png(&f, "torus_tex.png") {
		fmt.println("wrote torus_tex.png")
	}

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}
		draw_torus(&f, cam, &mh, &tex, base, f32(frame) * 0.01)
		display.present(&display, &f)
		frame += 1
	}
}

fit_transform :: proc(mh: ^mesh.Mesh) -> m.Mat4 {
	lo, hi := mesh.bounds(mh)
	center := (lo + hi) * 0.5
	size := hi - lo
	maxdim := max(size.x, max(size.y, size.z))
	s := maxdim > 0 ? 2.0 / maxdim : 1.0
	return m.mat4_scale(m.Vec3{s, s, s}) * m.mat4_translate(m.Vec3{-center.x, -center.y, -center.z})
}

// A large checker floor receding into the distance — the classic test for
// perspective-correct texture interpolation.
draw_floor :: proc(f: ^fb.Framebuffer, cam: render.Camera, tex: ^render.Texture, correct: bool) {
	fb.clear(f, fb.Color{18, 18, 24, 255})
	fb.clear_depth(f, 1.0)
	vp := render.camera_view_proj(cam)
	T :: f32(10.0) // uv tiles across the near edge
	a := render.Vertex3{pos = {-5, 0, -1},  uv = {0, 0}}
	b := render.Vertex3{pos = { 5, 0, -1},  uv = {T, 0}}
	c := render.Vertex3{pos = { 5, 0, -16}, uv = {T, T * 1.5}}
	d := render.Vertex3{pos = {-5, 0, -16}, uv = {0, T * 1.5}}
	render.triangle3(f, vp, a, b, c, tex, correct, WIDTH, HEIGHT)
	render.triangle3(f, vp, a, c, d, tex, correct, WIDTH, HEIGHT)
}

draw_torus :: proc(f: ^fb.Framebuffer, cam: render.Camera, mh: ^mesh.Mesh, tex: ^render.Texture, base: m.Mat4, angle: f32) {
	fb.clear(f, fb.Color{18, 18, 24, 255})
	fb.clear_depth(f, 1.0)
	model := m.mat4_rotate(m.Vec3{0, 1, 0}, angle) * m.mat4_rotate(m.Vec3{1, 0, 0}, 0.5) * base
	mvp := render.camera_view_proj(cam) * model
	render.draw_mesh_textured(f, mvp, mh, tex, WIDTH, HEIGHT)
}
