package;

import GL;
import ProgramInfo;

class Renderer {
    
    private var shaderProgram:GlUInt;
    private var vbo:GlUInt;
    private var vao:GlUInt;
    
    // Test triangle
    private var testProgram:ProgramInfo;
    private var testVAO:GlUInt;
    private var testVBO:GlUInt;
    private var testInitialized:Bool = false;
    
    public function new(windowWidth:Int, windowHeight:Int) {
        trace("Creating clean renderer...");
        initializeTestTriangle();
        trace("Clean renderer initialized!");
    }
    
    public function render():Void {
        // Clear screen to gray
        GL.glClearColor(0.6, 0.6, 0.6, 1.0);
        GL.glClear(GL.COLOR_BUFFER_BIT);
        
        // Render test triangle
        renderTestTriangle();
    }
    
    private function initializeTestTriangle():Void {
        trace("Initializing test triangle...");
        
        // Create ProgramInfo with simple vertex/fragment shaders
        // This automatically compiles and introspects the shader program!
        testProgram = new ProgramInfo("TestTriangle", getTestVertexShader(), getTestFragmentShader());
        
        // Print debug info about the introspected program
        testProgram.printVertexLayout();
        
        // Create vertex data (interleaved: pos.x, pos.y, pos.z, color.r, color.g, color.b)
        trace("Creating vertex data...");
        var vertices = [
            // Triangle vertices with colors
             0.0,  0.5, 0.0,  1.0, 0.0, 0.0,  // Top vertex - Red
            -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // Bottom left - Green  
             0.5, -0.5, 0.0,  0.0, 0.0, 1.0   // Bottom right - Blue
        ];
        trace("Vertex data created with " + vertices.length + " floats");
        
        // Generate VAO and VBO using proper GL calls
        trace("Generating VAO and VBO...");
        var vaoArray = new Array<GlUInt>();
        vaoArray.resize(1);
        GL.genVertexArrays(1, untyped __cpp__("(unsigned int*)&{0}[0]", vaoArray));
        testVAO = vaoArray[0];
        trace("VAO generated: " + testVAO);
        
        var vboArray = new Array<GlUInt>();
        vboArray.resize(1);
        GL.genBuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", vboArray));
        testVBO = vboArray[0];
        trace("VBO generated: " + testVBO);
        
        // Bind VAO first
        trace("Binding VAO: " + testVAO);
        GL.bindVertexArray(testVAO);
        
        // Bind and fill VBO with proper data conversion
        trace("Binding VBO: " + testVBO);
        GL.bindBuffer(GL.ARRAY_BUFFER, testVBO);
        
        trace("Converting vertex data to bytes...");
        var vertexBytes = haxe.io.Bytes.alloc(vertices.length * 4);
        for (i in 0...vertices.length) {
            vertexBytes.setFloat(i * 4, vertices[i]);
        }
        trace("Uploading " + vertexBytes.length + " bytes to GPU...");
        GL.bufferData(GL.ARRAY_BUFFER, vertexBytes.length, vertexBytes.getData(), GL.STATIC_DRAW);
        
        // Setup vertex attributes using our ProgramInfo
        trace("Setting up vertex attributes...");
        testProgram.setupVertexAttributes();
        
        // Unbind
        trace("Unbinding buffers...");
        GL.bindBuffer(GL.ARRAY_BUFFER, 0);
        GL.bindVertexArray(0);
        
        testInitialized = true;
        trace("Test triangle initialized successfully!");
    }
    
    private function renderTestTriangle():Void {
        if (!testInitialized) return;
        
        // Use our shader program
        GL.useProgram(testProgram.program);
        
        // Set time uniform for animation (time in seconds since start)
        var currentTime = (SDL.getTicks() : Float) / 1000.0; // Convert milliseconds to seconds
        testProgram.setUniformFloat("uTime", currentTime);
        
        // Bind VAO and draw
        GL.bindVertexArray(testVAO);
        GL.drawArrays(GL.TRIANGLES, 0, 3);
        GL.bindVertexArray(0);
    }
    
    private function getTestVertexShader():String {
        return '
        #version 330 core
        layout (location = 0) in vec3 aPos;
        layout (location = 1) in vec3 aColor;
        
        out vec3 vertexColor;
        
        uniform float uTime;
        
        void main() {
            // Animate the triangle by rotating it based on time
            float angle = uTime * 2.0;
            float cosA = cos(angle);
            float sinA = sin(angle);
            
            // Simple 2D rotation matrix
            vec3 rotatedPos = vec3(
                aPos.x * cosA - aPos.y * sinA,
                aPos.x * sinA + aPos.y * cosA,
                aPos.z
            );
            
            gl_Position = vec4(rotatedPos, 1.0);
            vertexColor = aColor;
        }
        ';
    }
    
    private function getTestFragmentShader():String {
        return '
        #version 330 core
        in vec3 vertexColor;
        out vec4 FragColor;
        
        void main() {
            FragColor = vec4(vertexColor, 1.0);
        }
        ';
    }
    
    public function cleanup():Void {
        // Cleanup test triangle
        if (testInitialized) {
            if (testVAO != 0) {
                var vaoArray = [testVAO];
                GL.deleteVertexArrays(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vaoArray));
            }
            if (testVBO != 0) {
                var vboArray = [testVBO];  
                GL.deleteBuffers(1, untyped __cpp__("(const unsigned int*)&{0}[0]", vboArray));
            }
            if (testProgram != null) testProgram.dispose();
        }
        
        // Simple cleanup for now - just shader if it exists
        if (shaderProgram != 0) {
            GL.deleteShader(shaderProgram);
        }
        trace("Renderer cleanup complete");
    }
}
