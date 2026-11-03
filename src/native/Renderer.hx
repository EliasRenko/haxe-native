package native;

import cpp.ConstCharStar;
import cpp.Float32;
import cpp.RawConstPointer;
import cpp.RawPointer;
import cpp.UInt32;
import data.Indices;
import data.Shader as DataShader;
import data.TextureData;
import data.Vertices;
import display.DepthVisualizationScreenPass;
import display.GrayscaleScreenPass;
import display.ScanlineScreenPass;
import display.ScreenPass;
import ds.SlotArray;
import GL;
import Log;
import math.Matrix;
import ProgramInfo;
import Texture;

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
    public var fbo:UInt = 0;
    public var textureConfigs:Array<FramebufferTextureConfig>;
    public var textures:Array<FramebufferTextureAttachment> = [];
    public var depthRenderbuffer:UInt = 0;
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

private typedef ShaderDefinition = {
    final name:String;
    final vertexSource:String;
    final fragmentSource:String;
}

class Buffers {
	public var vbo:UInt32;
	public var ebo:UInt32;
    public var programInfo:ProgramInfo;

    public function new(vbo:UInt32, ebo:UInt32, programInfo:ProgramInfo) {
        this.vbo = vbo;
        this.ebo = ebo;
        this.programInfo = programInfo;
    }
}

@:build(macros.ShaderRegistryMacro.build("shaders"))
class Renderer {
    
    // Publics
    public var app(get, null):App;
    public var frameCount(get, null):Int;
    public var matrix:Matrix = new Matrix();

    // Privates
    private var __app:App;
    private var __currentDepthTest:Bool = false;
    private var __currentDepthWrite:Bool = false;
    private var __currentBlendMode:Bool = false;
    private var __currentBlendSource:Int = -1;
    private var __currentBlendDestination:Int = -1;
    private var __frameCount:Int = 0;
    private var __programInfos:Array<ProgramInfo> = new Array<ProgramInfo>();

    private var buffers:SlotArray<Buffers> = new SlotArray<Buffers>(32);
    private var framebuffers:SlotArray<Framebuffer> = new SlotArray<Framebuffer>(8);
    private var __framebufferStack:Array<Int> = [];

    public var postProcessDisplayObject:ScreenPass = null;
    public var usePostProcessing:Bool = false; // Toggle post-processing on/off
    private var __screenPasses:Array<ScreenPass> = [];
    private var __activeScreenPassIndex:Int = 0;
    private var currentProgram:Int = -1;
    private var currentVbo:Int = 0;
    private var currentEbo:Int = 0;
    
    // ===== LIFECYCLE =====

    public function new(app:App) {
        __app = app;

		for (definition in definitions) {
			var programInfo = new ProgramInfo(definition.name, definition.vertexSource, definition.fragmentSource);
			__programInfos.push(programInfo);
		}

        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(true);
    }
    
    public function render():Void {
        currentProgram = -1;
        currentVbo = 0;
        currentEbo = 0;
        __currentBlendSource = -1;
        __currentBlendDestination = -1;
        __frameCount++;
    }

    public function release():Void {
        // Reset render state
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);

        while (__framebufferStack.length > 0) {
            unbindFramebuffer(__framebufferStack[__framebufferStack.length - 1]);
        }

        if (postProcessDisplayObject != null) {
            for (screenPass in __screenPasses) {
                screenPass.dispose(this);
                screenPass.release(this);
            }
            __screenPasses = [];
            postProcessDisplayObject = null;
        }

        for (framebuffer in framebuffers) {
            disposeFramebufferResources(framebuffer, true);
        }
        framebuffers.clear();

        for (buffer in buffers) {
            deleteBuffers(buffers.indexOf(buffer));
        }
        buffers.clear();

        for (programInfo in __programInfos) {
            programInfo.dispose();
        }
        __programInfos = [];

