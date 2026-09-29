package fb

// Packed 8-bit RGBA pixel. Four bytes, no padding, so a []Color maps 1:1 onto
// an R8G8B8A8 GPU texture / image buffer with no conversion.
Color :: struct {
	r, g, b, a: u8,
}
