package;

import GL;
import ProgramInfo;
import DisplayObject;
import data.TextureData;
import Texture;
import math.Matrix;
import cpp.Float32;
import cpp.UInt32;

typedef RenderState = {
    depthTest:Bool,
    depthWrite:Bool,
    blendMode:Bool
}

class Renderer {
    
    // Publics
    public var app(get, null):App;
    public var windowWidth:Int;
    public var windowHeight:Int;
    
    private var __app:App;
    
    // Current render state tracking
    private var __currentDepthTest:Bool = true;
    private var __currentDepthWrite:Bool = true;
    private var __currentBlendMode:Bool = false;
    private var frameCount:Int = 0;
    
    // ProgramInfo storage - managed by States, not Renderer
    private var programInfos:Map<String, ProgramInfo> = new Map<String, ProgramInfo>();
    
    // Framebuffer for post-processing
    public var screenFBO:Int = 0;
    public var screenTexture:Int = 0;
    public var postProcessShader:ProgramInfo = null;
    private var __fullscreenQuadVAO:Int = 0;
    private var __fullscreenQuadVBO:Int = 0;
    public var usePostProcessing:Bool = false; // Toggle post-processing on/off
    private var currentProgram:Int = -1;
    
    public function new(app:App, windowWidth:Int, windowHeight:Int) {
        this.__app = app;
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
    }
    
    public function render():Void {
        currentProgram = -1;
        frameCount++; // Increment frame counter for debug timing
        
        // Clear screen and depth buffer
        //clearScreen();
        
        // Initialize rendering state
        //initializeRenderState();
    }
    
    // ** New method to render display objects with provided view-projection matrix
    public function renderDisplayObject(displayObject:DisplayObject, viewProjectionMatrix:math.Matrix):Void {
        if (!displayObject.visible) return;
        
        // Update buffers if needed
        if (displayObject.needsBufferUpdate) {
            displayObject.updateBuffers(this);
        }
        
        displayObject.render(viewProjectionMatrix);

        // ---

        if (displayObject.vertices.length == 0) return;

        // Use the program
        if (displayObject.programInfo.program != currentProgram) {
            GL.useProgram(displayObject.programInfo.program);
            currentProgram = displayObject.programInfo.program;
        }

        // Bind VAO (shared from ProgramInfo)
        GL.bindVertexArray(displayObject.vao);
        
        // If using modern binding (ARB_vertex_attrib_binding), bind this object's VBO to binding point 0
        if (displayObject.programInfo.useModernBinding) {
            GL.bindVertexBuffer(0, displayObject.vbo, 0, displayObject.programInfo.dataPerVertex);
            
            // Bind EBO if present
            if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
                GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            }
        }

        // Render uniforms and textures
        __renderUniforms(displayObject.programInfo, displayObject.uniforms);
        __renderTextures(displayObject.programInfo, displayObject);

        // Draw the object
        if (displayObject.__indicesToRender == 0) {
            GL.drawArrays(displayObject.mode, 0, displayObject.__verticesToRender);
        } else {
            GL.drawElements(displayObject.mode, displayObject.__indicesToRender, GL.UNSIGNED_INT, 0);
        }

