# GamePBR

Writing a **physically-based renderer from scratch in [Odin](https://odin-lang.org/)** — first on the CPU, then ported to WebGPU. A learn-in-public project: every milestone ships working code **and** a blog-style write-up.

The point isn't to build a fast renderer — it's to *understand* one. Each step is small, documented, and tagged so you can check out any milestone and read the matching post.

## Tutorial format: one tag per milestone

Every step is a commit tagged `step-NN`. To follow along:

```bash
git clone https://github.com/CodeHariK/GamePBR
cd GamePBR
git tag                 # list all milestones
git checkout step-00    # jump to a step's exact code
```

Read the matching post in [`docs/`](docs/) alongside the code. The full roadmap with checkboxes lives in [`TODO.md`](TODO.md).

## Milestones

| Tag | Step | Post |
|-----|------|------|
| `step-00` | Project setup & toolchain | [docs/00-setup.md](docs/00-setup.md) |
| `step-01` | Math foundations | [docs/01-math.md](docs/01-math.md) |
| `step-02` | Framebuffer & image output | [docs/02-framebuffer.md](docs/02-framebuffer.md) |
| `step-03` | Triangle rasterization | [docs/03-rasterization.md](docs/03-rasterization.md) |
| `step-04` | Depth buffer | [docs/04-depth-buffer.md](docs/04-depth-buffer.md) |
| `step-05` | Camera & MVP transforms | [docs/05-camera-mvp.md](docs/05-camera-mvp.md) |
| `step-06` | Mesh loading (OBJ) | [docs/06-mesh-obj.md](docs/06-mesh-obj.md) |
| `step-07` | Texture mapping | [docs/07-texturing.md](docs/07-texturing.md) |
| `step-08` | Normals & tangent space | [docs/08-normals-tangent.md](docs/08-normals-tangent.md) |
| `step-09` | Baseline lighting | [docs/09-baseline-lighting.md](docs/09-baseline-lighting.md) |
| `step-10` | PBR theory | [docs/10-pbr-theory.md](docs/10-pbr-theory.md) |
| `step-11` | Cook-Torrance direct lighting | [docs/11-cook-torrance.md](docs/11-cook-torrance.md) |
| `step-12` | Metallic-roughness workflow | [docs/12-metallic-roughness.md](docs/12-metallic-roughness.md) |
| `step-13` | Multiple & typed lights | [docs/13-lights.md](docs/13-lights.md) |
| `step-14` | Tonemapping & gamma | [docs/14-tonemapping.md](docs/14-tonemapping.md) |
| `step-15` | Diffuse IBL | [docs/15-ibl-diffuse.md](docs/15-ibl-diffuse.md) |
| `step-16` | Specular IBL | [docs/16-ibl-specular.md](docs/16-ibl-specular.md) |
| `step-17` | Performance pass | [docs/17-performance.md](docs/17-performance.md) |
| `step-18` | WebGPU port | [docs/18-webgpu-port.md](docs/18-webgpu-port.md) |

## Build & run

Requires the [Odin compiler](https://odin-lang.org/docs/install/) on your PATH. raylib ships with Odin (`vendor:raylib`), so there's nothing else to install.

```bash
make run       # debug build + run
make release   # optimized build
```

You should get an 800×600 window with a gradient (step 00's proof-of-life).

## Tech stack

- **Language:** Odin
- **Display (CPU phase):** raylib, kept behind a four-proc `Display` seam so it swaps cleanly for **GLFW + WebGPU** at step 18
- **Platform:** developed on macOS (Apple Silicon)

## Layout

```
src/      Odin source (one responsibility per file)
docs/     one blog post per milestone + img/
TODO.md   the roadmap
```
