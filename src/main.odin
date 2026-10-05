package main

import "core:fmt"
import "fb"
import m "math"
import "mesh"
import "render"
import "utils"

WIDTH  :: 960
HEIGHT :: 540

AMBIENT   :: m.Vec3{0.05, 0.05, 0.06}
BG        :: fb.Color{16, 16, 20, 255}

main :: proc() {
	panel := render.make_panel_maps(256, 4)
	defer render.panel_maps_destroy(&panel)
	bumps := render.make_normal_map(256, 16)
	defer render.texture_destroy(&bumps)

	sphere := mesh.make_sphere(1.0, 96, 64)
	defer mesh.destroy(&sphere)
	mesh.compute_tangents(&sphere)
	plane := mesh.make_plane(1.4, 1)
	defer mesh.destroy(&plane)
	mesh.compute_tangents(&plane)

	f := fb.create(WIDTH, HEIGHT)
	defer fb.destroy(&f)

	// Factors of 1: the maps alone decide albedo, metallic and roughness.
	mapped := render.pbr_material(m.Vec3{1, 1, 1}, 1, 1)

	// --- 1. the maps themselves (MR split into its two channels for legibility) ---
	dump_texture(&panel.albedo, "map_albedo.png")
	dump_channel(&panel.mr, 1, "map_roughness.png") // G
	dump_channel(&panel.mr, 2, "map_metallic.png")  // B

	// --- 2. one sphere, one material, many surfaces ---
	// Sphere UVs wrap the whole circumference, so it gets a finer 8×8 tile set
	// and a frontal light that puts the highlight mid-sphere.
	panel8 := render.make_panel_maps(512, 8)
	defer render.panel_maps_destroy(&panel8)
	front := render.DirLight{dir = m.normalize(m.Vec3{-0.3, -0.4, -0.85}), color = {1, 1, 1}, intensity = 3.0}
	cam := render.Camera{
		eye = {0, 0, 3.0}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	sphere_ctx := render.ShadeCtx{
		model = .PBR, light = front, mat = mapped, eye = cam.eye, ambient = AMBIENT,
		tex = &panel8.albedo, mr_tex = &panel8.mr,
	}
	draw_sphere(&f, cam, &sphere, sphere_ctx, 0.5)
	if utils.write_png(&f, "material_sphere.png") { fmt.println("wrote material_sphere.png") }

	// --- 3. a tilted panel + normal map, lit so the mirror reflection hits the eye ---
	draw_panel_plane(&f, &plane, &panel, &bumps, mapped)
	if utils.write_png(&f, "material_plane.png") { fmt.println("wrote material_plane.png") }

	// --- live: the sphere turning under the light ---
	display := display_raylib_create(WIDTH, HEIGHT, "GamePBR")
	defer display.destroy(&display)
	frame := 0
	for !display.should_close(&display) {
		input := display.poll_input(&display)
		if input.quit { break }
		draw_sphere(&f, cam, &sphere, sphere_ctx, f32(frame) * 0.01)
		display.present(&display, &f)
		frame += 1
	}
}

draw_sphere :: proc(f: ^fb.Framebuffer, cam: render.Camera, sphere: ^mesh.Mesh, sh: render.ShadeCtx, angle: f32) {
	fb.clear(f, BG)
	fb.clear_depth(f, 1.0)
	model := m.mat4_rotate(m.Vec3{0, 1, 0}, angle) * m.mat4_rotate(m.Vec3{1, 0, 0}, 0.35)
	render.draw_mesh_lit(f, render.camera_view_proj(cam) * model, model, sphere, sh, WIDTH, HEIGHT)
}

// The plane lies back (normal tilted up toward the camera). The light is placed
// at the mirror direction of the view about the plane normal, so the specular
// highlight lands mid-panel and every tile's roughness is visible in its spread.
draw_panel_plane :: proc(f: ^fb.Framebuffer, plane: ^mesh.Mesh, panel: ^render.PanelMaps, bumps: ^render.Texture, mat: render.Material) {
	fb.clear(f, BG)
	fb.clear_depth(f, 1.0)
	cam := render.Camera{
		eye = {0, 1.7, 2.4}, target = {0, 0, 0}, up = {0, 1, 0},
		fov_y = 1.0472, aspect = f32(WIDTH) / f32(HEIGHT), near = 0.1, far = 100,
	}
	model := m.mat4_rotate(m.Vec3{1, 0, 0}, -1.1)
	N := m.normalize(m.normal_matrix(model) * m.Vec3{0, 0, 1})
	V := m.normalize(cam.eye)                // surface (origin) -> eye
	L := m.reflect(-V, N)                    // mirror of V about N
	light := render.DirLight{dir = -L, color = {1, 1, 1}, intensity = 3.0}
	sh := render.ShadeCtx{
		model = .PBR, light = light, mat = mat, eye = cam.eye, ambient = AMBIENT,
		tex = &panel.albedo, mr_tex = &panel.mr, nrm_tex = bumps,
	}
	render.draw_mesh_lit(f, render.camera_view_proj(cam) * model, model, plane, sh, WIDTH, HEIGHT)
}

// Write one channel (0=R, 1=G, 2=B) of a texture as a grayscale PNG.
dump_channel :: proc(t: ^render.Texture, ch: int, path: string) {
	tf := fb.create(t.width, t.height)
	defer fb.destroy(&tf)
	for p, i in t.pixels {
		v := ch == 0 ? p.r : (ch == 1 ? p.g : p.b)
		tf.pixels[i] = fb.Color{v, v, v, 255}
	}
	if utils.write_png(&tf, path) { fmt.println("wrote", path) }
}

// Write a texture to PNG by copying it into a same-sized framebuffer.
dump_texture :: proc(t: ^render.Texture, path: string) {
	tf := fb.create(t.width, t.height)
	defer fb.destroy(&tf)
	copy(tf.pixels, t.pixels)
	if utils.write_png(&tf, path) { fmt.println("wrote", path) }
}
