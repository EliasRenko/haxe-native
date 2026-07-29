# Renderer Optimization TODOs

This note collects the rendering improvements discussed for the current renderer pipeline.

## High-priority items

- [ ] Stop using transform updates as a trigger for buffer re-uploading.
  - Transform changes should not force vertex buffer uploads unless the vertex/index data actually changed.
- [ ] Cache GL state in the renderer to reduce redundant bindings.
  - Track current program, VAO, array buffer, element buffer, blend state, and texture bindings.
- [ ] Avoid rebinding unchanged buffers and textures per draw call.
  - Only bind state when it changes from the previous draw.
- [ ] Move blend-state setup out of the texture loop.
  - Apply blending once per draw rather than inside texture iteration.

## Medium-priority items

- [ ] Add lightweight uniform-change caching.
  - Skip sending uniforms to the GPU when the value has not changed.
- [ ] Review VAO cache behavior for per-(program, vbo) combinations.
  - Ensure cached VAOs are reused correctly and invalidated when needed.
- [ ] Consider batching draw calls for objects sharing the same material/program.
  - This can reduce state switching overhead.

## Later / broader ideas

- [ ] Profile the renderer to measure where time is actually spent.
- [ ] Explore instancing or batched rendering for repeated sprite/tile-like objects.
- [ ] Review matrix generation and uniform upload frequency for hot paths.
