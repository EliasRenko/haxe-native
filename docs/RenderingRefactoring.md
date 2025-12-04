# Plan: Rendering Engine Architecture Refactoring

This plan addresses the critical performance and architecture issues identified in the review, focusing on fixing buffer management, VAO binding confusion, and class responsibilities while preserving the excellent shader introspection system.

## Steps

1. **Fix buffer upload performance catastrophe** - Add dirty tracking to `DisplayObject.hx` with `isDynamic:Bool` and `needsBufferUpdate:Bool` flags, then modify `Renderer.hx:renderDisplayObject()` to only call `updateBuffers()` when the flag is true, eliminating the 10-100x performance loss from rebuilding every buffer every frame.

2. **Resolve VAO binding path confusion** - Choose single code path in `Renderer.hx:renderDisplayObject()` based on `ProgramInfo.useModernBinding` flag, removing the redundant dual binding of both `GL.bindBuffer()` and `GL.bindVertexBuffer()`, and implement `ProgramInfo.setupVertexAttributes()` call for legacy path.

3. **Move shader compilation into `ProgramInfo`** - Relocate `Renderer.compileProgramInfo()`, `checkShaderCompilation()`, and `checkProgramLinking()` methods (lines 560-640) into `ProgramInfo.hx` as private methods, breaking the circular dependency and allowing `ProgramInfo` to be self-contained.

4. **Fix `currentProgram` state tracking** - Remove `currentProgram = -1` reset in `Renderer.render()` and initialize to `0` instead of `-1` to preserve state tracking optimization across frames.

5. **Split `Renderer` responsibilities** - Extract buffer management methods (`createBuffers`, `uploadData`, `orphanAndUploadData`, etc.) into new `BufferManager.hx` class, keeping `Renderer` focused on high-level draw coordination and state management.

6. **Add uniform dirty tracking** - Implement dirty flags in `DisplayObject` for transform matrix and other uniforms to avoid uploading identical data every frame, particularly for the expensive `uMatrix` uniform.

## Steps (continued)

7. **Remove transform properties from DisplayObject** - Extract x, y, z, rotationX/Y/Z, scaleX/Y/Z, and `updateTransform()` method from `DisplayObject.hx`. Transform matrices should be passed to `render(viewProjectionMatrix:Matrix)` from the calling system (ECS entities in haxe-application). DisplayObject becomes pure rendering:
   - Remove: position, rotation, scale fields and `updateTransform()` method
   - Keep: vertices, indices, textures, uniforms, vbo, ebo, programInfo
   - Modify `render()` to accept final transform matrix as parameter instead of computing it
   - Benefits: geometry sharing, simpler abstraction, easier batching/instancing
   - **Rationale:** haxe-application already has ECS scene graph; haxe-native should just draw what it's told

## Further Considerations

1. **Buffer orphaning strategy documentation** - Need clear guidelines on when to use `uploadData()` vs `orphanAndUploadData()` vs `allocateTileBatchBuffers()`, and whether to standardize on one approach or keep all three options available.

2. **VAO unbinding removal** - Should we eliminate the `GL.bindVertexArray(0)` calls after every draw for minor performance gain, or keep them for debugging safety? Modern consensus is they're unnecessary but some prefer explicit cleanup.

3. **Matrix uniform handling** - After removing transforms, should `DisplayObject.render()` automatically set `uMatrix` uniform, or should calling code set it explicitly? Current code sets it in render(), but pure rendering layer might leave this to the caller.