        GL.bindVertexArray(0);
    }

    private function __renderUniforms(programInfo:ProgramInfo, uniforms:Map<String, Dynamic>):Void {
        // Use pre-computed uniform setters for optimal performance - no more switch/case in render loop!
        for (name => value in uniforms) {
            // O(1) lookup using pre-computed uniform map
            var uniformInfo = programInfo.getUniform(name);
            
            if (uniformInfo == null) {
                // TODO: Convert to proper logging - __app.trace(21, "Warning: Uniform '" + name + "' not found in shader");
                trace("Warning: Uniform '" + name + "' not found in shader");
                continue; // Uniform doesn't exist in shader
            }
            
            // Use pre-computed setter function - direct function call, no branching!
            // This eliminates the switch/case overhead completely
            uniformInfo.setter(value);
        }
    }

    private function __renderTextures(programInfo:ProgramInfo, drawable:DisplayObject):Void {
        for (i in 0...programInfo.textures.length) {
            var x = GL.TEXTURE0 + i;
            GL.activeTexture(x);

            if (i < drawable.textures.length) {
                var texture = drawable.textures[i];
                var textureId = texture != null ? texture.id : 0;
                GL.bindTexture(GL.TEXTURE_2D, textureId);
            }

            GL.blendFunc(drawable.blendFactors.source, drawable.blendFactors.destination);
            
            drawable.programInfo.textures[i].setter(i);
        }
    }
    
    /**
     * Create and register a ProgramInfo if it doesn't exist, or return existing one
     * This is the proper way for States to request ProgramInfos from Renderer
     */
    public function createProgramInfo(name:String, vertexShader:String, fragmentShader:String):ProgramInfo {
        // Check if this ProgramInfo already exists
        if (programInfos.exists(name)) {
            return programInfos.get(name);
        }
        
        // Create new ProgramInfo and register it
        var programInfo = new ProgramInfo(name, this, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);

        // TODO: Convert to proper logging system once cross-class access is resolved
        // trace("Created and registered ProgramInfo: " + name);
        return programInfo;
    }
    
    /**
     * Get a ProgramInfo by name
     * Used by States to retrieve ProgramInfos for creating DisplayObjects
     */
    public function getProgramInfo(name:String):ProgramInfo {
        if (!programInfos.exists(name)) {
            trace("Error: ProgramInfo '" + name + "' not found!");
            return null;
        }
        return programInfos.get(name);
    }
    
    /**
     * Check if a ProgramInfo is already registered
     */
    public function hasProgramInfo(name:String):Bool {
        return programInfos.exists(name);
    }
    
    /**
     * Create and register a ProgramInfo from preloaded shader files
     * This method uses the App's resource system to load shader files
     */
    public function createProgramInfoFromFiles(name:String, vertexShaderPath:String, fragmentShaderPath:String):ProgramInfo {
        // Check if this ProgramInfo already exists
        if (programInfos.exists(name)) {
            trace("ProgramInfo '" + name + "' already exists, reusing...");
            return programInfos.get(name);
        }
        
        // Get shader source from preloaded resources
        var vertexShader = app.resources.getText(vertexShaderPath);
        var fragmentShader = app.resources.getText(fragmentShaderPath);
        
        if (vertexShader == null) {
            trace("Error: Vertex shader '" + vertexShaderPath + "' not found in preloaded resources!");
            return null;
        }
        
        if (fragmentShader == null) {
            trace("Error: Fragment shader '" + fragmentShaderPath + "' not found in preloaded resources!");
            return null;
        }
        
        // Create new ProgramInfo and register it
        var programInfo = new ProgramInfo(name, this, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);
        
        trace("Created ProgramInfo '" + name + "' from preloaded shaders: " + vertexShaderPath + ", " + fragmentShaderPath);
        return programInfo;
    }
    
    /**
     * Get all registered ProgramInfo names
     */
    public function getProgramInfoNames():Array<String> {
        var names:Array<String> = [];
        for (name in programInfos.keys()) {
            names.push(name);
        }
        return names;
    }
    // ===== RENDERING PIPELINE METHODS =====
    // These methods encapsulate all GL operations and should be the only place GL calls are made

    /**
     * Create VBO and EBO for display objects (VAO is now shared from ProgramInfo)
     */
    public function createBuffers(vertexCount:Int, indexCount:Int):{vao:UInt, vbo:UInt, ebo:UInt} {
        var vao:UInt = 0; // Will be set from ProgramInfo
        var vbo:UInt = 0; 
        var ebo:UInt = 0;

        // Generate VBO
        var vboArray = [vbo];
        GL.genBuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", vboArray));
        vbo = vboArray[0];

        // Always generate EBO - even if we don't need indices initially, we might later
        // This is needed for tilemaps that start empty but get indices when atlas is set
        var eboArray = [ebo];
        GL.genBuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", eboArray));
        ebo = eboArray[0];

        return {vao: vao, vbo: vbo, ebo: ebo};
    }

    public function uploadData(displayObject:DisplayObject):Void {
        GL.bindVertexArray(displayObject.vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, displayObject.vbo);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, displayObject.vertices, GL.DYNAMIC_DRAW, displayObject.vertices.length);
        if (displayObject.ebo != 0 && displayObject.indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, displayObject.ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, displayObject.indices, GL.DYNAMIC_DRAW, displayObject.indices.length);
        }

        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
    }

    /**
     * Upload vertex data to GPU
     */
    public function uploadVertexData(vao:UInt, vbo:UInt, vertices:Array<Float32>):Void {
        
        GL.bindVertexArray(vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
        GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.DYNAMIC_DRAW, vertices.length);
    }

    /**
     * Upload index data to GPU
     */
    public function uploadIndexData(ebo:UInt, indices:Array<UInt32>):Void {
        
        if (ebo != 0 && indices.length > 0) {
            
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
            GL.bufferUIntArray(GL.ELEMENT_ARRAY_BUFFER, indices, GL.DYNAMIC_DRAW, indices.length);
        }
    }

    /**
     * Upload partial vertex data to GPU using bufferSubData for optimal performance
     * Perfect for tilemap updates, particle effects, and dynamic content
     * @param vbo Vertex buffer object
     * @param offsetInFloats Offset in floats (not bytes)
     * @param vertices Vertex data to upload
     */
    public function uploadVertexDataPartial(vbo:UInt, offsetInFloats:Int, vertices:Array<Float>):Void {
        trace("Renderer.uploadVertexDataPartial: vbo=" + vbo + " offset=" + offsetInFloats + " vertices.length=" + vertices.length);
        
        // Validate parameters
        if (vbo == 0) {
            trace("Error: Invalid VBO ID (0)");
            return;
        }
        
        if (vertices.length == 0) {
            trace("Warning: Empty vertex array passed to uploadVertexDataPartial");
            return;
        }
        
        if (offsetInFloats < 0) {
            trace("Error: Negative offset not allowed");
            return;
        }
        
        // Debug info
        if (vertices.length > 0) {
            trace("  Partial update - first 5 values: " + vertices.slice(0, 5));
        }
        
        // Bind buffer for update
        GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
        
        // Calculate byte offset (floats * 4 bytes per float)
        var byteOffset = offsetInFloats * 4;
        
        try {
            // Use the optimized GL bufferSubFloatArray method
            GL.bufferSubFloatArray(GL.ARRAY_BUFFER, byteOffset, vertices, vertices.length);
            trace("  Uploaded " + vertices.length + " floats at byte offset " + byteOffset);
        } catch (e:Dynamic) {
            trace("Error uploading vertex data: " + e);
        }
        
        // Unbind buffer
        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
    }

    /**
     * Upload partial index data to GPU using bufferSubData for optimal performance
     * @param ebo Element buffer object
     * @param offsetInIndices Offset in indices (not bytes)
     * @param indices Index data to upload
     */
    public function uploadIndexDataPartial(ebo:UInt, offsetInIndices:Int, indices:Array<Int>):Void {
        trace("Renderer.uploadIndexDataPartial: ebo=" + ebo + " offset=" + offsetInIndices + " indices.length=" + indices.length);
        
        // Validate parameters
        if (ebo == 0) {
            trace("Error: Invalid EBO ID (0)");
            return;
        }
        
        if (indices.length == 0) {
            trace("Warning: Empty index array passed to uploadIndexDataPartial");
            return;
        }
        
        if (offsetInIndices < 0) {
            trace("Error: Negative offset not allowed");
            return;
        }
        
        // Debug info
        if (indices.length > 0) {
            trace("  Partial update - first 5 values: " + indices.slice(0, 5));
        }
        
        // Bind buffer for update
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
        
        // Calculate byte offset (indices * 4 bytes per int)
        var byteOffset = offsetInIndices * 4;
        
        try {
            // Convert to UInt array for GL call
            var uintIndices:Array<UInt> = [];
            for (index in indices) {
                if (index < 0) {
                    throw "Negative index value not allowed: " + index;
                }
                uintIndices.push(index);
            }
            
            // Use the optimized GL bufferSubData method
            GL.bufferSubIntArray(GL.ELEMENT_ARRAY_BUFFER, byteOffset, uintIndices, uintIndices.length);
            trace("  Uploaded " + indices.length + " indices at byte offset " + byteOffset);
        } catch (e:Dynamic) {
            trace("Error uploading index data: " + e);
        }
        
        // Unbind buffer
        GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, 0);
    }

    // TODO: programInfo.setupVertexAttributes(this); This must be called in the beginning of the draw. Now it is called for every DisplayObject.
    /**
     * Set up vertex attributes and finalize buffer setup
     */
    public function setupVertexAttributes(programInfo:ProgramInfo):Void {
        //GL.bindVertexArray(programInfo.vao);
        programInfo.setupVertexAttributes(this);
        GL.bindVertexArray(0);
        // Unbind buffers
        //GL.bindBuffer(GL.ARRAY_BUFFER, 0); // TODO: We got bind and unbind separated. Union in 1 function.
        //GL.bindVertexArray(0);
    }

    /**
     * Delete OpenGL buffers - cleanup
     */
    public function deleteBuffers(vao:UInt, vbo:UInt, ebo:UInt):Void {
        if (vao != 0) {
            var vaoArray = [vao];
            GL.deleteVertexArrays(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vaoArray));
        }
        if (vbo != 0) {
            var vboArray = [vbo];
            GL.deleteBuffers(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vboArray));
        }
        if (ebo != 0) {
            var eboArray = [ebo];
            GL.deleteBuffers(1, untyped __cpp__("(const unsigned int*)&{0}[0]", eboArray));
        }
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
        
        var textureArray:Array<UInt> = [0];
        GL.genTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", textureArray));
        var textureId:UInt = textureArray[0];
        
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
        
        // Convert UInt8Array to Bytes for OpenGL upload
        var bytes = haxe.io.Bytes.alloc(textureData.width * textureData.height * textureData.bytesPerPixel);
        for (i in 0...bytes.length) {
            bytes.set(i, textureData.bytes[i]);
        }
        
        untyped __cpp__("glTexImage2D(GL_TEXTURE_2D, 0, {0}, {1}, {2}, 0, {3}, GL_UNSIGNED_BYTE, (unsigned char*){4}->b->GetBase())", 
            internalFormat, textureData.width, textureData.height, format, bytes);
        
        // Debug output for texture format
        trace("Texture uploaded: " + textureData.width + "x" + textureData.height + ", BPP=" + textureData.bytesPerPixel + 
              ", internalFormat=" + internalFormat + ", format=" + format);
        
        // Unbind texture
        GL.bindTexture(GL.TEXTURE_2D, 0);
        
        // Create and return Texture object
        var texture:Texture = {
            id: textureId,
            width: textureData.width,
            height: textureData.height,
            bpp: textureData.bytesPerPixel,
            target: GL.TEXTURE_2D
        };
        trace("Uploaded texture: ID=" + texture.id + " Size=" + texture.width + "x" + texture.height);
        return texture;
    }

    public function release():Void {
        // Reset render state
        setDepthTest(true);
        setDepthWrite(true);
        setBlendMode(false);
        
        // Cleanup all registered ProgramInfos
        for (name in programInfos.keys()) {
            var programInfo = programInfos.get(name);
            if (programInfo != null) {
                programInfo.dispose(this);
                trace("Disposed ProgramInfo: " + name);
            }
        }
        programInfos.clear();
        
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
                // For now, use direct call until BLEND constant is added
                untyped __cpp__("glEnable(GL_BLEND)");
                GL.blendFunc(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA);
            } else {
                untyped __cpp__("glDisable(GL_BLEND)");
            }
            __currentBlendMode = enabled;
        }
    }
    
    public function pushRenderState():RenderState {
        return {
            depthTest: __currentDepthTest,
            depthWrite: __currentDepthWrite,
            blendMode: __currentBlendMode
        };
    }
    
    public function popRenderState(state:RenderState):Void {
        setDepthTest(state.depthTest);
        setDepthWrite(state.depthWrite);
        setBlendMode(state.blendMode);
    }

    
    // ===== SHADER WRAPPER FUNCTIONS =====
    // These functions are used by ProgramInfo for shader compilation
    // TODO: Consider having ProgramInfo call GL directly instead
    
    public function createShader(type:Int):Int {
        return GL.createShader(type);
    }

    public function shaderSource(shader:Int, source:String):Void {
        untyped __cpp__("\n            const char* shaderSource = {1}.__s;\n            glShaderSource({0}, 1, &shaderSource, NULL);\n        ", shader, source);
    }

    public function compileShader(shader:Int):Void {
        GL.compileShader(shader);
    }

    public function createProgram():Int {
        return GL.createProgram();
    }

    public function attachShader(program:Int, shader:Int):Void {
        GL.attachShader(program, shader);
    }

    public function linkProgram(program:Int):Void {
        GL.linkProgram(program);
    }

    public function useProgram(program:Int):Void {
        GL.useProgram(program);
    }

    public function deleteShader(shader:Int):Void {
        GL.deleteShader(shader);
    }

    public function getAttribLocation(program:Int, name:String):Int {
        return GL.getAttribLocation(program, name);
    }

    public function getUniformLocation(program:Int, name:String):Int {
        return GL.getUniformLocation(program, name);
    }

    public function enableVertexAttribArray(index:Int):Void {
        GL.enableVertexAttribArray(index);
    }

    // ===== DEPRECATED / UNUSED FUNCTIONS =====
    // These functions are kept for reference but are no longer used in the current architecture
    
    /*
    // No-op function that was kept for compatibility
    private function __renderAttributes(programInfo:ProgramInfo):Void {
        // Attributes are already set up in VAO, so this is essentially a no-op
        // for our current VAO-based implementation, but kept for compatibility
    }
    */

    // Getters and setters
    private function get_app():App {
        return __app;
    }

    // ** Helper: Convert AttributeFormat to GL constant for rendering
	private function getGLFormat(format:AttributeFormat):Int {
		return switch (format) {
			case AttributeFormat.Float | AttributeFormat.Vec2 | AttributeFormat.Vec3 | AttributeFormat.Vec4: 5126; // GL_FLOAT
			case AttributeFormat.Int: 5124;          // GL_INT
			case AttributeFormat.UnsignedInt: 5125;  // GL_UNSIGNED_INT
			case AttributeFormat.Byte: 5120;         // GL_BYTE
			case AttributeFormat.UnsignedByte: 5121; // GL_UNSIGNED_BYTE
			case AttributeFormat.Short: 5122;        // GL_SHORT
			case AttributeFormat.UnsignedShort: 5123;// GL_UNSIGNED_SHORT
		}
	}

    // ** Shader compilation and linking
	public function compileProgramInfo(programInfo:ProgramInfo):Bool {
		if (programInfo.isCompiled) return true;
		
		// Vertex shader
		programInfo.vertexShader = createShader(GL.VERTEX_SHADER);
		shaderSource(programInfo.vertexShader, programInfo.vertexShaderSource);
		compileShader(programInfo.vertexShader);
		if (!checkShaderCompilation(programInfo.vertexShader, "Vertex")) {
			trace("Vertex shader compilation failed!");
			return false;
		}
		
		// Fragment shader
		programInfo.fragmentShader = createShader(GL.FRAGMENT_SHADER);
		shaderSource(programInfo.fragmentShader, programInfo.fragmentShaderSource);
		compileShader(programInfo.fragmentShader);
		if (!checkShaderCompilation(programInfo.fragmentShader, "Fragment")) {
			trace("Fragment shader compilation failed!");
			return false;
		}

		// Create and link program
		programInfo.program = createProgram();
		
		attachShader(programInfo.program, programInfo.vertexShader);
		attachShader(programInfo.program, programInfo.fragmentShader);
		linkProgram(programInfo.program);
		
		// Check program linking
		if (!checkProgramLinking(programInfo.program)) {
			return false;
		}
		
		programInfo.isCompiled = true;
		return true;
	}

    private function checkShaderCompilation(shader:Int, type:String):Bool {
		var success:Int = GL.getShaderParameterValue(shader, GL.COMPILE_STATUS);
		
		if (success == 0) {
			// Compilation failed, get error log
			var errorLog:String = GL.getShaderInfoLogString(shader);
			
			if (errorLog.length > 0) {
				trace(type + " shader compilation failed:");
				trace(errorLog);
			} else {
				trace(type + " shader compilation failed with no error log");
			}
			return false;
		}
		
		trace(type + " shader compiled successfully");
		return true;
	}

	private function checkProgramLinking(program:Int):Bool {
		var success:Int = GL.getProgramParameterValue(program, GL.LINK_STATUS);
		
		if (success == 0) {
			// Linking failed, get error log
			var errorLog:String = GL.getProgramInfoLogString(program);
			
			if (errorLog.length > 0) {
				trace("Program linking failed:");
				trace(errorLog);
			} else {
				trace("Program linking failed with no error log");
			}
			return false;
		}
		
		trace("Program linked successfully");
		return true;
	}
	
	// =============================================================================
	// FRAMEBUFFER AND POST-PROCESSING
	// =============================================================================
	
	/**
	 * Initialize the post-processing framebuffer and fullscreen quad
	 */
	public function initializePostProcessing():Void {
		// Create framebuffer and texture
		createFramebuffer(windowWidth, windowHeight);
		
		// Create fullscreen quad for rendering
		createFullscreenQuad();
		
		// Create default post-process shader (passthrough)
		var vertShader = '
			#version 330 core
			layout (location = 0) in vec2 aPos;
			layout (location = 1) in vec2 aTexCoord;
			out vec2 TexCoord;
			
			void main() {
				gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
				TexCoord = aTexCoord;
			}
		';
		
		var fragShader = '
			#version 330 core
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
	
	/**
	 * Create framebuffer with color texture attachment
	 */
	private function createFramebuffer(width:Int, height:Int):Void {
		// Create framebuffer
		screenFBO = GL.createFramebuffer();
		GL.bindFramebuffer(GL.FRAMEBUFFER, screenFBO);
		
		// Create color texture
		screenTexture = GL.createTexture();
		GL.bindTexture(GL.TEXTURE_2D, screenTexture);
		GL.texImage2D(GL.TEXTURE_2D, 0, GL.RGBA, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.LINEAR);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
		GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
		
		// Attach texture to framebuffer
		GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, screenTexture, 0);
		
		// Check framebuffer status
		if (GL.checkFramebufferStatus(GL.FRAMEBUFFER) != GL.FRAMEBUFFER_COMPLETE) {
			trace("ERROR: Framebuffer is not complete!");
		}
		
		// Unbind framebuffer
		GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
		
		trace("Renderer: Created framebuffer " + width + "x" + height);
	}
	
	/**
	 * Create a fullscreen quad (2 triangles)
	 */
	private function createFullscreenQuad():Void {
		// Fullscreen quad vertices: position (x,y) + texcoord (u,v)
		var quadVertices:Array<Float> = [
			// positions  // texCoords
			-1.0,  1.0,  0.0, 1.0, // top-left
			-1.0, -1.0,  0.0, 0.0, // bottom-left
			 1.0, -1.0,  1.0, 0.0, // bottom-right
			 1.0,  1.0,  1.0, 1.0  // top-right
		];
		
		var quadIndices:Array<UInt> = [
			0, 1, 2, // first triangle
			0, 2, 3  // second triangle
		];
		
		// Create VAO
		__fullscreenQuadVAO = GL.createVertexArray();
		GL.bindVertexArray(__fullscreenQuadVAO);
		
		// Create VBO
		__fullscreenQuadVBO = GL.createBuffer();
		GL.bindBuffer(GL.ARRAY_BUFFER, __fullscreenQuadVBO);
		
		// Convert vertex array to bytes
		var vertexBytes = haxe.io.Bytes.alloc(quadVertices.length * 4);
		for (i in 0...quadVertices.length) {
			vertexBytes.setFloat(i * 4, quadVertices[i]);
		}
		GL.bufferData(GL.ARRAY_BUFFER, vertexBytes.length, vertexBytes.getData(), GL.STATIC_DRAW);
		
		// Create EBO
		var ebo = GL.createBuffer();
		GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
		
		// Convert index array to bytes
		var indexBytes = haxe.io.Bytes.alloc(quadIndices.length * 4);
		for (i in 0...quadIndices.length) {
			indexBytes.setInt32(i * 4, quadIndices[i]);
		}
        
		GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indexBytes.length, indexBytes.getData(), GL.STATIC_DRAW);
		
		// Position attribute
		
        GL.vertexAttribPointer(0, 2, GL.FLOAT, false, 4 * 4, untyped __cpp__("(void*)0")); // 4 floats per vertex, stride = 16 bytes

		GL.enableVertexAttribArray(0);
		
		// TexCoord attribute
		GL.vertexAttribPointer(1, 2, GL.FLOAT, false, 4 * 4, untyped __cpp__("(void*){0}", 2 * 4)); // offset = 8 bytes
		GL.enableVertexAttribArray(1);
		
		GL.bindVertexArray(0);
		
		trace("Renderer: Created fullscreen quad");
	}
	
	/**
	 * Bind the framebuffer for rendering
	 */
	public function bindFramebuffer():Void {
		GL.bindFramebuffer(GL.FRAMEBUFFER, screenFBO);
		GL.viewport(0, 0, windowWidth, windowHeight);
	}
	
	/**
	 * Unbind the framebuffer (render to screen)
	 */
	public function unbindFramebuffer():Void {
		GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
		GL.viewport(0, 0, windowWidth, windowHeight);
	}
	
	/**
	 * Render the framebuffer texture to screen with post-process shader
	 */
	public function renderToScreen():Void {
		// Use post-process shader
		GL.useProgram(postProcessShader.program);
		
		// Bind screen texture
		GL.activeTexture(GL.TEXTURE0);
		GL.bindTexture(GL.TEXTURE_2D, screenTexture);
		
		// Set uniform
		var uniformInfo = postProcessShader.getUniform("uScreenTexture");
		if (uniformInfo != null) {
			uniformInfo.setter(uniformInfo.location, 0);
		}
		
		// Render fullscreen quad
		GL.bindVertexArray(__fullscreenQuadVAO);
		GL.drawElements(GL.TRIANGLES, 6, GL.UNSIGNED_INT, 0);
		GL.bindVertexArray(0);
	}
}