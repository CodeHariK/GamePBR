package main

import "fb"
import rl "vendor:raylib"

// raylib implementation of the Display seam. The only display file that imports
// raylib — keeping the dependency contained here.

Raylib_Display :: struct {
	texture: rl.Texture2D,
	width:   int,
	height:  int,
}

display_raylib_create :: proc(width, height: int, title: cstring) -> Display {
	rl.InitWindow(i32(width), i32(height), title)
	rl.SetTargetFPS(60)

	img := rl.GenImageColor(i32(width), i32(height), rl.BLACK)
	tex := rl.LoadTextureFromImage(img)
	rl.UnloadImage(img)

	backend := new(Raylib_Display)
	backend.texture = tex
	backend.width = width
	backend.height = height

	return Display{
		user_data    = backend,
		present      = raylib_present,
		poll_input   = raylib_poll_input,
		should_close = raylib_should_close,
		destroy      = raylib_destroy,
	}
}

raylib_present :: proc(d: ^Display, f: ^fb.Framebuffer) {
	backend := cast(^Raylib_Display)d.user_data
	rl.UpdateTexture(backend.texture, raw_data(f.pixels))

	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	rl.DrawTexture(backend.texture, 0, 0, rl.WHITE)
	rl.DrawFPS(10, 10)
	rl.EndDrawing()
}

raylib_poll_input :: proc(d: ^Display) -> Input {
	return Input{
		quit        = rl.IsKeyPressed(.ESCAPE),
		toggle_wire = rl.IsKeyPressed(.W),
	}
}

raylib_should_close :: proc(d: ^Display) -> bool {
	return rl.WindowShouldClose()
}

raylib_destroy :: proc(d: ^Display) {
	backend := cast(^Raylib_Display)d.user_data
	rl.UnloadTexture(backend.texture)
	rl.CloseWindow()
	free(backend)
}
