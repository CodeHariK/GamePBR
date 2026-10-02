package main

import "core:fmt"
import "core:math"
import "fb"
import m "math"
import "mesh"
import "render"
import "utils"

WIDTH  :: 800
HEIGHT :: 600

// Scene light: a "sun" coming from the upper-right-front.
LIGHT_DIR :: m.Vec3{-0.4, -0.8, -0.5}
AMBIENT   :: m.Vec3{0.04, 0.04, 0.06}
ALBEDO    :: m.Vec3{0.85, 0.32, 0.28}
BG        :: fb.Color{18, 18, 24, 255}

main :: proc() {
	sphere := mesh.make_sphere(1.0, 64, 48)
	defer mesh.destroy(&sphere)

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	cam := render.Camera{
		eye = {0, 0, 3.2}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	light := render.DirLight{dir = m.normalize(LIGHT_DIR), color = {1, 1, 1}, intensity = 1.0}

	// --- 1. Lambert diffuse only (specular off) ---
	diffuse_mat := render.Material{albedo = ALBEDO, specular = {0, 0, 0}, shininess = 1}
	draw_single(&f, cam, &sphere, render.ShadeCtx{light = light, mat = diffuse_mat, eye = cam.eye, ambient = AMBIENT})
	if utils.write_png(&f, "sphere_diffuse.png") { fmt.println("wrote sphere_diffuse.png") }

	// --- 2. Diffuse + Blinn-Phong specular ---
	full_mat := render.Material{albedo = ALBEDO, specular = {1, 1, 1}, shininess = 48}
	draw_single(&f, cam, &sphere, render.ShadeCtx{light = light, mat = full_mat, eye = cam.eye, ambient = AMBIENT})
	if utils.write_png(&f, "sphere_blinn_phong.png") { fmt.println("wrote sphere_blinn_phong.png") }

	// --- 3. Shininess sweep: 8 / 48 / 256 across a row ---
	draw_shininess_row(&f, &sphere, light)
	if utils.write_png(&f, "sphere_shininess.png") { fmt.println("wrote sphere_shininess.png") }

	// --- live: a spinning sun over a lit sphere ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		ang := f32(frame) * 0.02
		dir := m.Vec3{math.cos(ang) * 0.6, -0.7, math.sin(ang) * 0.6}
		spin := render.DirLight{dir = m.normalize(dir), color = {1, 1, 1}, intensity = 1.0}
		draw_single(&f, cam, &sphere, render.ShadeCtx{light = spin, mat = full_mat, eye = cam.eye, ambient = AMBIENT})
		display.present(&display, &f)
		frame += 1
	}
}

// One centered sphere at the origin.
draw_single :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, sh: render.ShadeCtx) {
	fb.clear(f, BG)
	fb.clear_depth(f, 1.0)
	model := m.mat4_identity()
	mvp := render.camera_view_proj(cam) * model
	render.draw_mesh_lit(f, mvp, model, sphere, sh, WIDTH, HEIGHT)
}

// Three spheres left-to-right with tightening highlights.
draw_shininess_row :: proc(f: ^fb.Framebuffer, sphere: ^mesh.Mesh, light: render.DirLight) {
	fb.clear(f, BG)
	fb.clear_depth(f, 1.0)
	cam := render.Camera{
		eye = {0, 0, 5.2}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	vp := render.camera_view_proj(cam)
	xs := [3]f32{-1.9, 0, 1.9}
	shin := [3]f32{8, 48, 256}
	for i in 0 ..< 3 {
		model := m.mat4_translate(m.Vec3{xs[i], 0, 0}) * m.mat4_scale(m.Vec3{0.8, 0.8, 0.8})
		mat := render.Material{albedo = ALBEDO, specular = {1, 1, 1}, shininess = shin[i]}
		sh := render.ShadeCtx{light = light, mat = mat, eye = cam.eye, ambient = AMBIENT}
		render.draw_mesh_lit(f, vp * model, model, sphere, sh, WIDTH, HEIGHT)
	}
}
