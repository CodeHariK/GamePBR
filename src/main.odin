package main

import "core:fmt"
import "fb"
import m "math"
import "render"
import "utils"

WIDTH  :: 800
HEIGHT :: 600

// A cube face: four corner indices (into `cube`) and a flat color.
Face :: struct {
	i:     [4]int,
	color: m.Vec3,
}

main :: proc() {
	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	cam := render.Camera{
		eye    = {2.5, 2.0, 3.5},
		target = {0, 0, 0},
		up     = {0, 1, 0},
		fov_y  = 1.0472, // 60 degrees
		aspect = f32(WIDTH) / f32(HEIGHT),
		near   = 0.1,
		far    = 100,
	}

	// One frame to disk (fixed angle) for the devlog.
	draw_scene(&f, cam, 0.2)
	if utils.write_ppm(&f, "cube.ppm") {
		fmt.println("wrote cube.ppm")
	}
	if utils.write_png(&f, "cube.png") {
		fmt.println("wrote cube.png")
	}

	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	// Spin the cube over time.
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit {
			break
		}
		draw_scene(&f, cam, f32(frame) * 0.02)
		display.present(&display, &f)
		frame += 1
	}
}

// Step 05: a perspective-projected cube, spinning about Y with a fixed X tilt.
draw_scene :: proc(f: ^fb.Framebuffer, cam: render.Camera, angle: f32) {
	fb.clear(f, fb.Color{18, 18, 24, 255})
	fb.clear_depth(f, 1.0)

	model := m.mat4_rotate(m.Vec3{0, 1, 0}, angle) * m.mat4_rotate(m.Vec3{1, 0, 0}, 0.5)
	mvp := render.camera_view_proj(cam) * model

	cube := [8]m.Vec3{
		{-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1}, // back  (z=-1)
		{-1, -1,  1}, {1, -1,  1}, {1, 1,  1}, {-1, 1,  1}, // front (z=+1)
	}
	faces := [6]Face{
		{{4, 5, 6, 7}, {0.90, 0.30, 0.30}}, // front  red
		{{1, 0, 3, 2}, {0.30, 0.80, 0.40}}, // back   green
		{{0, 4, 7, 3}, {0.30, 0.50, 0.95}}, // left   blue
		{{5, 1, 2, 6}, {0.95, 0.80, 0.30}}, // right  yellow
		{{3, 7, 6, 2}, {0.35, 0.85, 0.90}}, // top    cyan
		{{0, 1, 5, 4}, {0.85, 0.40, 0.85}}, // bottom magenta
	}

	for face in faces {
		p0 := cube[face.i[0]]
		p1 := cube[face.i[1]]
		p2 := cube[face.i[2]]
		p3 := cube[face.i[3]]
		render.triangle3(f, mvp, render.Vertex3{p0, face.color}, render.Vertex3{p1, face.color}, render.Vertex3{p2, face.color}, WIDTH, HEIGHT)
		render.triangle3(f, mvp, render.Vertex3{p0, face.color}, render.Vertex3{p2, face.color}, render.Vertex3{p3, face.color}, WIDTH, HEIGHT)
	}
}
