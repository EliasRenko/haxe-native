package web;

#if js
import web.GL;
import web.ProgramInfo;
import web.ProgramInfo.AttributeFormat;
import DisplayObject;
import Framebuffer;
import data.TextureData;
import Texture;
import math.Matrix;
import js.lib.Float32Array;
import js.lib.Uint32Array;
import js.lib.Uint8Array;

/**
 * WebGL2 renderer — mirrors the public API of the native Renderer class.
 *
 * Key differences from native:
 *  - Uses web.GL wrapper (no cpp.* types, no untyped __cpp__).
 *  - Per-(programId, vboId) VAO cache because WebGL2 VAOs capture buffer
 *    bindings (unlike OpenGL 4.3 ARB_vertex_attrib_binding).
 *  - Buffer creation uses GL.createBuffer() directly (not genBuffers pointer).
 *  - Texture upload uses Uint8Array instead of raw pointer.
 *  - orphanAndUpload uses bufferData with null then bufferSubData.
 */
class Renderer {

    // Publics
    public var app(get, null):App;

    // Render state tracking
    private var __currentDepthTest:Bool  = true;
    private var __currentDepthWrite:Bool = true;
    private var __currentBlendMode:Bool  = false;
    private var __app:App;
    private var frameCount:Int = 0;
    private var programInfos:Map<String, ProgramInfo> = new Map();

    // Framebuffer for post-processing
	public var framebuffer:Framebuffer = null;
	public var postProcessShader:ProgramInfo = null;
	public var usePostProcessing:Bool = false;

    private var __fullscreenQuadVAO:Int = 0;
	private var __fullscreenQuadVBO:Int = 0;
	private var currentProgram:Int = -1;

    // ** Per-(programId, vboId) VAO cache
    // WebGL2 VAOs store buffer bindings, so we can't share one VAO across
    // multiple DisplayObjects with different VBOs.
    private var __vaoCache:Map<String, Int> = new Map();

    public function new(app:App) {
        __app = app;
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(true);
    }

    // -------------------------------------------------------------------------
    // Frame entry point
    // -------------------------------------------------------------------------

    public function render():Void {
        currentProgram = -1;
        frameCount++;
    }

    // -------------------------------------------------------------------------
    // Display object rendering
    // -------------------------------------------------------------------------

    public function renderDisplayObject(displayObject:DisplayObject, viewProjectionMatrix:Matrix, cameraDirty:Bool):Void {
        if (!displayObject.visible) return;
        if (displayObject.programInfo == null) return;

        if (displayObject.needsBufferUpdate) {
            displayObject.updateBuffers(this);
        }

        if (displayObject.vertices.length == 0) return;

        displayObject.render(viewProjectionMatrix, cameraDirty);

        // Use the program
        if (displayObject.programInfo.program != currentProgram) {
            GL.useProgram(displayObject.programInfo.program);
            currentProgram = displayObject.programInfo.program;
        }

        // Bind the per-(program, vbo) VAO
        var vao = __getOrCreateVAO(displayObject.programInfo, displayObject.vbo);
        GL.bindVertexArray(vao);

        // Bind VBO (needed for drawElements / data upload)
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);

