package;

import GL;
import ProgramInfo;
import DisplayObject;
import display.Image;
import display.Triangle;
import display.Rectangle;
import display.Quad;
import display.Cube;
import data.TextureData;
import Camera;
import math.Matrix;

class Renderer {
    
    // App reference with controlled access
    public var app(get, null):App;
    
    // Window dimensions - exposed for camera calculations
    public var windowWidth:Int;
    public var windowHeight:Int;
    
    private var __app:App;
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
        
        // Debug: Print frame info occasionally
        if (frameCount % 300 == 0) { // Every 5 seconds
            trace("Frame: " + frameCount + ", Window: " + windowWidth + "x" + windowHeight);
        }
    }
    
    // ** New method to render display objects with provided view-projection matrix
    public function renderDisplayObject(displayObject:DisplayObject, viewProjectionMatrix:math.Matrix):Void {
        if (!displayObject.visible) return;
        
        // Update buffers if needed
        if (displayObject.needsBufferUpdate) {
            displayObject.updateBuffers(this);
        }
        
        // Render the display object with the provided view-projection matrix
        // The DisplayObject will combine this with its model matrix
        displayObject.render(viewProjectionMatrix, this);
    }
    
    /**
     * Register a ProgramInfo with the renderer
     * This allows States to create and register their ProgramInfos
     */
    public function registerProgramInfo(name:String, programInfo:ProgramInfo):Void {
        if (programInfos.exists(name)) {
            trace("Warning: ProgramInfo '" + name + "' already exists, replacing...");
        }
        programInfos.set(name, programInfo);
        trace("Registered ProgramInfo: " + name);
    }
    
    /**
     * Create and register a ProgramInfo if it doesn't exist, or return existing one
     * This is the proper way for States to request ProgramInfos from Renderer
     */
    public function createProgramInfo(name:String, vertexShader:String, fragmentShader:String):ProgramInfo {
        // Check if this ProgramInfo already exists
        if (programInfos.exists(name)) {
            trace("ProgramInfo '" + name + "' already exists, reusing...");
            return programInfos.get(name);
        }
        
        // Create new ProgramInfo and register it
        var programInfo = new ProgramInfo(name, this, vertexShader, fragmentShader);
        programInfos.set(name, programInfo);
        
        trace("Created and registered ProgramInfo: " + name);
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

        // Generate EBO if we need indices
        if (indexCount > 0) {
            var eboArray = [ebo];
            GL.genBuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", eboArray));
            ebo = eboArray[0];
        }

        return {vao: vao, vbo: vbo, ebo: ebo};
    }

    /**
     * Upload vertex data to GPU
     */
    public function uploadVertexData(vao:UInt, vbo:UInt, vertices:Array<Float>):Void {
        GL.bindVertexArray(vao);
        GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
        
        // Convert vertex array to bytes
        var vertexBytes = haxe.io.Bytes.alloc(vertices.length * 4);
        for (i in 0...vertices.length) {
            vertexBytes.setFloat(i * 4, vertices[i]);
        }
        GL.bufferData(GL.ARRAY_BUFFER, vertexBytes.length, vertexBytes.getData(), GL.DYNAMIC_DRAW);
    }

    /**
     * Upload index data to GPU
     */
    public function uploadIndexData(ebo:UInt, indices:Array<Int>):Void {
        if (ebo != 0 && indices.length > 0) {
            GL.bindBuffer(GL.ELEMENT_ARRAY_BUFFER, ebo);
            var indexBytes = haxe.io.Bytes.alloc(indices.length * 4);
            for (i in 0...indices.length) {
                indexBytes.setInt32(i * 4, indices[i]);
            }
            GL.bufferData(GL.ELEMENT_ARRAY_BUFFER, indexBytes.length, indexBytes.getData(), GL.DYNAMIC_DRAW);
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
     * Set rendering state for 2D rendering
     */
    public function set2DRenderState():Void {
        GL.glDisable(GL.DEPTH_TEST);
    }

    /**
     * Set rendering state for 3D rendering  
     */
    public function set3DRenderState():Void {
        GL.glEnable(GL.DEPTH_TEST);
        GL.glDepthFunc(GL.LESS);
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
        GL.glEnable(GL.DEPTH_TEST);
        GL.glDepthFunc(GL.LESS);
        
        // Disable face culling to see all faces from all angles
        GL.glDisable(GL.CULL_FACE);
    }

    /**
     * Shader compilation and management methods
     */
    public function createShader(type:Int):Int {
        return GL.createShader(type);
    }

    public function shaderSource(shader:Int, source:String):Void {
        untyped __cpp__("
            const char* shaderSource = {1}.__s;
            glShaderSource({0}, 1, &shaderSource, NULL);
        ", shader, source);
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

    public function vertexAttribPointer(index:Int, size:Int, type:Int, normalized:Bool, stride:Int, offset:Int):Void {
        untyped __cpp__("glVertexAttribPointer({0}, {1}, {2}, {3} ? GL_TRUE : GL_FALSE, {4}, (void*)(intptr_t){5})", 
            index, size, type, normalized, stride, offset);
    }

    public function uniform1i(location:Int, value:Int):Void {
        GL.uniform1i(location, value);
    }

    public function uniform1f(location:Int, value:Float):Void {
        GL.uniform1f(location, value);
    }

    public function uniformMatrix4fv(location:Int, transpose:Bool, value:Array<Float>):Void {
        // Create a copy to ensure proper memory layout
        var matrixData = new Array<Float>();
        for (i in 0...16) {
            matrixData[i] = value[i];
        }
        
        // Use transpose=false for column-major OpenGL matrix format
        untyped __cpp__("
            float matData[16];
            for(int i = 0; i < 16; i++) {
                matData[i] = {2}[i];
            }
            glUniformMatrix4fv({0}, 1, {1} ? GL_TRUE : GL_FALSE, matData);
        ", location, transpose, matrixData);
    }

    public function cleanup():Void {
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
     * Get app reference
     */
    private function get_app():App {
        return __app;
    }

}