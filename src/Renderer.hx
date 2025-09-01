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
    
    private var app:App;
    private var shaderProgram:GlUInt;
    private var vbo:GlUInt;
    private var vao:GlUInt;
    
    // Camera for world and projection matrices
    private var camera:Camera;
    private var windowWidth:Int;
    private var windowHeight:Int;
    
    // Frame counter for debug output
    private var frameCount:Int = 0;
    
    // DisplayObjects
    private var testTriangle:Triangle;
    private var triangleProgram:ProgramInfo;
    
    // Test rectangle using DisplayObject architecture
    private var testRectangle:Rectangle;
    private var rectangleProgram:ProgramInfo;
    
    // Test textured quad using DisplayObject architecture
    private var testQuad:Quad;
    private var quadProgram:ProgramInfo;
    
    // Test 3D cube using DisplayObject architecture
    private var testCube:Cube;
    private var cubeProgram:ProgramInfo;
    
    // Background rectangle for 2D/3D testing
    private var backgroundRect:Rectangle;
    private var backgroundProgram:ProgramInfo;
    
    // Test image using DisplayObject architecture
    private var testImage:Image;
    private var imageProgram:ProgramInfo;
    
    public function new(app:App, windowWidth:Int, windowHeight:Int) {
        trace("Creating clean renderer...");
        this.app = app;
        this.windowWidth = windowWidth;
        this.windowHeight = windowHeight;
        
        // Initialize camera with explicit values for debugging
        camera = new Camera();
        camera.ortho = true; // Use orthographic projection for 2D
        camera.x = 0.0;
        camera.y = 0.0; 
        camera.z = 0.0;
        camera.pitch = 0.0;
        camera.yaw = 0.0;
        camera.roll = 0.0;
        
        initializeTestTriangle();
        initializeTestRectangle();
        initializeTestQuad();
        initializeTestCube();
        initializeBackgroundRect();
        //initializeTestImage();
        trace("Clean renderer initialized!");
    }
    
    public function render():Void {
        frameCount++; // Increment frame counter for debug timing
        
        // Clear screen and depth buffer
        GL.glClearColor(0.1, 0.1, 0.15, 1.0); // Very dark background for 3D focus
        GL.glClear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
        
        // Enable depth testing for 3D
        GL.glEnable(GL.DEPTH_TEST);
        GL.glDepthFunc(GL.LESS);
        
        // Disable face culling to see all faces from all angles
        GL.glDisable(GL.CULL_FACE);

        // Use perspective projection for 3D cube
        camera.ortho = false;
        camera.x = 0; // Center camera on X axis
        camera.y = 0; // Center camera on Y axis  
        camera.z = 5; // Move camera back to see the cube clearly
        
        // Render background rectangle first (behind the 3D cube)
        if (backgroundRect != null) {
            // Temporarily disable depth testing for the rectangle to ensure it's visible
            GL.glDisable(GL.DEPTH_TEST);
            renderDisplayObject(backgroundRect);
            GL.glEnable(GL.DEPTH_TEST); // Re-enable for 3D cube
        }
        
        // Render only the 3D cube at center with clean Y-axis rotation
        if (testCube != null) {
            // Center the cube
            testCube.x = 0.0;
            testCube.y = 0.0;
            testCube.z = 0.0;
            
            // Simple Y-axis rotation like typical 3D demos (no X/Z rotation)
            var time = haxe.Timer.stamp();
            var rotY = (time * 0.3) % (2 * Math.PI); // Slower Y rotation, wrapped to 0-2π
            
            testCube.rotationX = 0.0; // No X rotation
            testCube.rotationY = rotY; // Only Y-axis rotation
            testCube.rotationZ = 0.0; // No Z rotation
            
            // Debug: Print current rotation values occasionally
            if (frameCount % 300 == 0) { // Every 5 seconds
                trace("Cube Y rotation: " + testCube.rotationY + " (clean Y-axis spin)");
                trace("Raw time: " + time + " (wrapped rotation prevents precision issues)");
                trace("Camera position: X=" + camera.x + ", Y=" + camera.y + ", Z=" + camera.z);
                trace("Camera ortho=" + camera.ortho + ", fov=" + camera.fov);
            } 
            // testCube.rotationZ = 0.2; // Fixed small Z rotation
            
            renderDisplayObject(testCube);
        }
    }
    
    // ** New method to render display objects
    public function renderDisplayObject(displayObject:DisplayObject):Void {
        if (!displayObject.visible) return;
        
        // Initialize the display object if not already done
        if (!displayObject.initialized) {
            displayObject.init();
        }
        
        // Calculate the camera matrix (world + projection)
        camera.renderMatrix(windowWidth, windowHeight);
        var cameraMatrix = camera.getMatrix();
        
        // Render the display object with the camera matrix
        displayObject.render(cameraMatrix);
    }    private function initializeTestTriangle():Void {
        trace("Initializing test triangle using DisplayObject architecture...");
        
        // Create ProgramInfo with triangle shaders and automatic introspection
        triangleProgram = new ProgramInfo("TestTriangle", Triangle.getVertexShader(), Triangle.getFragmentShader());
        
        // Print debug info about the introspected program
        triangleProgram.printVertexLayout();
        
        // Create the triangle display object
        testTriangle = new Triangle(triangleProgram);
        
        // Configure triangle properties - position it at left side
        testTriangle.x = -0.5;
        testTriangle.y = 0.3;
        testTriangle.scaleX = 0.7;
        testTriangle.scaleY = 0.7;
        // testTriangle.setRotationSpeed(0.1); // Animation disabled for debugging
        // testTriangle.setAutoRotate(true);   // Animation disabled for debugging
        
        trace("Test triangle initialized successfully!");
    }
    
    private function initializeTestRectangle():Void {
        trace("Initializing test rectangle using DisplayObject architecture...");
        
        // Create ProgramInfo with rectangle shaders and automatic introspection
        rectangleProgram = new ProgramInfo("TestRectangle", Rectangle.getVertexShader(), Rectangle.getFragmentShader());
        
        // Print debug info about the introspected program
        rectangleProgram.printVertexLayout();
        
        // Create the rectangle display object with custom size
        testRectangle = new Rectangle(rectangleProgram, 0.6, 0.4);
        
        // Position rectangle at center-right
        testRectangle.x = 0.5;
        testRectangle.y = 0.3;
        testRectangle.scaleX = 0.8;
        testRectangle.scaleY = 0.8;
        
        // You can customize colors if desired
        // testRectangle.setCornerColors([1.0, 0.5, 0.0], [0.5, 1.0, 0.0], [0.0, 0.5, 1.0], [1.0, 0.0, 0.5]);
        
        trace("Test rectangle initialized successfully!");
    }
    
    private function initializeTestQuad():Void {
        trace("Initializing test textured quad using DisplayObject architecture...");
        
        // Create ProgramInfo with quad shaders and automatic introspection
        quadProgram = new ProgramInfo("TestQuad", Quad.getVertexShader(), Quad.getFragmentShader());
        
        // Print debug info about the introspected program
        quadProgram.printVertexLayout();
        
        // Create the textured quad display object - smaller size for better texture detail visibility
        testQuad = new Quad(quadProgram, 128, 128);
        
        // Center the quad for better visibility
        testQuad.x = 0.0;
        testQuad.y = 0.0;
        // Remove scaling to see actual texture size after loading
        // testQuad.scaleX = 0.6;
        // testQuad.scaleY = 0.6;
        
        // Load dev1.tga texture instead of creating a gradient
        trace("Loading dev1.tga texture...");
        app.resources.loadTexture("textures/dev1.tga")
            .then(function(textureData:data.TextureData) {
                trace("Successfully loaded dev1.tga, uploading to GPU...");
                testQuad.createTextureFromData(textureData);
                trace("dev1.tga texture uploaded to quad!");
            })
            .onError(function(error:String) {
                trace("Failed to load dev1.tga: " + error + ", falling back to checkerboard");
                // Fallback to checkerboard texture if loading fails
                testQuad.createCheckerboardTexture(64);
            });
        
        trace("Test textured quad initialized successfully!");
    }
    
    private function initializeTestCube():Void {
        trace("Initializing test 3D cube using DisplayObject architecture...");
        
        // Create ProgramInfo with cube shaders and automatic introspection
        cubeProgram = new ProgramInfo("TestCube", Cube.getVertexShader(), Cube.getFragmentShader());
        
        // Print debug info about the introspected program
        cubeProgram.printVertexLayout();
        
        // Create the 3D cube display object with larger size for better visibility
        testCube = new Cube(cubeProgram, 2.0);
        
        // Position cube slightly to the right in 3D space
        testCube.x = 1.5;
        testCube.y = 0.0;
        testCube.z = 0.0;
        
        // Configure animation - disabled for debugging
        // testCube.autoRotate = true;
        // testCube.rotationSpeed = 1.0;
        
        trace("Test 3D cube initialized successfully!");
    }
    
    private function initializeBackgroundRect():Void {
        trace("Initializing background rectangle for 2D/3D testing...");
        
        // Create ProgramInfo with rectangle shaders
        backgroundProgram = new ProgramInfo("BackgroundRect", Rectangle.getVertexShader(), Rectangle.getFragmentShader());
        
        // Create a larger rectangle that covers more of the screen
        backgroundRect = new Rectangle(backgroundProgram, 3.0, 2.0);
        
        // Position it in front of the cube for testing visibility
        backgroundRect.x = 1.5; // Move it to the side
        backgroundRect.y = 0.0;
        backgroundRect.z = 0.5; // In front of the cube which is at z=0
        
        // Set a bright contrasting color for visibility testing
        var brightGreen = [0.0, 1.0, 0.0]; // Bright green
        backgroundRect.setCornerColors(brightGreen, brightGreen, brightGreen, brightGreen);
        
        trace("Background rectangle initialized successfully!");
    }
    
    private function initializeTestImage():Void {
        trace("Initializing test image using DisplayObject architecture...");
        
        // Create a simple shader program for the image
        imageProgram = new ProgramInfo("TestImage", getImageVertexShader(), getImageFragmentShader());
        
        // Create the image display object
        testImage = new Image(imageProgram);
        
        // Set up the image properties
        testImage.x = 100;
        testImage.y = 100;
        testImage.width = 200;
        testImage.height = 200;
        
        trace("Test image initialized successfully!");
    }

    private function getImageVertexShader():String {
        return '
        #version 330 core
        layout (location = 0) in vec3 aPos;
        layout (location = 1) in vec2 aTexCoord;
        
        out vec2 TexCoord;
        
        uniform mat4 uMatrix;
        
        void main() {
            gl_Position = uMatrix * vec4(aPos, 1.0);
            TexCoord = aTexCoord;
        }
        ';
    }
    
    private function getImageFragmentShader():String {
        return'
        #version 330 core
        in vec2 TexCoord;
        out vec4 FragColor;
        
        uniform vec4 uColor;
        
        void main() {
            // For now, just render a solid color since we don\'t have textures yet
            FragColor = uColor;
        }';
    }
    
    public function cleanup():Void {
        // Cleanup DisplayObjects - they handle their own resource cleanup
        if (testTriangle != null) {
            // DisplayObjects automatically clean up their VAO/VBO in their cleanup
        }
        
        if (testRectangle != null) {
            // DisplayObjects automatically clean up their VAO/VBO in their cleanup
        }
        
        if (testQuad != null) {
            // DisplayObjects automatically clean up their VAO/VBO and textures in their cleanup
            testQuad.remove();
        }
        
        if (testImage != null) {
            // DisplayObjects automatically clean up their VAO/VBO in their cleanup
        }
        
        // Cleanup shader programs
        if (triangleProgram != null) triangleProgram.dispose();
        if (rectangleProgram != null) rectangleProgram.dispose();
        if (quadProgram != null) quadProgram.dispose();
        if (imageProgram != null) imageProgram.dispose();
        
        // Simple cleanup for now - just shader if it exists
        if (shaderProgram != 0) {
            GL.deleteShader(shaderProgram);
        }
        trace("Renderer cleanup complete");
    }

    // Create a gradient texture for testing TextureData upload
    private function createGradientTexture(width:Int, height:Int):TextureData {
        var pixels = new haxe.io.UInt8Array(width * height * 3); // RGB format
        
        for (y in 0...height) {
            for (x in 0...width) {
                var index = (y * width + x) * 3;
                
                // Create a simple red-green gradient
                var red = Std.int((x / width) * 255);
                var green = Std.int((y / height) * 255);
                var blue = 128; // Constant blue
                
                pixels[index + 0] = red;   // R
                pixels[index + 1] = green; // G
                pixels[index + 2] = blue;  // B
            }
        }
        
        return new TextureData(pixels, 3, width, height, false);
    }
}
