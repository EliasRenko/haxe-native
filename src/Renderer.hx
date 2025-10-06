package;

import GL;
import ProgramInfo;
import DisplayObject;
import data.TextureData;
import Texture;
import math.Matrix;

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
    
    public function new(app:App, windowWidth:Int, windowHeight:Int) {
        this.__app = app;
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
    }
    
    public function render():Void {
        frameCount++; // Increment frame counter for debug timing
        
        // Clear screen and depth buffer
        clearScreen();
        
        // Initialize rendering state
        initializeRenderState();
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

        if (displayObject.vertices.length == 0) {
            return;
        }

        // Use the program
        GL.useProgram(displayObject.programInfo.program);

        // Bind VAO
        GL.bindVertexArray(displayObject.vao);

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
     * Register a ProgramInfo with the renderer
     * This allows States to create and register their ProgramInfos
     */
    public function registerProgramInfo(name:String, programInfo:ProgramInfo):Void {
        if (programInfos.exists(name)) {
            // TODO: Convert to proper logging system once cross-class access is resolved
            // trace("Warning: ProgramInfo '" + name + "' already exists, replacing...");
        }
        programInfos.set(name, programInfo);
        // TODO: Convert to proper logging system once cross-class access is resolved
        // trace("Registered ProgramInfo: " + name);
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
     * Create and manage OpenGL buffers for display objects
     */
    public function createBuffers(vertexCount:Int, indexCount:Int):{vao:UInt, vbo:UInt, ebo:UInt} {
        var vao:UInt = 0;
        var vbo:UInt = 0; 
        var ebo:UInt = 0;

        // Generate VAO
        var vaoArray = [vao];
        GL.genVertexArrays(1, untyped __cpp__("(unsigned int*)&{0}[0]", vaoArray));
        vao = vaoArray[0];

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

    /**
     * Upload vertex data to GPU
     */
    public function uploadVertexData(vao:UInt, vbo:UInt, vertices:Array<Float>):Void {
        trace("Renderer.uploadVertexData: vao=" + vao + " vbo=" + vbo + " vertices.length=" + vertices.length);
        if (vertices.length > 0) {
            trace("  First 15 vertex values: " + vertices.slice(0, 15));
        }
        
        GL.bindVertexArray(vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
        
        // Convert vertex array to bytes
        var vertexBytes = haxe.io.Bytes.alloc(vertices.length * 4);
        for (i in 0...vertices.length) {
            vertexBytes.setFloat(i * 4, vertices[i]);
        }
        
        trace("  Uploading " + vertexBytes.length + " bytes to VBO " + vbo);
        GL.bufferData(GL.ARRAY_BUFFER, vertexBytes.length, vertexBytes.getData(), GL.DYNAMIC_DRAW);
        trace("  Buffer upload complete");
    }

    /**
     * Upload index data to GPU
     */
    public function uploadIndexData(ebo:UInt, indices:Array<Int>):Void {
        trace("Renderer.uploadIndexData: ebo=" + ebo + " indices.length=" + indices.length);
        if (indices.length > 0) {
            trace("  First 15 index values: " + indices.slice(0, 15));
        }
        
        if (ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
            var indexBytes = haxe.io.Bytes.alloc(indices.length * 4);
            for (i in 0...indices.length) {
                indexBytes.setInt32(i * 4, indices[i]);
            }
            
            trace("  Uploading " + indexBytes.length + " bytes to EBO " + ebo);
            GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indexBytes.length, indexBytes.getData(), GL.DYNAMIC_DRAW);
            trace("  Index buffer upload complete");
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
        if (vertices.length > 0) {
            trace("  Partial update - first 5 values: " + vertices.slice(0, 5));
        }
        
        if (vbo != 0 && vertices.length > 0) {
            GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
            
            // Calculate byte offset (floats * 4 bytes per float)
            var byteOffset = offsetInFloats * 4;
            
            // Use the optimized GL bufferSubData method
            GL.bufferSubFloatArray(GL.ARRAY_BUFFER, byteOffset, vertices, vertices.length);
            
            trace("  Uploaded " + vertices.length + " floats at byte offset " + byteOffset);
        }
    }

    /**
     * Upload partial index data to GPU using bufferSubData for optimal performance
     * @param ebo Element buffer object
     * @param offsetInIndices Offset in indices (not bytes)
     * @param indices Index data to upload
     */
    public function uploadIndexDataPartial(ebo:UInt, offsetInIndices:Int, indices:Array<Int>):Void {
        trace("Renderer.uploadIndexDataPartial: ebo=" + ebo + " offset=" + offsetInIndices + " indices.length=" + indices.length);
        if (indices.length > 0) {
            trace("  Partial update - first 5 values: " + indices.slice(0, 5));
        }
        
        if (ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
            
            // Calculate byte offset (indices * 4 bytes per int)
            var byteOffset = offsetInIndices * 4;
            
            // Convert to UInt array for GL call
            var uintIndices:Array<UInt> = [];
            for (index in indices) {
                uintIndices.push(index);
            }
            
            // Use the optimized GL bufferSubData method
            GL.bufferSubIntArray(GL.ELEMENT_ARRAY_BUFFER, byteOffset, uintIndices, uintIndices.length);
            
            trace("  Uploaded " + indices.length + " indices at byte offset " + byteOffset);
        }
    }

    /**
     * Set up vertex attributes and finalize buffer setup
     */
    public function setupVertexAttributes(programInfo:ProgramInfo):Void {
        programInfo.setupVertexAttributes(this);
        // Unbind buffers
        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
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



    public function vertexAttribPointer(index:Int, size:Int, type:Int, normalized:Bool, stride:Int, offset:Int):Void {
        untyped __cpp__("glVertexAttribPointer({0}, {1}, {2}, {3} ? GL_TRUE : GL_FALSE, {4}, (void*)(intptr_t){5})", 
            index, size, type, normalized, stride, offset);
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
        
        // Upload actual texture data
        var format = GL.RGBA;
        var internalFormat = GL.RGBA;
        
        // Convert UInt8Array to Bytes for OpenGL upload
        var bytes = haxe.io.Bytes.alloc(textureData.width * textureData.height * textureData.bytesPerPixel);
        for (i in 0...bytes.length) {
            bytes.set(i, textureData.bytes[i]);
        }
        
        untyped __cpp__("glTexImage2D(GL_TEXTURE_2D, 0, {0}, {1}, {2}, 0, {3}, GL_UNSIGNED_BYTE, (unsigned char*){4}->b->GetBase())", 
            internalFormat, textureData.width, textureData.height, format, bytes);
        
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


    // 

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
}