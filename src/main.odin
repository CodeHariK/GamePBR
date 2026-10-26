package main

import "core:fmt"
import "core:math"
import "core:time"
import "fb"
import m "math"
import "mesh"
import "render"
import "utils"

WIDTH  :: 960
HEIGHT :: 540

SUN_DIR :: m.Vec3{0.55, 0.55, 0.62} // upper right, toward the camera
BASE    :: m.Vec3{0.92, 0.46, 0.40} // step 11's grid colour, for comparison

main :: proc() {
	sphere := mesh.make_sphere(1.0, 64, 48)
	defer mesh.destroy(&sphere)

	// --- precompute everything IBL needs from one environment ---
	env := render.make_sky_env(512, 256, SUN_DIR)
	defer render.env_destroy(&env)
	t0 := time.tick_now()
	ibl := render.make_ibl_maps(&env, render.ibl_settings_default())
	defer render.ibl_maps_destroy(&ibl)
	fmt.printfln("IBL precompute: %.0f ms", time.duration_milliseconds(time.tick_since(t0)))

	aces := utils.display_default()

	// --- 1. the precomputed data ---
	write_prefiltered_strip(&ibl, aces, "ibl_prefiltered.png")
	write_brdf_lut(&ibl.lut, "ibl_brdf_lut.png")

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	// --- 2. step 15's material row, now with reflections ---
	row_cam := render.Camera{
		eye = {0, 0.4, 5.0}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	draw_material_row(&f, row_cam, &sphere, &env, &ibl)
	utils.resolve(&f, aces)
	if utils.write_png(&f, "ibl_materials.png") { fmt.println("wrote ibl_materials.png") }

	// --- 3. step 11's metallic × roughness chart, lit by the sky alone ---
	draw_grid(&f, &sphere, &env, &ibl)
	utils.resolve(&f, aces)
	if utils.write_png(&f, "ibl_grid.png") { fmt.println("wrote ibl_grid.png") }

	// --- live: orbit the camera around the row ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		a := f32(frame) * 0.01
		orbit := row_cam
		orbit.eye = m.Vec3{5.0 * math.sin(a), 0.4, 5.0 * math.cos(a)}
		draw_material_row(&f, orbit, &sphere, &env, &ibl)
		utils.resolve(&f, aces)
		display.present(&display, &f)
		frame += 1
	}
}

ibl_ctx :: proc(cam: render.Camera, mat: render.Material, ibl: ^render.IBLMaps) -> render.ShadeCtx {
	return render.ShadeCtx{model = .PBR, mat = mat, eye = cam.eye, ibl = ibl}
}

// White rough, red plastic, teal plastic, gold metal — sky lighting only.
draw_material_row :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, env: ^render.EnvMap, ibl: ^render.IBLMaps) {
	render.draw_env_background(f, cam, env)
	fb.clear_depth(f, 1.0)
	mats := [4]render.Material{
		render.pbr_material(m.Vec3{0.85, 0.85, 0.85}, 0, 0.7),
		render.pbr_material(m.Vec3{0.85, 0.12, 0.10}, 0, 0.35),
		render.pbr_material(m.Vec3{0.10, 0.50, 0.55}, 0, 0.5),
		render.pbr_material(m.Vec3{1.00, 0.77, 0.34}, 1, 0.3),
	}
	for mat, i in mats {
		draw_ball(f, cam, sphere, m.Vec3{(f32(i) - 1.5) * 1.45, 0, 0}, 0.62, ibl_ctx(cam, mat, ibl))
	}
}

// Rows: dielectric (top), metal (bottom). Columns: roughness 0.05 → 1.0.
draw_grid :: proc(f: ^fb.Framebuffer, sphere: ^mesh.Mesh, env: ^render.EnvMap, ibl: ^render.IBLMaps) {
	cam := render.Camera{
		eye = {0, 0, 7.5}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	render.draw_env_background(f, cam, env)
	fb.clear_depth(f, 1.0)
	rough := [7]f32{0.05, 0.15, 0.3, 0.45, 0.6, 0.8, 1.0}
	for r in 0 ..< 2 {
		for c in 0 ..< 7 {
			pos := m.Vec3{(f32(c) - 3) * 1.25, r == 0 ? 0.85 : -0.85, 0}
			mat := render.pbr_material(BASE, f32(r), rough[c])
			draw_ball(f, cam, sphere, pos, 0.52, ibl_ctx(cam, mat, ibl))
		}
	}
}

draw_ball :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, pos: m.Vec3, r: f32, sh: render.ShadeCtx) {
	model := m.mat4_translate(pos) * m.mat4_scale(m.Vec3{r, r, r})
	render.draw_mesh_lit(f, render.camera_view_proj(cam) * model, model, sphere, sh, WIDTH, HEIGHT)
}

// The five prefiltered levels side by side (roughness 0 → 1, left to right),
// each upscaled to 256×128.
write_prefiltered_strip :: proc(ibl: ^render.IBLMaps, d: utils.Display, path: string) {
	cw :: 256; ch :: 128
	img := fb.create(cw * render.PREFILTER_LEVELS, ch)
	defer fb.destroy(&img)
	for lv in 0 ..< render.PREFILTER_LEVELS {
		for y in 0 ..< ch {
			for x in 0 ..< cw {
				u := (f32(x) + 0.5) / cw
				v := (f32(y) + 0.5) / ch
				img.hdr[y * img.width + lv * cw + x] = render.env_sample_uv(&ibl.prefiltered[lv], u, v)
			}
		}
	}
	utils.resolve(&img, d)
	if utils.write_png(&img, path) { fmt.println("wrote", path) }
}

// The LUT as an image: red = A, green = B (raw values, no tonemap).
// x = n·v (0 left → 1 right), y = roughness (0 top → 1 bottom).
write_brdf_lut :: proc(lut: ^render.BrdfLut, path: string) {
	size :: 256
	img := fb.create(size, size)
	defer fb.destroy(&img)
	for y in 0 ..< size {
		for x in 0 ..< size {
			ab := render.brdf_lut_sample(lut, (f32(x) + 0.5) / size, (f32(y) + 0.5) / size)
			img.pixels[y * size + x] = utils.to_color(m.Vec3{ab.x, ab.y, 0})
		}
	}
	if utils.write_png(&img, path) { fmt.println("wrote", path) }
}