        // Bind EBO if present
        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
        }

        // Set uniforms and textures
        __renderUniforms(displayObject.programInfo, displayObject.uniforms);
        __renderTextures(displayObject.programInfo, displayObject);

        // Draw
        if (displayObject.__indicesToRender == 0) {
            GL.drawArrays(displayObject.mode, 0, displayObject.__verticesToRender);
        } else {
            GL.drawElements(displayObject.mode, displayObject.__indicesToRender, GL.UNSIGNED_INT, 0);
        }

        displayObject.postRender();
        GL.bindVertexArray(0);
    }

    // -------------------------------------------------------------------------
    // VAO cache — creates a VAO that captures the attribute layout for a given
    // (programInfo, vbo) combination and stores it for reuse.
    // -------------------------------------------------------------------------

    private function __getOrCreateVAO(programInfo:ProgramInfo, vbo:Int):Int {
        var key = programInfo.programId + "_" + vbo;
        if (__vaoCache.exists(key)) return __vaoCache.get(key);

        var vao = GL.createVertexArray();
        GL.bindVertexArray(vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, vbo);

        for (attr in programInfo.attributes) {
            GL.enableVertexAttribArray(attr.location);
            GL.vertexAttribPointer(attr.location, attr.size, __glFormat(attr.format), false, attr.stride, attr.offset);
        }

        GL.bindVertexArray(0);
        GL.bindBuffer(GL.ARRAY_BUFFER, 0);

        __vaoCache.set(key, vao);
        return vao;
    }

    private function __glFormat(format:AttributeFormat):Int {
        return switch (format) {
            case Float | Vec2 | Vec3 | Vec4: 5126; // GL_FLOAT
            case Int:          5124;
            case UnsignedInt:  5125;
            case Byte:         5120;
            case UnsignedByte: 5121;
            case Short:        5122;
            case UnsignedShort:5123;
        };
    }

    // -------------------------------------------------------------------------
    // Uniforms and textures
    // -------------------------------------------------------------------------

    private function __renderUniforms(programInfo:ProgramInfo, uniforms:Map<String, Dynamic>):Void {
        for (name => value in uniforms) {
            var uniformInfo = programInfo.getUniform(name);
            if (uniformInfo == null) {
                trace("Warning: Uniform '" + name + "' not found in shader");
                continue;
            }
            uniformInfo.setter(value);
        }
    }

    private function __renderTextures(programInfo:ProgramInfo, drawable:DisplayObject):Void {
        for (i in 0...programInfo.textures.length) {
            GL.activeTexture(GL.TEXTURE0 + i);

            if (i < drawable.textures.length) {
                var texture = drawable.textures[i];
                var textureId = texture != null ? texture.id : 0;
                GL.bindTexture(GL.TEXTURE_2D, textureId);
            }

            GL.blendFunc(drawable.blendFactors.source, drawable.blendFactors.destination);
            programInfo.textures[i].setter(i);
        }
    }

    // -------------------------------------------------------------------------
    // ProgramInfo management
    // -------------------------------------------------------------------------

    public function createProgramInfo(name:String, vertexShader:String, fragmentShader:String):ProgramInfo {
        if (programInfos.exists(name)) return programInfos.get(name);
        var programInfo = new ProgramInfo(name, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);
        return programInfo;
    }

    public function getProgramInfo(name:String):ProgramInfo {
        if (!programInfos.exists(name)) {
            trace("Error: ProgramInfo '" + name + "' not found!");
            return null;
        }
        return programInfos.get(name);
    }

    public function hasProgramInfo(name:String):Bool {
        return programInfos.exists(name);
    }

    public function createProgramInfoFromFiles(name:String, ?vertexShaderPath:String, fragmentShaderPath:String):ProgramInfo {
        if (programInfos.exists(name)) {
            trace("ProgramInfo '" + name + "' already exists, reusing...");
            return programInfos.get(name);
        }

        var vertexShader:String = null;
        if (vertexShaderPath != null) {
            vertexShader = app.resources.getText(vertexShaderPath);
            if (vertexShader == null) {
                trace("Error: Vertex shader '" + vertexShaderPath + "' not found in preloaded resources!");
                return null;
            }
        }

        var fragmentShader = app.resources.getText(fragmentShaderPath);
        if (fragmentShader == null) {
            trace("Error: Fragment shader '" + fragmentShaderPath + "' not found in preloaded resources!");
            return null;
        }

        var programInfo = new ProgramInfo(name, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);
        trace("Created ProgramInfo '" + name + "' from files: " + vertexShaderPath + ", " + fragmentShaderPath);
        return programInfo;
    }

    public function getProgramInfoNames():Array<String> {
        return [for (k in programInfos.keys()) k];
    }

    // -------------------------------------------------------------------------
    // Buffer management
    // -------------------------------------------------------------------------

    public function createBuffers():{ vbo:Int, ebo:Int } {
        return { vbo: GL.createBuffer(), ebo: GL.createBuffer() };
    }

    public function uploadData(displayObject:DisplayObject):Void {
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, displayObject.vertices, GL.DYNAMIC_DRAW, displayObject.vertices.length);

        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.DYNAMIC_DRAW, displayObject.indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
    }

    public function orphanAndUploadData(displayObject:DisplayObject, maxBufferSize:Int):Void {
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        // Orphan: allocate new storage, discarding old
        GL.context.bufferData(GL.ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, displayObject.vertices, GL.STREAM_DRAW, displayObject.vertices.length);

        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.context.bufferData(GL.ELEMENT_ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.STREAM_DRAW, displayObject.indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
    }

    public function allocateTileBatchBuffers(displayObject:DisplayObject, maxTiles:Int):Void {
        var vertexBufferSize = maxTiles * 4 * 5 * 4; // tiles × 4 verts × 5 floats × 4 bytes

        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        GL.context.bufferData(GL.ARRAY_BUFFER, vertexBufferSize, GL.STREAM_DRAW);

        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.STATIC_DRAW, displayObject.indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
    }

    public function orphanAndUploadTileBatch(displayObject:DisplayObject):Void {
        if (displayObject.vertices.length == 0) return;

        var vertexBufferSize = 1000 * 4 * 5 * 4; // MAX_TILES × 4 verts × 5 floats × 4 bytes

        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        GL.context.bufferData(GL.ARRAY_BUFFER, vertexBufferSize, GL.DYNAMIC_DRAW);

        var floatArray:Array<Float> = cast displayObject.vertices.data;
        GL.bufferSubFloatArray(GL.ARRAY_BUFFER, 0, floatArray, floatArray.length);

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
    }

    public function deleteBuffers(vbo:Int, ebo:Int):Void {
        GL.deleteBuffers(1, vbo);
        GL.deleteBuffers(1, ebo);
    }

    // -------------------------------------------------------------------------
    // Screen and render state
    // -------------------------------------------------------------------------

    public function clearScreen():Void {
        GL.glClearColor(0.1, 0.1, 0.15, 1.0);
        GL.glClear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    }

    public function initializeRenderState():Void {
        GL.glDisable(GL.CULL_FACE);
    }

    public function setDepthTest(enabled:Bool):Void {
        if (__currentDepthTest != enabled) {
            if (enabled) GL.glEnable(GL.DEPTH_TEST) else GL.glDisable(GL.DEPTH_TEST);
            __currentDepthTest = enabled;
        }
    }

    public function setDepthWrite(enabled:Bool):Void {
        if (__currentDepthWrite != enabled) {
            GL.context.depthMask(enabled);
            __currentDepthWrite = enabled;
        }
    }

    public function setBlendMode(enabled:Bool):Void {
        if (__currentBlendMode != enabled) {
            if (enabled) {
                GL.glEnable(GL.BLEND);
                GL.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
            } else {
                GL.glDisable(GL.BLEND);
            }
            __currentBlendMode = enabled;
        }
    }

    // -------------------------------------------------------------------------
    // Texture upload
    // -------------------------------------------------------------------------

    public function uploadTexture(textureData:TextureData):Texture {
        if (textureData == null) {
            trace("Error: Cannot upload null texture data");
            return null;
        }

        var textureId = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, textureId);

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);

        var format:Int;
        var internalFormat:Int;

        switch (textureData.bytesPerPixel) {
            case 1: format = GL.RED;  internalFormat = GL.R8;
            case 2: format = GL.RG;   internalFormat = GL.RG8;
            case 3: format = GL.RGB;  internalFormat = GL.RGB8;
            case 4: format = GL.RGBA; internalFormat = GL.RGBA8;
            default: throw "Unsupported texture format: " + textureData.bytesPerPixel + " bpp";
        }

        var pixelData = new Uint8Array(textureData.bytes.getData());
        GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, textureData.width, textureData.height, 0, format, GL.UNSIGNED_BYTE, pixelData);
        GL.bindTexture(GL.TEXTURE_2D, 0);

        return {
            id:     textureId,
            width:  textureData.width,
            height: textureData.height,
            bpp:    textureData.bytesPerPixel,
            target: GL.TEXTURE_2D,
            src:    textureData.src
        };
    }

    public function createRenderTargetTexture(width:Int, height:Int, internalFormat:Int, format:Int, type:Int):Texture {
        var textureId = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, textureId);

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);

        GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, width, height, 0, format, type, null);
        GL.bindTexture(GL.TEXTURE_2D, 0);

        return {
            id:     textureId,
            width:  width,
            height: height,
            bpp:    (format == GL.RGBA ? 4 : 1),
            target: GL.TEXTURE_2D,
            src:    ""
        };
    }

    // -------------------------------------------------------------------------
    // Post-processing framebuffer
    // -------------------------------------------------------------------------

    public function initializePostProcessing():Void {
        var size = __app.window.getWindowSizeInPixels();
        framebuffer = new Framebuffer(size.width, size.height, false, true);
        framebuffer.initialize(this);
        createFullscreenQuad();

        var vertShader = '
            #version 300 es
            precision mediump float;
            layout (location = 0) in vec2 aPos;
            layout (location = 1) in vec2 aTexCoord;
            out vec2 TexCoord;
            void main() {
                gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
                TexCoord = aTexCoord;
            }
        ';

        var fragShader = '
            #version 300 es
            precision mediump float;
            in vec2 TexCoord;
            out vec4 FragColor;
            uniform sampler2D uScreenTexture;
            void main() {
                FragColor = texture(uScreenTexture, TexCoord);
            }
        ';

        postProcessShader = createProgramInfo("PostProcess", vertShader, fragShader);
        trace("Renderer: Post-processing initialized");
    }

    private function createFullscreenQuad():Void {
        var quadVertices:Array<Float> = [
            -1.0,  1.0,  0.0, 1.0,
            -1.0, -1.0,  0.0, 0.0,
             1.0, -1.0,  1.0, 0.0,
             1.0,  1.0,  1.0, 1.0
        ];
        var quadIndices:Array<UInt> = [0, 1, 2, 0, 2, 3];

        __fullscreenQuadVAO = GL.createVertexArray();
        GL.bindVertexArray(__fullscreenQuadVAO);

        __fullscreenQuadVBO = GL.createBuffer();
        GL.bindBuffer(GL.ARRAY_BUFFER, __fullscreenQuadVBO);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, quadVertices, GL.STATIC_DRAW, quadVertices.length);

        var ebo = GL.createBuffer();
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
        GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, quadIndices, GL.STATIC_DRAW, quadIndices.length);

        // aPos (location 0): 2 floats, stride = 4 floats * 4 bytes = 16
        GL.context.vertexAttribPointer(0, 2, GL.FLOAT, false, 16, 0);
        GL.context.enableVertexAttribArray(0);
        // aTexCoord (location 1): 2 floats, offset = 8 bytes
        GL.context.vertexAttribPointer(1, 2, GL.FLOAT, false, 16, 8);
        GL.context.enableVertexAttribArray(1);

        GL.bindVertexArray(0);
        trace("Renderer: Created fullscreen quad");
    }

    public function bindFramebuffer():Void {
        if (framebuffer != null) framebuffer.bind();
    }

    public function unbindFramebuffer():Void {
        if (framebuffer != null) framebuffer.unbind();
        var size = __app.window.getWindowSizeInPixels();
        GL.viewport(0, 0, size.width, size.height);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return; // Ignore degenerate resize (e.g. canvas inside display:none)
        GL.viewport(0, 0, width, height);
        if (framebuffer != null) framebuffer.resize(this, width, height);
    }

    public function renderToScreen():Void {
        if (framebuffer == null || postProcessShader == null) {
            trace("Warning: Post-processing not initialized");
            return;
        }
        GL.useProgram(postProcessShader.program);
        framebuffer.bindColorTexture(0);
        var uniformInfo = postProcessShader.getUniform("uScreenTexture");
        if (uniformInfo != null) uniformInfo.setter(0);
        GL.bindVertexArray(__fullscreenQuadVAO);
        GL.drawElements(GL.TRIANGLES, 6, GL.UNSIGNED_INT, 0);
        GL.bindVertexArray(0);
    }

    // -------------------------------------------------------------------------
    // Cleanup
    // -------------------------------------------------------------------------

    public function release():Void {
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);

        if (framebuffer != null) {
            framebuffer.dispose();
            framebuffer = null;
        }

        // Destroy cached VAOs
        for (vao in __vaoCache) {
            GL.deleteVertexArray(vao);
        }
        __vaoCache.clear();

        for (name in programInfos.keys()) {
            var pi = programInfos.get(name);
            if (pi != null) {
                pi.dispose();
                trace("Disposed ProgramInfo: " + name);
            }
        }
        programInfos.clear();
        trace("Renderer cleanup complete");
    }

    // -------------------------------------------------------------------------
    // Getters
    // -------------------------------------------------------------------------

    private function get_app():App { return __app; }
}
#end
