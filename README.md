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

## References

- https://www.songho.ca/opengl/gl_projectionmatrix.html

- [Lecture 07: Perspective Projection and Texture Mapping (CMU 15-462/662)](https://www.youtube.com/watch?v=_4Q4O2Kgdo4&list=PL9_jI1bdZmz2emSh0UQ5iOdT2xRHFHL7E&index=8)
- [Intro to Graphics 06 - 3D Transformations](https://www.youtube.com/watch?v=1z1S2kQKXDs&list=PLplnkTzzqsZTfYh4UbhLGpI5kGd5oW_Hh&index=7)
- [Quick Understanding of Homogeneous Coordinates for Computer Graphics](https://www.youtube.com/watch?v=o-xwmTODTUI)
- [The Math behind (most) 3D games - Perspective Projection](https://www.youtube.com/watch?v=U0_ONQQ5ZNM)
- [Perspective projection in 5 minutes](https://www.youtube.com/watch?v=F5WA26W4JaM&list=PLWfDJ5nla8UpwShx-lzLJqcp575fKpsSO&index=12)
- [How do Video Game Graphics Work?](https://www.youtube.com/watch?v=C8YtdC8mxTU)
- [How LookAt Camera Really Works (Math Explained)](https://www.youtube.com/watch?v=kEojgGHnoi4)
- [GSN Composer : Normal Mapping and Tangent Space (MikkTSpace) [Shaders Monthly #15]](https://www.youtube.com/watch?v=uqUNsQLKScs&list=PL8vNj3osX2PzZ-cNSqhA8G6C1-Li5-Ck8&index=16)
- [Interactive Graphics 19 - Bump, Normal, Displacement, and Parallax Mapping](https://www.youtube.com/watch?v=cM7RjEtZGHw)
- [View, World, Object, & Tangent Space - Shader Graph Basics - Episode 10](https://www.youtube.com/watch?v=E6Srr-HaicI)
- [Explaining my game engine in 2024 - Part1: Triangle mesh tangent space, normal map identification](https://www.youtube.com/watch?v=AqRkwN3MxUI)

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
