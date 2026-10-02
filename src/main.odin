package main

import "core:fmt"
import "core:math"
import "fb"
import m "math"
import "mesh"
import "render"
import "utils"

WIDTH  :: 960
HEIGHT :: 540

LIGHT_DIR :: m.Vec3{-0.4, -0.7, -0.5}
AMBIENT   :: m.Vec3{0.03, 0.03, 0.04}
BG        :: fb.Color{16, 16, 20, 255}
BASE      :: m.Vec3{0.92, 0.46, 0.40} // shared base color for the grid

main :: proc() {
	sphere := mesh.make_sphere(1.0, 64, 48)
	defer mesh.destroy(&sphere)

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	light := render.DirLight{dir = m.normalize(LIGHT_DIR), color = {1, 1, 1}, intensity = 3.0}

	// --- metallic × roughness grid: the canonical PBR test chart ---
	draw_grid(&f, &sphere, light)
	if utils.write_png(&f, "pbr_grid.png") { fmt.println("wrote pbr_grid.png") }

	// --- hero: a glossy dielectric sphere (diffuse body + sharp Fresnel highlight).
	// A metal would be near-black here: with no environment to reflect, one point
	// light can't light it — exactly the gap IBL (steps 15-16) fills. ---
	hero_cam := render.Camera{
		eye = {0, 0, 3.0}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	glossy := render.pbr_material(m.Vec3{0.90, 0.33, 0.28}, 0.0, 0.22)
	draw_single(&f, hero_cam, &sphere, render.ShadeCtx{
		model = .PBR, light = light, mat = glossy, eye = hero_cam.eye, ambient = AMBIENT})
	if utils.write_png(&f, "pbr_hero.png") { fmt.println("wrote pbr_hero.png") }

	// --- live: a spinning sun over a dielectric sphere ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)

	plastic := render.pbr_material(m.Vec3{0.90, 0.40, 0.35}, 0.0, 0.35)
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		ang := f32(frame) * 0.02
		dir := m.Vec3{math.cos(ang) * 0.6, -0.7, math.sin(ang) * 0.6}
		spin := render.DirLight{dir = m.normalize(dir), color = {1, 1, 1}, intensity = 3.0}
		draw_single(&f, hero_cam, &sphere, render.ShadeCtx{
			model = .PBR, light = spin, mat = plastic, eye = hero_cam.eye, ambient = AMBIENT})
		display.present(&display, &f)
		frame += 1
	}
}

draw_single :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, sh: render.ShadeCtx) {
	fb.clear(f, BG)
	fb.clear_depth(f, 1.0)
	model := m.mat4_identity()
	mvp := render.camera_view_proj(cam) * model
	render.draw_mesh_lit(f, mvp, model, sphere, sh, WIDTH, HEIGHT)
}

// Rows = metallic (dielectric top, metal bottom); columns = roughness, low → high.
draw_grid :: proc(f: ^fb.Framebuffer, sphere: ^mesh.Mesh, light: render.DirLight) {
	fb.clear(f, BG)
	fb.clear_depth(f, 1.0)
	cam := render.Camera{
		eye = {0, 0, 7.5}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	vp := render.camera_view_proj(cam)
	rough := [7]f32{0.05, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0}
	metal := [2]f32{0.0, 1.0}
	for r in 0 ..< 2 {
		for c in 0 ..< 7 {
			x := (f32(c) - 3.0) * 1.25
			y: f32 = r == 0 ? 0.85 : -0.85
			model := m.mat4_translate(m.Vec3{x, y, 0}) * m.mat4_scale(m.Vec3{0.52, 0.52, 0.52})
			mat := render.pbr_material(BASE, metal[r], rough[c])
			sh := render.ShadeCtx{model = .PBR, light = light, mat = mat, eye = cam.eye, ambient = AMBIENT}
			render.draw_mesh_lit(f, vp * model, model, sphere, sh, WIDTH, HEIGHT)
		}
	}
}
