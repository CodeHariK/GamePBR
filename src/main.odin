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
	mh, ok := mesh.load_obj("assets/torus.obj")
	if !ok {
		fmt.eprintln("failed to load assets/torus.obj (run from the repo root)")
		return
	}
	defer mesh.destroy(&mh)
	fmt.printfln("loaded torus: %d vertices, %d triangles", len(mh.positions), len(mh.indices) / 3)

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	cam := render.Camera{
		eye    = {0, 1.4, 3.2},
		target = {0, 0, 0},
		up     = {0, 1, 0},
		fov_y  = 1.0472, // 60 degrees
		aspect = f32(WIDTH) / f32(HEIGHT),
		near   = 0.1,
		far    = 100,
	}
	base := fit_transform(&mh)

	// Two frames to disk for the devlog: filled and wireframe.
	draw_scene(&f, cam, &mh, base, 0.6, false)
	if utils.write_png(&f, "torus_filled.png") {
		fmt.println("wrote torus_filled.png")
	}
	draw_scene(&f, cam, &mh, base, 0.6, true)
	if utils.write_png(&f, "torus_wire.png") {
		fmt.println("wrote torus_wire.png")
	}

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR  (press W to toggle wireframe)")
	defer display.destroy(&display)

	wire := false
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}
		if input.toggle_wire {
			wire = !wire
		}
		draw_scene(&f, cam, &mh, base, f32(frame) * 0.01, wire)
		display.present(&display, &f)
		frame += 1
	}
}

// Center the mesh at the origin and scale it to roughly a 2-unit box.
fit_transform :: proc(mh: ^mesh.Mesh) -> m.Mat4 {
	lo, hi := mesh.bounds(mh)
	center := (lo + hi) * 0.5
	size := hi - lo
	maxdim := max(size.x, max(size.y, size.z))
	s := maxdim > 0 ? 2.0 / maxdim : 1.0
	return m.mat4_scale(m.Vec3{s, s, s}) * m.mat4_translate(m.Vec3{-center.x, -center.y, -center.z})
}

// Step 06: a loaded mesh, spun about Y, drawn filled (normal-colored) or wire.
draw_scene :: proc(f: ^fb.Framebuffer, cam: render.Camera, mh: ^mesh.Mesh, base: m.Mat4, angle: f32, wire: bool) {
	fb.clear(f, fb.Color{18, 18, 24, 255})
	fb.clear_depth(f, 1.0)

	model := m.mat4_rotate(m.Vec3{0, 1, 0}, angle) * m.mat4_rotate(m.Vec3{1, 0, 0}, 0.5) * base
	mvp := render.camera_view_proj(cam) * model

	if wire {
		render.draw_wire(f, mvp, mh, fb.Color{120, 220, 200, 255}, WIDTH, HEIGHT)
	} else {
		render.draw_mesh(f, mvp, mh, WIDTH, HEIGHT)
	}
}
