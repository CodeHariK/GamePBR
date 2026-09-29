# GamePBR — Milestone TODO

A from-scratch **CPU PBR renderer in Odin**, later ported to **WebGPU**.
Learning project: every step ships working code **and** a blog-style write-up in `docs/`.

- **Language:** Odin (using its built-in vector/matrix types)
- **Path:** software rasterizer → physically-based shading → IBL → WebGPU
- **Rule per step:** small single-responsibility files, thorough docs, one blog `.md` before moving on

---

## Phase 0 — Foundations
- [ ] **00 — Project setup & toolchain** · window/framebuffer, main loop, write an image to disk → [docs/00-setup.md](docs/00-setup.md)
- [ ] **01 — Math foundations** · vectors, matrices, transforms, color helpers → [docs/01-math.md](docs/01-math.md)
- [ ] **02 — Framebuffer & image output** · pixel buffer, clear, PPM then PNG → [docs/02-framebuffer.md](docs/02-framebuffer.md)

## Phase 1 — The rasterizer
- [ ] **03 — Triangle rasterization** · edge functions, barycentric coords, fill → [docs/03-rasterization.md](docs/03-rasterization.md)
- [ ] **04 — Depth buffer** · z-buffer, correct occlusion → [docs/04-depth-buffer.md](docs/04-depth-buffer.md)
- [ ] **05 — Camera & MVP transforms** · model/view/projection, perspective divide → [docs/05-camera-mvp.md](docs/05-camera-mvp.md)
- [ ] **06 — Mesh loading (OBJ)** · parse OBJ, wireframe, then filled → [docs/06-mesh-obj.md](docs/06-mesh-obj.md)
- [ ] **07 — Texture mapping** · UVs, perspective-correct interpolation, sampling → [docs/07-texturing.md](docs/07-texturing.md)
- [ ] **08 — Normals & tangent space** · per-vertex normals, TBN, normal mapping → [docs/08-normals-tangent.md](docs/08-normals-tangent.md)

## Phase 2 — Lighting → PBR
- [ ] **09 — Baseline lighting** · Lambert diffuse + Blinn-Phong (the "before") → [docs/09-baseline-lighting.md](docs/09-baseline-lighting.md)
- [ ] **10 — PBR theory** · radiometry, the rendering equation, BRDF, energy conservation → [docs/10-pbr-theory.md](docs/10-pbr-theory.md)
- [ ] **11 — Cook-Torrance direct lighting** · GGX (D), Smith (G), Fresnel-Schlick (F) → [docs/11-cook-torrance.md](docs/11-cook-torrance.md)
- [ ] **12 — Metallic-roughness workflow** · albedo/metallic/roughness textures, F0 → [docs/12-metallic-roughness.md](docs/12-metallic-roughness.md)
- [ ] **13 — Multiple & typed lights** · point, directional, spot; attenuation → [docs/13-lights.md](docs/13-lights.md)
- [ ] **14 — Tonemapping & gamma** · HDR → LDR (ACES/Reinhard), sRGB correction → [docs/14-tonemapping.md](docs/14-tonemapping.md)

## Phase 3 — Image-based lighting
- [ ] **15 — Diffuse IBL** · equirectangular env map, irradiance convolution → [docs/15-ibl-diffuse.md](docs/15-ibl-diffuse.md)
- [ ] **16 — Specular IBL** · split-sum: prefiltered env map + BRDF LUT → [docs/16-ibl-specular.md](docs/16-ibl-specular.md)

## Phase 4 — Speed & the jump to GPU
- [ ] **17 — Performance pass** · multithreaded tiles, SIMD, profiling → [docs/17-performance.md](docs/17-performance.md)
- [ ] **18 — WebGPU port** · architecture bridge, first triangle, port the BRDF to WGSL → [docs/18-webgpu-port.md](docs/18-webgpu-port.md)

---

### Conventions
- One concept per file/function; keep files small and readable.
- Each blog doc: **What & why → Theory → Implementation → Results (image) → Gotchas → References → Next.**
- Commit the write-up in the same PR/commit as the step's code.
- Save reference output images under `docs/img/` so blog posts render.
