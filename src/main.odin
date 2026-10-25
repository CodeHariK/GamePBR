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

SUN_DIR :: m.Vec3{0.55, 0.55, 0.62} // upper right, toward the camera

main :: proc() {
	sphere := mesh.make_sphere(1.0, 64, 48)
	defer mesh.destroy(&sphere)

	// --- the environment: a 512×256 HDR sky, and its irradiance map ---
	env := render.make_sky_env(512, 256, SUN_DIR)
	defer render.env_destroy(&env)
	small := render.env_downsample(&env, 4) // 128×64 is plenty to convolve
	defer render.env_destroy(&small)
	irr := render.convolve_irradiance(&small, 32, 16)
	defer render.env_destroy(&irr)

	aces := utils.display_default()

	// --- 1. the maps themselves, as lat-long images ---
	write_env_image(&env, aces, 1, "ibl_env.png")
	// E/π = the radiance a white Lambert surface facing that way would reflect,
	// which puts the irradiance map on the same scale as the sky it came from.
	write_env_image(&irr, aces, 1 / math.PI, "ibl_irradiance.png")

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	// --- 2. flat ambient vs. diffuse IBL, same sphere, same sky ---
	cam := render.Camera{
		eye = {0, 0.3, 4.2}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	grey := render.pbr_material(m.Vec3{0.8, 0.8, 0.8}, 0, 0.9)
	flat := render.ShadeCtx{model = .PBR, mat = grey, eye = cam.eye, ambient = env_mean(&small)}
	lit := render.ShadeCtx{model = .PBR, mat = grey, eye = cam.eye, env_irr = &irr}
	render.draw_env_background(&f, cam, &env)
	fb.clear_depth(&f, 1.0)
	draw_ball(&f, cam, &sphere, m.Vec3{-1.15, 0, 0}, 0.95, flat)
	draw_ball(&f, cam, &sphere, m.Vec3{1.15, 0, 0}, 0.95, lit)
	utils.resolve(&f, aces)
	if utils.write_png(&f, "ibl_ambient_vs_ibl.png") { fmt.println("wrote ibl_ambient_vs_ibl.png") }

	// --- 3. materials lit by the sky alone (no punctual lights) ---
	row_cam := render.Camera{
		eye = {0, 0.4, 5.0}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	draw_material_row(&f, row_cam, &sphere, &env, &irr)
	utils.resolve(&f, aces)
	if utils.write_png(&f, "ibl_materials.png") { fmt.println("wrote ibl_materials.png") }

	// --- live: orbit the camera; the sky turns behind the spheres ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		a := f32(frame) * 0.01
		orbit := row_cam
		orbit.eye = m.Vec3{5.0 * math.sin(a), 0.4, 5.0 * math.cos(a)}
		draw_material_row(&f, orbit, &sphere, &env, &irr)
		utils.resolve(&f, aces)
		display.present(&display, &f)
		frame += 1
	}
}

// White rough, red plastic, teal plastic, gold metal — sky lighting only.
draw_material_row :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, env, irr: ^render.EnvMap) {
	render.draw_env_background(f, cam, env)
	fb.clear_depth(f, 1.0)
	mats := [4]render.Material{
		render.pbr_material(m.Vec3{0.85, 0.85, 0.85}, 0, 0.7),
		render.pbr_material(m.Vec3{0.85, 0.12, 0.10}, 0, 0.35),
		render.pbr_material(m.Vec3{0.10, 0.50, 0.55}, 0, 0.5),
		render.pbr_material(m.Vec3{1.00, 0.77, 0.34}, 1, 0.3),
	}
	for mat, i in mats {
		x := (f32(i) - 1.5) * 1.45
		sh := render.ShadeCtx{model = .PBR, mat = mat, eye = cam.eye, env_irr = irr}
		draw_ball(f, cam, sphere, m.Vec3{x, 0, 0}, 0.62, sh)
	}
}

draw_ball :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, pos: m.Vec3, r: f32, sh: render.ShadeCtx) {
	model := m.mat4_translate(pos) * m.mat4_scale(m.Vec3{r, r, r})
	render.draw_mesh_lit(f, render.camera_view_proj(cam) * model, model, sphere, sh, WIDTH, HEIGHT)
}

// Solid-angle-weighted mean radiance of an environment: the single flat
// "ambient" colour that delivers the same TOTAL light as the sky.
env_mean :: proc(e: ^render.EnvMap) -> m.Vec3 {
	acc := m.Vec3{}
	total: f32 = 0
	for y in 0 ..< e.height {
		dw := render.env_texel_solid_angle(e, y)
		for x in 0 ..< e.width {
			acc += e.px[y * e.width + x] * dw
			total += dw
		}
	}
	return acc / total
}

// Show a lat-long map (×scale) as a 2:1 image, bilinear-upscaled to 768×384.
write_env_image :: proc(e: ^render.EnvMap, d: utils.Display, scale: f32, path: string) {
	img := fb.create(768, 384)
	defer fb.destroy(&img)
	for y in 0 ..< img.height {
		for x in 0 ..< img.width {
			u := (f32(x) + 0.5) / f32(img.width)
			v := (f32(y) + 0.5) / f32(img.height)
			img.hdr[y * img.width + x] = render.env_sample_uv(e, u, v) * scale
		}
	}
	utils.resolve(&img, d)
	if utils.write_png(&img, path) { fmt.println("wrote", path) }
}
