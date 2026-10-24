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

AMBIENT :: m.Vec3{0.01, 0.01, 0.012}
BG      :: fb.Color{10, 10, 14, 255}
FLOOR_Y :: f32(-1.0)

Scene :: struct {
	floor:  mesh.Mesh,
	sphere: mesh.Mesh,
	cam:    render.Camera,
}

main :: proc() {
	s := Scene{
		floor  = mesh.make_plane(4.5, 4),
		sphere = mesh.make_sphere(1.0, 64, 48),
		cam    = render.Camera{
			eye = {0, 2.4, 6.2}, target = {0, -0.5, 0}, up = {0, 1, 0},
			fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
		},
	}
	defer mesh.destroy(&s.floor)
	defer mesh.destroy(&s.sphere)

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	// --- 1. the operators themselves: HDR ramps through each display transform ---
	draw_ramps(&f)
	if utils.write_png(&f, "tone_ramps.png") { fmt.println("wrote tone_ramps.png") }

	// --- 2. render the four-light scene ONCE into the HDR buffer... ---
	scene := scene_lights(0)
	begin(&f)
	draw_scene(&f, &s, scene[:])

	// --- ...then resolve it six ways. No re-rendering: that's what HDR buys. ---
	Look :: struct { name: string, d: utils.Display }
	looks := [?]Look{
		{"tone_clamp_linear.png", {op = .Clamp, srgb = false}},  // steps 09-13
		{"tone_clamp_srgb.png",   {op = .Clamp, srgb = true}},
		{"tone_reinhard.png",     {op = .Reinhard, srgb = true}},
		{"tone_aces.png",         {op = .ACES, srgb = true}},
		{"tone_aces_ev-1.png",    {op = .ACES, exposure_ev = -1, srgb = true}},
		{"tone_aces_ev+1.png",    {op = .ACES, exposure_ev = 1, srgb = true}},
	}
	for l in looks {
		utils.resolve(&f, l.d)
		if utils.write_png(&f, l.name) { fmt.println("wrote", l.name) }
	}

	// --- live: orbiting lights, ACES + sRGB ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		live := scene_lights(f32(frame) * 0.02)
		begin(&f)
		draw_scene(&f, &s, live[:])
		utils.resolve(&f, utils.display_default())
		display.present(&display, &f)
		frame += 1
	}
}

// Four horizontal bands, one per display transform. Within each band x is HDR
// radiance on a log scale from 1/16 (left) to 16 (right) — 1.0 sits at the
// centre, marked by a thin line. Top of each band: grey; bottom: saturated
// orange, to show what each operator does to hue as it brightens.
draw_ramps :: proc(f: ^fb.Framebuffer) {
	bands := [4]utils.Display{
		{op = .Clamp, srgb = false},
		{op = .Clamp, srgb = true},
		{op = .Reinhard, srgb = true},
		{op = .ACES, srgb = true},
	}
	orange := m.Vec3{1.0, 0.45, 0.12}
	bh := f.height / 4
	for y in 0 ..< f.height {
		band := min(y / bh, 3)
		row := y - band * bh
		for x in 0 ..< f.width {
			idx := y * f.width + x
			if row < 3 || x == f.width / 2 {
				f.pixels[idx] = fb.Color{60, 60, 70, 255} // separators + the 1.0 mark
				continue
			}
			r := math.pow(f32(2), -4 + 8 * f32(x) / f32(f.width))
			c := row < bh * 3 / 5 ? m.Vec3{r, r, r} : orange * r
			f.pixels[idx] = utils.encode_pixel(c, bands[band])
		}
	}
}

// Warm and cool point lights orbiting at angle `t`, plus a spot and moonlight.
scene_lights :: proc(t: f32) -> [4]render.Light {
	return [4]render.Light{
		render.point_light(m.Vec3{-2.6 * math.cos(t), 0.6, 1.6 * math.cos(t) + 0.9 * math.sin(t)},
			m.Vec3{1.0, 0.55, 0.2}, 6, 9),
		render.point_light(m.Vec3{2.6 * math.cos(t), 0.8, -0.4 - 1.2 * math.sin(t)},
			m.Vec3{0.3, 0.55, 1.0}, 6, 9),
		render.spot_light(m.Vec3{0, 3.2, 1.2}, m.Vec3{0, -4.2, -1.2}, m.Vec3{1, 1, 1}, 40,
			math.to_radians_f32(12), math.to_radians_f32(22)),
		render.directional_light(m.Vec3{0.3, -1, -0.4}, m.Vec3{0.6, 0.7, 1.0}, 0.25),
	}
}

draw_scene :: proc(f: ^fb.Framebuffer, s: ^Scene, lights: []render.Light) {
	draw_floor(f, s, lights)
	y := FLOOR_Y + 0.7
	draw_ball(f, s, m.Vec3{-1.8, y, 0}, 0.7, render.pbr_material(m.Vec3{1.0, 0.77, 0.34}, 1, 0.2), lights)
	draw_ball(f, s, m.Vec3{0, y, 0}, 0.7, render.pbr_material(m.Vec3{0.85, 0.12, 0.10}, 0, 0.35), lights)
	draw_ball(f, s, m.Vec3{1.8, y, 0}, 0.7, render.pbr_material(m.Vec3{0.9, 0.9, 0.9}, 0, 0.8), lights)
	draw_markers(f, s, lights)
}

begin :: proc(f: ^fb.Framebuffer) {
	fb.clear(f, BG)
	fb.clear_hdr(f, utils.srgb_to_linear3(utils.to_vec3(BG))) // same color, linear
	fb.clear_depth(f, 1.0)
}

lit_ctx :: proc(s: ^Scene, mat: render.Material, lights: []render.Light) -> render.ShadeCtx {
	return render.ShadeCtx{model = .PBR, lights = lights, mat = mat, eye = s.cam.eye, ambient = AMBIENT}
}

// The XY plane, laid flat (facing +Y) at FLOOR_Y.
draw_floor :: proc(f: ^fb.Framebuffer, s: ^Scene, lights: []render.Light) {
	model := m.mat4_translate(m.Vec3{0, FLOOR_Y, 0}) * m.mat4_rotate(m.Vec3{1, 0, 0}, -math.PI / 2)
	sh := lit_ctx(s, render.pbr_material(m.Vec3{0.7, 0.7, 0.7}, 0, 0.7), lights)
	render.draw_mesh_lit(f, render.camera_view_proj(s.cam) * model, model, &s.floor, sh, WIDTH, HEIGHT)
}

draw_ball :: proc(f: ^fb.Framebuffer, s: ^Scene, pos: m.Vec3, r: f32, mat: render.Material, lights: []render.Light) {
	model := m.mat4_translate(pos) * m.mat4_scale(m.Vec3{r, r, r})
	render.draw_mesh_lit(f, render.camera_view_proj(s.cam) * model, model, &s.sphere, lit_ctx(s, mat, lights), WIDTH, HEIGHT)
}

// A small emissive (unlit) sphere at each point/spot light, in the light's color.
draw_markers :: proc(f: ^fb.Framebuffer, s: ^Scene, lights: []render.Light) {
	for l in lights {
		if l.kind == .Directional { continue }
		mat := render.Material{emissive = l.color}
		model := m.mat4_translate(l.pos) * m.mat4_scale(m.Vec3{0.07, 0.07, 0.07})
		sh := render.ShadeCtx{model = .PBR, mat = mat, eye = s.cam.eye} // no lights: emission only
		render.draw_mesh_lit(f, render.camera_view_proj(s.cam) * model, model, &s.sphere, sh, WIDTH, HEIGHT)
	}
}
