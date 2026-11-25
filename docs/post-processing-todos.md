# Post-processing improvement TODO

Review scope: [PostProcessing](../src/display/PostProcessing.hx),
[ScreenPass](../src/display/ScreenPass.hx), the built-in screen passes and
[App rendering](../../haxe-application/src/App.hx#L210).

## P0 - API correctness and lifecycle

- [x] Make `PostProcessing` own no hardcoded effects. Its constructor should
  not instantiate `ScanlineScreenPass`, `GrayscaleScreenPass` and
  `DepthVisualizationScreenPass` implicitly. Define default registration
  elsewhere or provide a small opt-in preset. The library should allow a
  project to start with an empty pipeline.
- [ ] Separate a post-processing pass from a frame render target. A pass is
  currently also a target, display object, shader owner and selector item.
  Split the responsibilities so that scene capture, effect passes and final
  presentation have clear contracts.
- [ ] Define and enforce pass identity/lifetime. Add stable ids or names,
  idempotent `add`, `remove` and `dispose`, stale-index protection, and
  reference-safe selection. `release` should mark the manager unusable or
  support explicit reuse consistently.
- [x] Remove null or invalid-active behavior. `activePass` currently returns
  `null` for an empty pipeline and `App` dereferences it whenever
  `enabled` is true. Define whether empty means disabled, throw with a clear
  lifecycle error, or fall back to direct rendering.
- [x] Scope enabled and render-state behavior. `enabled` should decide the
  complete pipeline path: direct render when disabled, source capture plus
  effects when enabled. Disabled rendering must not leave stale scissor,
  viewport, framebuffer or blend state.
- [x] Fix the render-target assumptions in `ScreenPass`. It always assigns
  `uScreenTexture` from `GL.COLOR_ATTACHMENT0`, even when a custom pass may
  not have that attachment or may need an explicitly supplied source texture.
  Replace this with source texture declarations or pass inputs.
- [x] Make rendering transactional. Binding a framebuffer, clearing, rendering
  the scene and unbinding are currently spread through `App`. If scene
  rendering throws or a pass fails, ensure the renderer is restored to the
  default framebuffer and previous state. Do not leave nested or active
  framebuffers bound.
- [x] Validate resize and resource ownership. Re-resize, resize after release,
  dispose while active, and resize an active target should have documented
  behavior. Ensure every pass refreshes textures and uniforms that point to
  recreated framebuffer attachments.
- [x] Add a complete cleanup contract. Passes are disposed and their display
  object buffers released in `PostProcessing`; custom pass implementations
  need one idempotent `dispose`, not separate `dispose` plus `release` calls.

## P1 - Easy extension and clean pipeline API

- [ ] Introduce a small pass interface or base contract. A pass should declare
  name, input requirements, output contract and lifecycle hooks; it should not
  require copying `ScreenPass` boilerplate for a simple shader effect.
- [ ] Provide an easy single-effect API. Example goals:
  `addEffect(new GrayscaleEffect())`,
  `addEffect("grayscale", shader, uniforms)`, or
  `addEffect(new GrayscaleEffect())` using a typed preset. Adding/removing,
  enabling and selecting one pass should not require constructing or resizing
  a framebuffer object manually.
- [ ] Support named effects and stable selection. Replace index-only cycling
  with names or ids, `setActive("grayscale")`, `next`, `previous`, and
  `activeName`. Cycling over an empty or disabled pipeline should be
  harmless or documented.
- [ ] Support a real effect chain. The current model is selector-only: exactly
  one pass is chosen and it receives the captured scene. Add an ordered chain
  of passes, ping-pong textures/framebuffers, intermediate passes and an
  explicit final screen pass.
- [ ] Separate input and output resources. Define typed inputs such as
  sceneColor, sceneDepth, previousColor, resolution and time. Built-in passes
  should declare attachments/uniforms instead of rebuilding them in
  constructors and custom classes.
- [ ] Add scoped uniform configuration. Provide typed or fluent setup for
  parameters, including changed detection, rather than exposing raw
  `shader.setUniform("name", value)` everywhere. Define Haxe type behavior for
  floats, vectors, matrices, textures and arrays.
- [ ] Encapsulate the frame workflow in `PostProcessing`. The API could expose
  `begin(renderer)`, `renderScene(renderer, callback)`, `present(renderer)`,
  or one `render(renderer, sceneCallback)` method. `App` should only provide
  the scene callback and run policy, not manually implement pipeline steps.
- [ ] Define pass presets as composition, not subclasses. Scanlines, grayscale
  and depth visualization should be simple pass configurations or effects,
  while custom users can compose shader sources and inputs. Preserve advanced
  framebuffer access for custom passes.
- [ ] Add a one-off pass factory for new effects. It should accept a shader,
  size policy and input/output attachments; it should create buffers,
  resources and uniform source mappings automatically, and provide lifecycle
  cleanup.
- [ ] Standardize viewport and coordinates. Document logical size vs backing
  pixel size, `TexCoord` origin, HiDPI behavior and size uniforms. Built-in
  shaders should receive resolution consistently rather than hardcoding
  scanline frequency as a view-height-dependent constant.
- [ ] Remove obsolete spelling and boilerplate. Rename
  `PostProccessingShader` to `PostProcessingShader`, and reduce duplicated full-screen
  vertex shaders across built-in passes by sharing a full-screen quad shader or
  pass template.
- [ ] Let users choose pipeline modules. Add easy enable/disable, module
  enablement and ordering for each effect; support both mutually exclusive
  previews (current behavior) and composable chains.

## P2 - Resource management and performance

- [ ] Pool render targets. Add reusable ping-pong targets sized for viewport
  changes, release only when no longer referenced, and avoid allocating a
  separate framebuffer for every pass if effects share a chain.
- [ ] Use a target allocator with format policies. Expose color/internal format,
  depth policy, MSAA policy and mipmap policy, while providing RGBA8 plus
  optional depth as defaults. Validate format/size compatibility.
- [ ] Add chain-wide resize. Resize once in `PostProcessing`, then propagate
  new dimensions to all targets and effects without allocating each pass
  independently.
- [ ] Eliminate unnecessary targets. Scanline and grayscale are currently
  scene-capture targets and do not need depth; depth visualization needs both
  color and depth. Add an effect-only mode that renders directly over the
  final target without a redundant intermediate framebuffer.
- [ ] Cache full-screen geometry and bindings. Share or pool the quad geometry,
  VAO and program resources; flush programs/buffers once per pass where
  compatible. Do not implement batching that changes effect ordering.
- [ ] Add diagnostics. Report active pass, pass count, target count, target
  size/format, framebuffer status, draw calls, texture uploads, chained pass
  count and resizing counts.
- [ ] Add tests. Use a graphics-backed test harness or deterministic mocks to
  cover empty pipeline, direct rendering, one pass, multi-pass chains,
  ping-pong correctness, resize, add/remove, stale selection, release,
  exception cleanup and depth/color attachment refresh.
