package web;

#if js
import web.GL;
import web.ProgramInfo;
import web.ProgramInfo.AttributeFormat;
import DisplayObject;
import data.Shader;
import Log;
import data.TextureData;
import Texture;
import math.Matrix;
import js.lib.Float32Array;
import js.lib.Uint32Array;
import js.lib.Uint8Array;

private typedef FramebufferTextureConfig = {
    final attachment:Int;
    final internalFormat:Int;
    final format:Int;
    final type:Int;
}

private typedef FramebufferTextureAttachment = {
    final attachment:Int;
    final texture:Texture;
}

private class Framebuffer {
    public var fbo:Int = 0;
    public var textureConfigs:Array<FramebufferTextureConfig>;
    public var textures:Array<FramebufferTextureAttachment> = [];
    public var depthRenderbuffer:Int = 0;
    public var width:Int;
    public var height:Int;
    public var hasDepthRenderbuffer:Bool;

	public function new(width:Int, height:Int, textureConfigs:Array<FramebufferTextureConfig>, useDepthRenderbuffer:Bool) {
		this.width = width;
		this.height = height;
		this.textureConfigs = textureConfigs;
		this.hasDepthRenderbuffer = useDepthRenderbuffer;
	}
}

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

    private var __framebuffers:Map<Int, Framebuffer> = new Map();
    private var __framebufferStack:Array<Int> = [];
    private var __nextFramebufferId:Int = 0;
    private var __postProcessFramebufferId:Int = -1;
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
            displayObject.programInfo.initializeSamplerUnits();
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
        renderUniforms(displayObject.programInfo, displayObject.shader);

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

    public function renderUniforms(programInfo:ProgramInfo, shader:Null<Shader>):Void {
        if (shader == null) return;

        for (uniform in shader.getUniforms()) {
            var uniformInfo = programInfo.getUniformAt(uniform.nameId);
            if (uniformInfo == null) {
                __app.log.warn(LogCategory.RENDERER, "Uniform '" + uniform.name + "' not found in shader");
                continue;
            }

            uniformInfo.setter(uniform.value);
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
            __app.log.error(LogCategory.RENDERER, "ProgramInfo '" + name + "' not found");
            return null;
        }
        return programInfos.get(name);
    }

    public function hasProgramInfo(name:String):Bool {
        return programInfos.exists(name);
    }

    public function createProgramInfoFromFiles(name:String, ?vertexShaderPath:String, fragmentShaderPath:String):ProgramInfo {
        if (programInfos.exists(name)) {
            __app.log.debug(LogCategory.RENDERER, "ProgramInfo '" + name + "' already exists, reusing");
            return programInfos.get(name);
        }

        var vertexShader:String = null;
        if (vertexShaderPath != null) {
            vertexShader = app.resources.getText(vertexShaderPath);
            if (vertexShader == null) {
                __app.log.error(LogCategory.RENDERER, "Vertex shader '" + vertexShaderPath + "' not found in preloaded resources");
                return null;
            }
        }

        var fragmentShader = app.resources.getText(fragmentShaderPath);
        if (fragmentShader == null) {
            __app.log.error(LogCategory.RENDERER, "Fragment shader '" + fragmentShaderPath + "' not found in preloaded resources");
            return null;
        }

        var programInfo = new ProgramInfo(name, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);
        __app.log.info(LogCategory.RENDERER, "Created ProgramInfo '" + name + "' from files: " + vertexShaderPath + ", " + fragmentShaderPath);
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
            __app.log.error(LogCategory.RENDERER, "Cannot upload null texture data");
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

	public function createFramebuffer(width:Int, height:Int, textureConfigs:Array<FramebufferTextureConfig>, useDepthRenderbuffer:Bool = false):Int {
        if (width <= 0 || height <= 0) {
            throw "Framebuffer dimensions must be positive";
        }

        if (textureConfigs == null) {
            throw "Framebuffer texture configurations cannot be null";
        }

        if (textureConfigs.length == 0 && !useDepthRenderbuffer) {
            throw "Framebuffer requires at least one attachment";
        }

        var hasDepthAttachment = false;
        for (i in 0...textureConfigs.length) {
            var attachment = textureConfigs[i].attachment;

            if (attachment == GL.DEPTH_ATTACHMENT || attachment == GL.DEPTH_STENCIL_ATTACHMENT) {
                if (useDepthRenderbuffer || hasDepthAttachment) {
                    throw "Framebuffer cannot have multiple depth attachments or combine a depth texture with a depth renderbuffer";
                }
                hasDepthAttachment = true;
            }

            for (j in 0...i) {
                if (attachment == textureConfigs[j].attachment) {
                    throw "Duplicate framebuffer attachment: " + attachment;
                }
            }
        }

        var framebuffer = new Framebuffer(width, height, textureConfigs.copy(), useDepthRenderbuffer);
        framebuffer.fbo = GL.createFramebuffer();
        try {
            initializeFramebufferAttachments(framebuffer);
        } catch (error:Dynamic) {
            restoreFramebufferBinding();
            disposeFramebufferResources(framebuffer, true);
            throw error;
        }

        var id = __nextFramebufferId++;
        __framebuffers.set(id, framebuffer);
        return id;
    }

    public function getFramebufferTexture(framebufferId:Int, attachment:Int):Texture {
        var framebuffer = getFramebufferOrThrow(framebufferId);
        for (texture in framebuffer.textures) {
            if (texture.attachment == attachment) return texture.texture;
        }
        throw "Framebuffer " + framebufferId + " has no texture at attachment " + attachment;
    }

    public function bindFramebuffer(framebufferId:Int):Void {
        var framebuffer = getFramebufferOrThrow(framebufferId);
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer.fbo);
        GL.viewport(0, 0, framebuffer.width, framebuffer.height);
        __framebufferStack.push(framebufferId);
    }

    public function unbindFramebuffer(framebufferId:Int):Void {
        if (__framebufferStack.length == 0
            || __framebufferStack[__framebufferStack.length - 1] != framebufferId) {
            throw "Framebuffer " + framebufferId + " is not the active render target";
        }

        __framebufferStack.pop();
        restoreFramebufferBinding();
        if (__framebufferStack.length == 0) {
            var size = __app.window.getWindowSizeInPixels();
            GL.viewport(0, 0, size.width, size.height);
        } else {
            var active = getFramebufferOrThrow(__framebufferStack[__framebufferStack.length - 1]);
            GL.viewport(0, 0, active.width, active.height);
        }
    }

    public function resizeFramebuffer(framebufferId:Int, width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return;
        var framebuffer = getFramebufferOrThrow(framebufferId);
        if (__framebufferStack.indexOf(framebufferId) >= 0) {
            throw "Cannot resize framebuffer " + framebufferId + " while it is bound";
        }
        if (framebuffer.width == width && framebuffer.height == height) return;

        disposeFramebufferAttachments(framebuffer);
        framebuffer.width = width;
        framebuffer.height = height;
        try {
            initializeFramebufferAttachments(framebuffer);
        } catch (error:Dynamic) {
            restoreFramebufferBinding();
            disposeFramebufferResources(framebuffer, true);
            __framebuffers.remove(framebufferId);
            if (__postProcessFramebufferId == framebufferId) __postProcessFramebufferId = -1;
            throw error;
        }
    }

    public function disposeFramebuffer(framebufferId:Int):Void {
        var framebuffer = getFramebufferOrThrow(framebufferId);
        if (__framebufferStack.indexOf(framebufferId) >= 0) {
            throw "Cannot dispose framebuffer " + framebufferId + " while it is bound";
        }
        disposeFramebufferResources(framebuffer, true);
        __framebuffers.remove(framebufferId);
        if (__postProcessFramebufferId == framebufferId) __postProcessFramebufferId = -1;
    }

    private function getFramebufferOrThrow(framebufferId:Int):Framebuffer {
        var framebuffer = __framebuffers.get(framebufferId);
        if (framebuffer == null) {
            throw "Framebuffer with ID " + framebufferId + " not found";
        }
        return framebuffer;
    }

    private function initializeFramebufferAttachments(framebuffer:Framebuffer):Void {
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer.fbo);
        for (config in framebuffer.textureConfigs) {

            var texture = createRenderTargetTexture(
                framebuffer.width,
                framebuffer.height,
                config.internalFormat,
                config.format,
                config.type
            );

            GL.framebufferTexture2D(
                GL.FRAMEBUFFER,
                config.attachment,
                GL.TEXTURE_2D,
                texture.id,
                0
            );

            framebuffer.textures.push({attachment: config.attachment, texture: texture});
        }

        var drawBuffers:Array<Int> = [];
        var firstColorAttachment = -1;
        for (config in framebuffer.textureConfigs) {
            if (config.attachment >= GL.COLOR_ATTACHMENT0
                && config.attachment < GL.COLOR_ATTACHMENT0 + 32) {
                var index = config.attachment - GL.COLOR_ATTACHMENT0;
                while (drawBuffers.length <= index) drawBuffers.push(GL.NONE);
                drawBuffers[index] = config.attachment;
                if (firstColorAttachment < 0) firstColorAttachment = config.attachment;
            }
        }
        GL.drawBuffers(drawBuffers.length > 0 ? drawBuffers : [GL.NONE]);
        GL.readBuffer(firstColorAttachment >= 0 ? firstColorAttachment : GL.NONE);

        if (framebuffer.hasDepthRenderbuffer) {
            framebuffer.depthRenderbuffer = GL.createRenderbuffer();
            GL.bindRenderbuffer(GL.RENDERBUFFER, framebuffer.depthRenderbuffer);
            GL.renderbufferStorage(
                GL.RENDERBUFFER, GL.DEPTH_COMPONENT24, framebuffer.width, framebuffer.height
            );
            GL.framebufferRenderbuffer(
                GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, framebuffer.depthRenderbuffer
            );
            GL.bindRenderbuffer(GL.RENDERBUFFER, 0);
        }

        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        restoreFramebufferBinding();
        if (status != GL.FRAMEBUFFER_COMPLETE) {
            var message = "Framebuffer incomplete: " + getFramebufferStatusString(status);
            __app.log.error(LogCategory.RENDERER, message);
            throw message;
        }
        __app.log.debug(
            LogCategory.RENDERER, "Created framebuffer " + framebuffer.width + "x" + framebuffer.height
        );
    }

    private function restoreFramebufferBinding():Void {
        var framebufferId = __framebufferStack.length > 0
            ? __framebufferStack[__framebufferStack.length - 1]
            : -1;
        var framebuffer = framebufferId >= 0 ? __framebuffers.get(framebufferId) : null;
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer != null ? framebuffer.fbo : 0);
    }

    private function getFramebufferStatusString(status:Int):String {
        return switch (status) {
            case 0x8CD5: "FRAMEBUFFER_COMPLETE";
            case 0x8CD6: "FRAMEBUFFER_INCOMPLETE_ATTACHMENT";
            case 0x8CD7: "FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT";
            case 0x8CDB: "FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER";
            case 0x8CDC: "FRAMEBUFFER_INCOMPLETE_READ_BUFFER";
            case 0x8CDD: "FRAMEBUFFER_UNSUPPORTED";
            case 0x8D56: "FRAMEBUFFER_INCOMPLETE_MULTISAMPLE";
            default: "UNKNOWN_STATUS_" + status;
        };
    }

    private function disposeFramebufferAttachments(framebuffer:Framebuffer):Void {
        for (attachment in framebuffer.textures) {
            GL.deleteTexture(attachment.texture.id);
        }
        framebuffer.textures = [];
        if (framebuffer.depthRenderbuffer != 0) {
            GL.deleteRenderbuffers(1, framebuffer.depthRenderbuffer);
            framebuffer.depthRenderbuffer = 0;
        }
    }

    private function disposeFramebufferResources(framebuffer:Framebuffer, deleteFramebuffer:Bool):Void {
        disposeFramebufferAttachments(framebuffer);
        if (deleteFramebuffer && framebuffer.fbo != 0) {
            GL.deleteFramebuffer(framebuffer.fbo);
            framebuffer.fbo = 0;
        }
    }

    // -------------------------------------------------------------------------
    // Post-processing framebuffer
    // -------------------------------------------------------------------------

    public function initializePostProcessing():Void {
        if (__postProcessFramebufferId >= 0) return;
        var size = __app.window.getWindowSizeInPixels();
        __postProcessFramebufferId = createFramebuffer(size.width, size.height, [{
            attachment: GL.COLOR_ATTACHMENT0,
            internalFormat: GL.RGBA8,
            format: GL.RGBA,
            type: GL.UNSIGNED_BYTE
        }], true);
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
        __app.log.info(LogCategory.RENDERER, "Post-processing initialized");
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
        __app.log.debug(LogCategory.RENDERER, "Created fullscreen quad");
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return; // Ignore degenerate resize (e.g. canvas inside display:none)
        GL.viewport(0, 0, width, height);
        if (__postProcessFramebufferId >= 0) {
            resizeFramebuffer(__postProcessFramebufferId, width, height);
        }
    }

    public function renderToScreen():Void {
        if (__postProcessFramebufferId < 0 || postProcessShader == null) {
            __app.log.warn(LogCategory.RENDERER, "Post-processing not initialized");
            return;
        }
        GL.useProgram(postProcessShader.program);
        postProcessShader.initializeSamplerUnits();
        var uniformInfo = postProcessShader.getUniform("uScreenTexture");
        if (uniformInfo != null) uniformInfo.setter(
            getFramebufferTexture(__postProcessFramebufferId, GL.COLOR_ATTACHMENT0)
        );
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

        while (__framebufferStack.length > 0) {
            unbindFramebuffer(__framebufferStack[__framebufferStack.length - 1]);
        }
        for (framebuffer in __framebuffers) {
            disposeFramebufferResources(framebuffer, true);
        }
        __framebuffers.clear();
        __postProcessFramebufferId = -1;

        // Destroy cached VAOs
        for (vao in __vaoCache) {
            GL.deleteVertexArray(vao);
        }
        __vaoCache.clear();

        for (name in programInfos.keys()) {
            var pi = programInfos.get(name);
            if (pi != null) {
                pi.dispose();
                __app.log.debug(LogCategory.RENDERER, "Disposed ProgramInfo: " + name);
            }
        }
        programInfos.clear();
        __app.log.info(LogCategory.RENDERER, "Renderer cleanup complete");
    }

    // -------------------------------------------------------------------------
    // Getters
    // -------------------------------------------------------------------------

    private function get_app():App { return __app; }
}
#end