        __app.log.info(LogCategory.RENDERER, "Renderer cleanup complete");
    }

    // ===== PROGRAMS AND DRAWING =====

    public function useProgram(programInfo:ProgramInfo):Void {
        if (programInfo.program != currentProgram) {
            GL.useProgram(programInfo.program);
            GL.bindVertexArray(programInfo.vao);
            programInfo.initializeSamplerUnits();
            currentProgram = programInfo.program;
            currentVbo = 0;
            currentEbo = 0;
        }
    }

    public function getProgramInfo(index:Int):ProgramInfo {
        if (index < 0 || index >= __programInfos.length) {
            throw "ProgramInfo index out of range: " + index;
        }
        return __programInfos[index];
    }

    public function renderUniforms(programInfo:ProgramInfo, shader:Null<DataShader>):Void {
        if (shader == null) return;

        for (uniform in shader.getUniforms()) {
            var uniformInfo = programInfo.getUniformAt(uniform.nameId);
            
            // If the uniform doesn't exist in the shader, log a warning and skip it
            if (uniformInfo == null) {
                __app.log.warn(
                    LogCategory.RENDERER,
                    "Uniform '" + uniform.name + "' doesn't exist in shader"
                );

                continue;
            }

            uniformInfo.setter(uniform.value);
        }
    }

    public function drawElements(mode:Int, count:Int):Void {
        GL.drawElements(mode, count, GL.UNSIGNED_INT, 0);
    }

    public function drawArrays(mode:Int, first:Int, count:Int):Void {
        GL.drawArrays(mode, first, count);
    }
    
    public function createProgramInfo(name:String, vertexSource:String, fragmentSource:String):ProgramInfo {
        var programInfo = new ProgramInfo(name, vertexSource, fragmentSource);

        __programInfos.push(programInfo);

        __app.log.info(LogCategory.RENDERER, "Created and registered ProgramInfo: " + name);

        return programInfo;
    }
    
    // ===== BUFFERS =====

	public function bindBuffers(bufferId:Int, stride:Int):Void {
		var buffersObjs = buffers.get(bufferId);
		if (buffersObjs == null) {
			throw "Buffers not found for bufferId: " + bufferId;
		}

		// Also bind using modern ARB_vertex_attrib_binding
		if (buffersObjs.vbo != currentVbo) {
			GL.bindVertexBuffer(0, buffersObjs.vbo, 0, stride);
			currentVbo = buffersObjs.vbo;
		}

		// Bind element buffer if available
		if (buffersObjs.ebo != 0 && buffersObjs.ebo != currentEbo) {
			GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, buffersObjs.ebo);
			currentEbo = buffersObjs.ebo;
		}
	}

    public function createBuffers(programInfoIndex:Int):Int {
        if (programInfoIndex < 0 || programInfoIndex >= __programInfos.length) {
            throw "ProgramInfo index out of range: " + programInfoIndex;
        }

        var vbo:UInt32 = 0;
        var ebo:UInt32 = 0;

        GL.genBuffers(1, RawPointer.addressOf(vbo));
        GL.genBuffers(1, RawPointer.addressOf(ebo));

        return buffers.add(new Buffers(vbo, ebo, __programInfos[programInfoIndex]));
    }

    public function getBuffers(bufferId:Int):Buffers {
        return buffers.get(bufferId);
    }

    // Upload vertex data to GPU
    public function uploadData(bufferId:Int, vertices:Vertices, indices:Indices):Void {
        var bufferInfo = getBuffersOrThrow(bufferId);

        GL.bindVertexArray(bufferInfo.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, bufferInfo.vbo);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.DYNAMIC_DRAW, vertices.length);
        if (bufferInfo.ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, bufferInfo.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, indices, GL.DYNAMIC_DRAW, indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

    public function orphanAndUploadData(bufferId:Int, vertices:Vertices, indices:Indices, maxBufferSize:Int):Void {
        var bufferInfo = getBuffersOrThrow(bufferId);

        GL.bindVertexArray(bufferInfo.programInfo.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, bufferInfo.vbo);
        untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.STREAM_DRAW, vertices.length);
        if (bufferInfo.ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, bufferInfo.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, indices, GL.STREAM_DRAW, indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

    public function deleteBuffers(bufferId:Int):Void {
        var buffersObj = buffers.get(bufferId);
        if (buffersObj == null) return;

        GL.deleteBuffers(1, RawPointer.addressOf(buffersObj.vbo));
        GL.deleteBuffers(1, RawPointer.addressOf(buffersObj.ebo));

        buffers.remove(bufferId);
    }

    private function getBuffersOrThrow(bufferId:Int):Buffers {
        var bufferInfo = buffers.get(bufferId);
        if (bufferInfo == null) {
            throw "Buffers not found for bufferId: " + bufferId;
        }
        return bufferInfo;
    }

    // ===== TEXTURES =====

    /**
     * Upload TextureData to OpenGL and return Texture object
     */
    public function uploadTexture(textureData:TextureData):Texture {
        if (textureData == null) {
            __app.log.error(LogCategory.RENDERER, "Cannot upload null texture data");
            return null;
        }

        var textureId:UInt32 = 0;
        GL.genTextures(1, RawPointer.addressOf(textureId));
        
        GL.bindTexture(GL.TEXTURE_2D, textureId);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        
        // Upload actual texture data with correct format based on BPP
        var format:Int;
        var internalFormat:Int;
        
        switch (textureData.bytesPerPixel) {
            case 1: // Grayscale/monochrome
                format = GL.RED;
                internalFormat = GL.RED;
            case 2: // Grayscale + Alpha
                format = GL.RG;
                internalFormat = GL.RG;
            case 3: // RGB
                format = GL.RGB;
                internalFormat = GL.RGB;
            case 4: // RGBA
                format = GL.RGBA;
                internalFormat = GL.RGBA;
            default:
                throw "Unsupported texture format: " + textureData.bytesPerPixel + " bytes per pixel";
        }
                    
        GL.texImage2D(GL.TEXTURE_2D, 0, internalFormat, textureData.width, textureData.height, 0, format, GL.UNSIGNED_BYTE, textureData.bytes.getData().bytes);
        GL.bindTexture(GL.TEXTURE_2D, 0);

        var texture:Texture = {
            id: textureId,
            width: textureData.width,
            height: textureData.height,
            bpp: textureData.bytesPerPixel,
            target: GL.TEXTURE_2D,
            src: textureData.src
        };
        
        return texture;
    }

    public function createRenderTargetTexture(width:Int, height:Int, internalFormat:Int, format:Int, type:Int):Texture {
        var textureId:UInt32 = 0;
        GL.genTextures(1, RawPointer.addressOf(textureId));
        GL.bindTexture(GL.TEXTURE_2D, textureId);

        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);

        // Allocate texture storage without uploading data
        untyped __cpp__("glTexImage2D({0}, 0, {1}, {2}, {3}, 0, {4}, {5}, NULL);", GL.TEXTURE_2D, internalFormat, width, height, format, type);

        GL.bindTexture(GL.TEXTURE_2D, 0);

        return {
            id: textureId,
            width: width,
            height: height,
            bpp: (format == GL.RGBA ? 4 : 1),
            target: GL.TEXTURE_2D,
            src: ""
        };
    }

    // ===== RENDER STATE =====

    /**
     * Clear the screen and prepare for rendering
     */
    public function clearScreen():Void {
        GL.glClearColor(0.1, 0.1, 0.15, 1.0); // Very dark background for 3D focus
        GL.glClear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
    }

    /**
     * Initialize rendering state
     */
    public function initializeRenderState():Void {
        // Enable depth testing for 3D
        // GL.glEnable(GL.DEPTH_TEST);
        // GL.glDepthFunc(GL.LESS);

        // Disable face culling to see all faces from all angles
        GL.glDisable(GL.CULL_FACE);
    }

    // TODO: Move to GL
    public function vertexAttribPointer(index:Int, size:Int, type:Int, normalized:Bool, stride:Int, offset:Int):Void {
        untyped __cpp__("glVertexAttribPointer({0}, {1}, {2}, {3} ? GL_TRUE : GL_FALSE, {4}, (void*)(intptr_t){5})", index, size, type, normalized, stride, offset);
    }

	public function setBlendFunction(source:Int, destination:Int):Void {
		if (__currentBlendSource != source || __currentBlendDestination != destination) {
			GL.blendFunc(source, destination);
			__currentBlendSource = source;
			__currentBlendDestination = destination;
		}
	}

    public function setDepthTest(enabled:Bool):Void {
        if (__currentDepthTest != enabled) {
            if (enabled) {
                GL.glEnable(GL.DEPTH_TEST);
            } else {
                GL.glDisable(GL.DEPTH_TEST);
            }
            __currentDepthTest = enabled;
        }
    }
    
    public function setDepthWrite(enabled:Bool):Void {
        if (__currentDepthWrite != enabled) {
            GL.glDepthMask(enabled);
            __currentDepthWrite = enabled;
        }
    }
    
    public function setBlendMode(enabled:Bool):Void {
        if (__currentBlendMode != enabled) {
            if (enabled) {
                GL.glEnable(GL.BLEND);
                setBlendFunction(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
            } else {
                GL.glDisable(GL.BLEND);
            }
            __currentBlendMode = enabled;
        }
    }

    // ===== ACCESSORS =====

    private function get_app():App {
        return __app;
    }

    private function get_frameCount():Int {
        return __frameCount;
    }

    // ===== POST-PROCESSING =====

	public function initializePostProcessing():Void {
        if (postProcessDisplayObject != null) {
            return;
        }

        var size = app.window.getWindowSizeInPixels();
        __screenPasses = [];
        try {
            __screenPasses.push(new ScanlineScreenPass(this, size.width, size.height));
            __screenPasses.push(new GrayscaleScreenPass(this, size.width, size.height));
            __screenPasses.push(new DepthVisualizationScreenPass(this, size.width, size.height));
        } catch (error:Dynamic) {
            for (screenPass in __screenPasses) {
                screenPass.dispose(this);
                screenPass.release(this);
            }
            __screenPasses = [];
            throw error;
        }
        __activeScreenPassIndex = 0;
        postProcessDisplayObject = __screenPasses[__activeScreenPassIndex];
	}

    public function cyclePostProcess(delta:Int):Void {
        if (__screenPasses.length == 0) {
            throw "Post-processing screen passes are not initialized";
        }

        __activeScreenPassIndex = (__activeScreenPassIndex + delta) % __screenPasses.length;
        if (__activeScreenPassIndex < 0) {
            __activeScreenPassIndex += __screenPasses.length;
        }
        postProcessDisplayObject = __screenPasses[__activeScreenPassIndex];
        __app.log.info(
            LogCategory.RENDERER,
            "Selected screen pass " + (__activeScreenPassIndex + 1) + "/" + __screenPasses.length
                + ": " + postProcessDisplayObject.label
        );
    }

    // ===== FRAMEBUFFERS =====

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
        return framebuffers.add(framebuffer);
    }

    public function getFramebufferTexture(frameBufferId:Int, attachment:Int):Texture {
        var framebuffer = getFramebufferOrThrow(frameBufferId);
        for (texture in framebuffer.textures) {
            if (texture.attachment == attachment) return texture.texture;
        }
        throw "Framebuffer " + frameBufferId + " has no texture at attachment " + attachment;
    }

    public function resizeFramebuffer(frameBufferId:Int, width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return;
        var framebuffer = getFramebufferOrThrow(frameBufferId);
        if (__framebufferStack.indexOf(frameBufferId) >= 0) {
            throw "Cannot resize framebuffer " + frameBufferId + " while it is bound";
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
            framebuffers.remove(frameBufferId);
            throw error;
        }
    }

    private function getFramebufferOrThrow(frameBufferId:Int):Framebuffer {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer == null) {
            throw "Framebuffer with ID " + frameBufferId + " not found";
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
        GL.drawBuffers(
            drawBuffers.length > 0 ? drawBuffers.length : 1,
            drawBuffers.length > 0 ? drawBuffers : [GL.NONE]
        );
        GL.readBuffer(firstColorAttachment >= 0 ? firstColorAttachment : GL.NONE);

        if (framebuffer.hasDepthRenderbuffer) {
            var renderbuffers:Array<UInt> = [0];
            GL.genRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", renderbuffers));
            framebuffer.depthRenderbuffer = renderbuffers[0];
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
            LogCategory.RENDERER,
            "Created framebuffer " + framebuffer.width + "x" + framebuffer.height
        );
    }

    private function restoreFramebufferBinding():Void {
        var framebufferId = __framebufferStack.length > 0
            ? __framebufferStack[__framebufferStack.length - 1]
            : -1;
        var framebuffer = framebufferId >= 0 ? framebuffers.get(framebufferId) : null;
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
            var textures = [attachment.texture.id];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", textures));
        }
        framebuffer.textures = [];
        if (framebuffer.depthRenderbuffer != 0) {
            var renderbuffers = [framebuffer.depthRenderbuffer];
            GL.deleteRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", renderbuffers));
            framebuffer.depthRenderbuffer = 0;
        }
    }

    private function disposeFramebufferResources(framebuffer:Framebuffer, deleteFramebuffer:Bool):Void {
        disposeFramebufferAttachments(framebuffer);
        if (deleteFramebuffer && framebuffer.fbo != 0) {
            var framebuffers = [framebuffer.fbo];
            GL.deleteFramebuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", framebuffers));
            framebuffer.fbo = 0;
        }
    }

    public function bindFramebuffer(frameBufferId:Int):Void {
        var framebuffer = getFramebufferOrThrow(frameBufferId);
        GL.bindFramebuffer(GL.FRAMEBUFFER, framebuffer.fbo);
        setViewport(framebuffer.width, framebuffer.height);
        __framebufferStack.push(frameBufferId);
	}
	
	public function unbindFramebuffer(frameBufferId:Int):Void {
        if (__framebufferStack.length == 0
            || __framebufferStack[__framebufferStack.length - 1] != frameBufferId) {
            throw "Framebuffer " + frameBufferId + " is not the active render target";
        }

        var previousFramebuffer:Framebuffer = null;
        if (__framebufferStack.length > 1) {
            previousFramebuffer = framebuffers.get(__framebufferStack[__framebufferStack.length - 2]);
            if (previousFramebuffer == null) {
                throw "Active framebuffer no longer exists";
            }
        }

        __framebufferStack.pop();
        if (previousFramebuffer != null) {
            GL.bindFramebuffer(GL.FRAMEBUFFER, previousFramebuffer.fbo);
            setViewport(previousFramebuffer.width, previousFramebuffer.height);
        } else {
            GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
            var size = app.window.getWindowSizeInPixels();
            setViewport(size.width, size.height);
        }
	}
	
    public function disposeFramebuffer(frameBufferId:Int):Void {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer == null) {
            throw "Framebuffer with ID " + frameBufferId + " not found";
        }
        if (__framebufferStack.indexOf(frameBufferId) >= 0) {
            throw "Cannot dispose framebuffer " + frameBufferId + " while it is bound";
        }
        disposeFramebufferResources(framebuffer, true);
        framebuffers.remove(frameBufferId);
    }

    // ===== VIEWPORT =====

    private function setViewport(width:Int, height:Int):Void {
        GL.viewport(0, 0, width, height);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return; // Ignore degenerate resize (e.g. window minimised)
        if (__framebufferStack.length > 0) {
            var activeFramebuffer = framebuffers.get(__framebufferStack[__framebufferStack.length - 1]);
            if (activeFramebuffer == null) {
                throw "Active framebuffer no longer exists";
            }
            setViewport(activeFramebuffer.width, activeFramebuffer.height);
        } else {
            setViewport(width, height);
        }
        
        for (screenPass in __screenPasses) {
            screenPass.resize(this, width, height);
        }
    }
}