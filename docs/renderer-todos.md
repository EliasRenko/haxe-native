# Renderer improvement TODO

Review scope: [Renderer](../src/Renderer.hx), its resource types and current
display-object, GUI and post-processing callers. This is a proposed backlog, not
implemented behavior. P0 items are correctness/lifecycle risks; P1 defines the
high-level API and its contracts; P2 covers extensions and optimization.

## P0 - Correctness and resource safety

- [ ] **Keep GL state and the cache consistent.** `uploadData`,
  `orphanAndUploadData` and program creation bind VAOs and finish with VAO 0,
  but `useProgram` may skip rebinding the previously cached program and VAO.
  Invalidate or restore all affected cached state; include VBO, EBO, stride and
  VAO ownership in the contract. Define how external raw GL calls invalidate
  renderer state. Test draw A, upload/create, draw A again, as well as changing
  stride and alternating programs and buffers.
  ([Renderer](../src/Renderer.hx#L264),
  [uploads](../src/Renderer.hx#L832))
- [ ] **Make empty clips actually clip everything.** `setScissor` disables
  clipping for empty or out-of-bounds rectangles, so a disjoint nested
  `pushScissor` can expose the whole target. Represent an enabled empty clip
  separately from no clip; restore it correctly on pop. Recompute or explicitly
  scope clips when the viewport/target changes. Test disjoint, zero-sized,
  offscreen and nested clips, pop, resize and framebuffer switches.
  ([Renderer](../src/Renderer.hx#L1065))
- [ ] **Fail shader creation explicitly.** Compilation/link failure currently
  returns an unregistered `ProgramInfo` with program 0, while callers can try
  to use it. Return a clear error with program name, stage and driver log; clean
  up partial resources and ensure registry and diagnostics stay consistent.
  Test vertex, fragment, link and VAO-creation failures.
  ([Renderer](../src/Renderer.hx#L328))
- [ ] **Make program, buffer and texture ownership safe.** Define one owner,
  idempotent disposal and invalid-use errors, including after renderer release.
  `ProgramInfo.release` changes handles to -1, but `disposeProgramInfo` checks
  only for zero; direct disposal also leaves the object registered. Textures
  expose mutable GL IDs, and recycled `SlotArray` IDs can make stale buffer or
  framebuffer IDs refer to new resources. Use validated handles or an
  equivalent lifetime mechanism; test double disposal, stale handles, deletion
  while bound, cross-renderer use and shutdown ordering.
  ([ProgramInfo](../src/ProgramInfo.hx#L35),
  [Renderer](../src/Renderer.hx#L778),
  [SlotArray](../src/ds/SlotArray.hx))
- [ ] **Validate texture uploads and pixel layout.** Check dimensions, bpp,
  allocation, byte length and any byte-view offset before creating a GL
  texture; clean up on failure. Set and restore appropriate unpack alignment
  for rows not divisible by four. Define channel/swizzle, color-space,
  filtering and alpha semantics, and report actual render-target format rather
  than guessing `bpp`. Test odd-width 1/2/3-channel images, RGBA, invalid data
  and resource cleanup.
  ([Renderer](../src/Renderer.hx#L893),
  [TextureData](../src/data/TextureData.hx))
- [ ] **Make framebuffer resize and attachment lifetime predictable.**
  Resize currently destroys old attachments before replacement succeeds; on
  failure it removes the framebuffer. Define transactional failure behavior,
  borrowed attachment invalidation and whether independently disposing an
  attached texture is allowed. Ensure live counters remain correct on failed
  creation/resize. Test failed and successful resize, stale attachments,
  completeness errors and disposal.
  ([Renderer](../src/Renderer.hx#L1166),
  [ScreenPass](../src/display/ScreenPass.hx#L67))
- [ ] **Validate uniform and vertex layouts instead of guessing.** Unsupported
  GL types currently default to `Float`; reflected array sizes are ignored,
  vector setters silently ignore short arrays and matrix setters index without
  length checks. Reject unsupported layouts/types with useful errors or
  implement them, including arrays and integer attribute binding where needed.
  Validate sampler type/target and available texture units; replace sampler
  ordering inferred from fragment-source text with an explicit stable mapping.
  Test invalid lengths/types, arrays, integer attributes, multiple samplers and
  optimized-out uniforms.
  ([Renderer](../src/Renderer.hx#L441),
  [uniform reflection](../src/Renderer.hx#L542),
  [AttributeFormat](../src/types/AttributeFormat.hx),
  [UniformFormat](../src/types/UniformFormat.hx))
- [ ] **Define correct clear and initial state.** `clearScreen` hardcodes the
  color and clears depth under current GL masks/scissor; cached state also
  assumes initial GL values. Establish state explicitly and make clear color,
  buffers and clipping/mask behavior deliberate. Test clearing after depth
  writes are disabled and while scissoring is active.
  ([Renderer](../src/Renderer.hx#L198),
  [clearScreen](../src/Renderer.hx#L1000))

## P1 - A usable high-level 2D API

- [ ] **Define the public drawing model before splitting the class.** Specify
  frame and render-target boundaries, coordinate origin, logical vs pixel
  units/HiDPI, transforms, layering/order, default depth and alpha behavior.
  Decide which operations belong on `Renderer` versus existing
  `DisplayObject`, `Image`, `TileManager` and GUI batches; avoid a competing
  scene graph. Preserve existing behavior during migration.
- [ ] **Offer concise immediate 2D drawing.** Design typed commands for
  rectangles, lines and textured quads/sprite regions, with position, size,
  color/tint, opacity, transform and blend options. A basic image or rectangle
  should not require callers to manage GL buffers, program indices or
  uniforms. Define ordering and batch-flush boundaries; demonstrate drawing a
  sprite and a clipped UI panel. Add paths, circles and text only after their
  tessellation/font ownership contracts are specified.
- [ ] **Provide scoped drawing state.** Add a clear transform, opacity, blend
  and clipping state model, with push/pop or equivalent scoped restoration and
  explicit behavior on exceptions and frame boundaries. Cover nested
  transforms/clips and render-target changes without leaking state between
  callers. Keep the existing `matrix` users working through an adapter or
  documented migration.
- [ ] **Make render targets convenient without removing advanced attachments.**
  Provide a simple color target, optional depth, size and texture access; offer
  a scoped target/pass operation that restores viewport and state even on
  failure. Specify nesting, resize, feedback-loop restrictions and attachment
  ownership; retain an explicit advanced path for existing post-processing.
- [ ] **Replace raw GL-facing public parameters with typed descriptions.**
  Use suitable drawing modes, blend modes, texture/filter options and resource
  handles; expose explicit advanced shader/mesh access as an escape hatch.
  Validate counts, offsets, buffer ownership and program/layout compatibility.
  Avoid forcing a breaking change on existing display and GUI consumers.
- [ ] **Clarify frame and lifecycle operations.** Rename or wrap `render()`
  according to its actual frame-begin/reset role; document initialization,
  active GL context/thread requirements, window resize/minimization, shutdown,
  and what happens after release or on context loss. Make invalid transitions
  explicit and test them.
  ([Renderer](../src/Renderer.hx#L218))
- [ ] **Centralize repeated low-level submission.** Existing
  [Image](../src/display/Image.hx#L86) and
  [ScreenPass](../src/display/ScreenPass.hx#L96) repeat program, buffer, blend,
  uniforms and draw steps. Provide one validated submission path and migrate
  current callers incrementally, including GUI and tile batches. Preserve custom
  shaders, render order and post-processing behavior.
- [ ] **Specify errors and documentation.** Replace inconsistent `trace`,
  silent no-ops, null returns and thrown strings with a consistent documented
  policy appropriate to the project. Document supported GL version/extensions,
  state ownership, lifetime rules, limits and examples for simple and advanced
  use. Identify intentional breaking changes and a migration path.
- [ ] **Add renderer regression tests.** Add focused native GL/context tests
  with deterministic pixel readback for clipping, blending, textures,
  transforms and render targets, plus failure/lifetime tests for the P0 cases.
  Include existing image, batch and post-processing flows; document how to run
  them and any graphics-driver requirements. Current native tests cover audio,
  not the renderer.

## P2 - Performance and extensibility

- [ ] **Fix streaming uploads and measure them.** `orphanAndUploadData`
  allocates `maxBufferSize` with null data, then `bufferFloatArray` calls
  `glBufferData` again with the actual size. Implement a coherent
  capacity/subdata or alternative streaming strategy, validate byte sizes and
  handle indices consistently. Benchmark against regular uploads before
  changing defaults.
  ([Renderer](../src/Renderer.hx#L853), [GL](../src/GL.hx#L135))
- [ ] **Batch compatible 2D draws without changing visual order.** Specify
  flushes for target, shader, texture capacity, clip, blend and transform
  changes; preserve transparency ordering. Measure draw calls, uploads and
  frame time on representative GUI/sprite/tile workloads before and after.
- [ ] **Make diagnostics trustworthy and useful.** Disabling diagnostics calls
  `beginFrame` after setting `enabled` false, so it does not clear frame
  counters. Triangle counts currently use `count / 3` for every draw mode;
  clarify metrics and resource-count units, and test enable/disable, frame
  resets, failure cleanup and non-triangle modes.
  ([RendererDiagnostics](../src/Renderer.hx#L84),
  [draw calls](../src/Renderer.hx#L306))
- [ ] **Separate responsibilities after contracts stabilize.** Extract
  cohesive internal program/reflection, resource/target and render-state
  components as needed, while keeping the public 2D entry point small.
  Avoid exposing raw internals or adding abstractions without a caller.
