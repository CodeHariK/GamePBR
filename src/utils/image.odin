package utils

import "core:fmt"
import "core:os"
import "core:strings"
import "../fb"
import rl "vendor:raylib"

// Writing a framebuffer to disk.
//   - PPM (P6): hand-rolled, no library — the simplest image file there is.
//   - PNG: via raylib's exporter. raylib already bundles stb_image_write, so we
//     do NOT also link vendor:stb/image (that duplicates the C symbols at link
//     time). Both formats use a top-left origin, matching the framebuffer.

write_ppm :: proc(f: ^fb.Framebuffer, path: string) -> bool {
	header := fmt.tprintf("P6\n%d %d\n255\n", f.width, f.height)

	buf := make([]u8, len(header) + f.width * f.height * 3)
	defer delete(buf)

	copy(buf[:], header)
	o := len(header)
	for p in f.pixels {
		buf[o + 0] = p.r
		buf[o + 1] = p.g
		buf[o + 2] = p.b
		o += 3
	}
	return os.write_entire_file(path, buf) == nil
}

write_png :: proc(f: ^fb.Framebuffer, path: string) -> bool {
	cpath := strings.clone_to_cstring(path)
	defer delete(cpath)

	img := rl.Image{
		data    = raw_data(f.pixels),
		width   = i32(f.width),
		height  = i32(f.height),
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	return rl.ExportImage(img, cpath)
}
