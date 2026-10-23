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

	// --- 1. one point light over the floor: the inverse-square pool ---
	falloff := [?]render.Light{render.point_light(m.Vec3{0, FLOOR_Y + 1.0, 0}, m.Vec3{1, 1, 1}, 3)}
	begin(&f)
	draw_floor(&f, &s, falloff[:])
	draw_markers(&f, &s, falloff[:])
	if utils.write_png(&f, "lights_point.png") { fmt.println("wrote lights_point.png") }

	// --- 2. a spot light: a cone with a soft inner→outer edge ---
	spot := [?]render.Light{
		render.spot_light(m.Vec3{2.2, 2.6, 1.6}, m.Vec3{-2.2, -3.6, -1.6}, m.Vec3{1, 1, 1}, 50,
			math.to_radians_f32(14), math.to_radians_f32(24)),
	}
	begin(&f)
	draw_floor(&f, &s, spot[:])
	draw_ball(&f, &s, m.Vec3{0, FLOOR_Y + 0.7, 0}, 0.7, render.pbr_material(m.Vec3{0.9, 0.9, 0.9}, 0, 0.5), spot[:])
	draw_markers(&f, &s, spot[:])
	if utils.write_png(&f, "lights_spot.png") { fmt.println("wrote lights_spot.png") }

	// --- 3. everything: warm + cool points, a white spot, dim blue moonlight ---
	scene := scene_lights(0)
	begin(&f)
	draw_scene(&f, &s, scene[:])
	if utils.write_png(&f, "lights_scene.png") { fmt.println("wrote lights_scene.png") }

	// --- live: the two point lights orbit the spheres ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		live := scene_lights(f32(frame) * 0.02)
		begin(&f)
		draw_scene(&f, &s, live[:])
		display.present(&display, &f)
		frame += 1
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
