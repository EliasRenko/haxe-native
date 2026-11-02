package native;

import data.Vertices;
import data.Indices;
import ds.SlotArray;
import cpp.RawConstPointer;
import cpp.ConstCharStar;
import cpp.RawPointer;
import GL;
import ProgramInfo;
import DisplayObject;
import data.TextureData;
import Texture;
import math.Matrix;
import cpp.Float32;
import cpp.UInt32;
import Framebuffer;
import Log;
import display.ScreenPass;

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
    private var __currentDepthTest:Bool = true;
    private var __currentDepthWrite:Bool = true;
    private var __currentBlendMode:Bool = false;
    private var __currentBlendSource:Int = -1;
    private var __currentBlendDestination:Int = -1;
    private var __frameCount:Int = 0;
    private var __programInfos:Array<ProgramInfo> = new Array<ProgramInfo>();

    private var buffers:SlotArray<Buffers> = new SlotArray<Buffers>(32);
    public var framebuffers:SlotArray<Framebuffer> = new SlotArray<Framebuffer>(8);

    public var postProcessDisplayObject:ScreenPass = null;
    private var __fullscreenQuadVAO:Int = 0;
    private var __fullscreenQuadVBO:Int = 0;
    public var usePostProcessing:Bool = false; // Toggle post-processing on/off
    private var currentProgram:Int = -1;
    private var currentVbo:Int = 0;
    private var currentEbo:Int = 0;
    
    public function new(app:App) {
        __app = app;

        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(true);

        // ---

		for (definition in definitions) {
			var programInfo = new ProgramInfo(definition);
			__programInfos.push(programInfo);
		}
    }
    
    public function render():Void {
        currentProgram = -1;
        currentVbo = 0;
        currentEbo = 0;
        __currentBlendSource = -1;
        __currentBlendDestination = -1;
        __frameCount++;
    }

    public function useProgram(programInfo:ProgramInfo):Void {
        if (programInfo.program != currentProgram) {
            GL.useProgram(programInfo.program);
            GL.bindVertexArray(programInfo.vao);
            currentProgram = programInfo.program;
            currentVbo = 0;
            currentEbo = 0;
        }
    }

    public function getProgramInfo(index:Int):ProgramInfo {
        return __programInfos[index];
    }

	public function bindBuffers(bufferId:Int, stride:Int):Void {
		var buffersObjs = buffers.get(bufferId);
		if (buffersObjs == null) {
			trace("Error: Buffers not found for bufferId: " + bufferId);
			return;
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

	public function setBlendFunction(source:Int, destination:Int):Void {
		if (__currentBlendSource != source || __currentBlendDestination != destination) {
			GL.blendFunc(source, destination);
			__currentBlendSource = source;
			__currentBlendDestination = destination;
		}
	}

    public function renderUniforms(programInfo:ProgramInfo, displayObject:DisplayObject):Void {
        var shader = displayObject.shader;
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

    public function bindTexture(textureId:Int, index:Int):Void {
        if (textureId != 0) {
            GL.activeTexture(GL.TEXTURE0 + index);
            GL.bindTexture(GL.TEXTURE_2D, textureId);
        }
    }

    public function drawElements(mode:Int, count:Int):Void {
        GL.drawElements(mode, count, GL.UNSIGNED_INT, 0);
    }

    public function drawArrays(mode:Int, first:Int, count:Int):Void {
        GL.drawArrays(mode, first, count);
    }
    
    public function createProgramInfo(shaderDef:ShaderDefinition):ProgramInfo {
        var programInfo = new ProgramInfo(shaderDef);

        __programInfos.push(programInfo);

        __app.log.info(LogCategory.RENDERER, "Created and registered ProgramInfo: " + shaderDef.name);

        return programInfo;
    }
    
    // ===== RENDERING PIPELINE METHODS =====

    public function createBuffers(programInfoIndex:Int):Int {
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
        var bufferInfo = buffers.get(bufferId);

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
        var bufferInfo = buffers.get(bufferId);

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

    /**
     * Upload TextureData to OpenGL and return Texture object
     */
    public function uploadTexture(textureData:TextureData):Texture {
        if (textureData == null) {
            trace("Error: Cannot upload null texture data");
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

    public function release():Void {
        // Reset render state
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);

        postProcessDisplayObject.dispose(this);
        postProcessDisplayObject = null;

        __programInfos = [];
        framebuffers.clear();
        buffers.clear();
        
        trace("Renderer cleanup complete");
    }
    
    /**
     * Render state management methods
     */
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
            // For now, skip depth mask as it's not in GL.hx yet
            // GL.depthMask(enabled);
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

    // Getters and setters
    private function get_app():App {
        return __app;
    }

    private function get_frameCount():Int {
        return __frameCount;
    }
	
	public function initializePostProcessing():Void {
        var size = app.window.getWindowSizeInPixels();

        //var vertShader = app.resources.getText("shaders/postprocess.vert");
        //var fragShader = app.resources.getText("shaders/postprocess.frag");
        
        //createProgramInfo("postprocess", vertShader, fragShader);

        postProcessDisplayObject = new ScreenPass(this, size.width, size.height);

        trace("Renderer: Post-processing initialized");
	}

    public function createFramebuffer(width:Int, height:Int):Int {
        
        var framebuffer = new Framebuffer(width, height, false, false);
        framebuffer.initialize(this);

        return framebuffers.add(framebuffer);
    }

    public function bindFramebuffer(frameBufferId:Int):Void {

        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer != null) {
            framebuffer.bind();
        } else {
            trace("Error: Framebuffer with ID " + frameBufferId + " not found.");
        }
	}
	
	public function unbindFramebuffer(frameBufferId:Int):Void {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer != null) {
            framebuffer.unbind();
        } else {
            trace("Error: Framebuffer with ID " + frameBufferId + " not found.");
        }

        var size = app.window.getWindowSizeInPixels();
		setViewport(size.width, size.height);
	}
	
    private function setViewport(width:Int, height:Int):Void {
        GL.viewport(0, 0, width, height);
    }

    public function resize(width:Int, height:Int):Void {
        if (width <= 0 || height <= 0) return; // Ignore degenerate resize (e.g. window minimised)
        setViewport(width, height);
        
        postProcessDisplayObject.resize(this, width, height);
    }

    public function disposeFramebuffer(frameBufferId:Int):Void {
        var framebuffer = framebuffers.get(frameBufferId);
        if (framebuffer != null) {
            framebuffer.dispose();
            framebuffers.remove(frameBufferId);
        } else {
            trace("Error: Framebuffer with ID " + frameBufferId + " not found.");
        }
    }
}