package;

import GL;
import ProgramInfo;
import DisplayObject;
import display.Image;
import display.Triangle;
import display.Rectangle;
import display.Quad;
import data.TextureData;

class Renderer {
    
    private var app:App;
    private var shaderProgram:GlUInt;
    private var vbo:GlUInt;
    private var vao:GlUInt;
    
    // DisplayObjects
    private var testTriangle:Triangle;
    private var triangleProgram:ProgramInfo;
    
    // Test rectangle using DisplayObject architecture
    private var testRectangle:Rectangle;
    private var rectangleProgram:ProgramInfo;
    
    // Test textured quad using DisplayObject architecture
    private var testQuad:Quad;
    private var quadProgram:ProgramInfo;
    
    // Test image using DisplayObject architecture
    private var testImage:Image;
    private var imageProgram:ProgramInfo;
    
    public function new(app:App, windowWidth:Int, windowHeight:Int) {
        trace("Creating clean renderer...");
        this.app = app;
        initializeTestTriangle();
        initializeTestRectangle();
        initializeTestQuad();
        //initializeTestImage();
        trace("Clean renderer initialized!");
    }
    
    public function render():Void {
        // Clear screen to gray
        GL.glClearColor(0.6, 0.6, 0.6, 1.0);
        GL.glClear(GL.COLOR_BUFFER_BIT);

        // Render test triangle using DisplayObject architecture
        if (testTriangle != null) {
            // Update triangle animation
            testTriangle.update(0.016); // Assuming ~60fps
            renderDisplayObject(testTriangle);
        }

        // Render test rectangle using DisplayObject architecture  
        if (testRectangle != null) {
            // Add simple scaling animation
            var time = cast(SDL.getTicks(), Int) / 1000.0; // Convert to seconds
            testRectangle.scaleX = 0.8 + 0.2 * Math.sin(time * 2.0);
            testRectangle.scaleY = 0.8 + 0.2 * Math.cos(time * 2.0);
            renderDisplayObject(testRectangle);
        }

        // Render test textured quad using DisplayObject architecture
        if (testQuad != null) {
            // Add rotation animation
            var time = cast(SDL.getTicks(), Int) / 1000.0; // Convert to seconds
            testQuad.rotationZ = time;
            renderDisplayObject(testQuad);
        }

        // Render test image using DisplayObject architecture
        // Temporarily disabled to debug triangle
        // if (testImage != null) {
        //     renderDisplayObject(testImage);
        // }
    }
    
    // ** New method to render display objects
    public function renderDisplayObject(displayObject:DisplayObject):Void {
        if (!displayObject.visible) return;
        
        // Initialize the display object if not already done
        if (!displayObject.initialized) {
            displayObject.init();
        }
        
        // Create a simple identity matrix for now (camera matrix)
        var cameraMatrix = new Matrix();
        cameraMatrix.identity();
        
        // Render the display object
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
        testTriangle.setRotationSpeed(0.1);
        testTriangle.setAutoRotate(true);
        
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
        
        // Create the textured quad display object
        testQuad = new Quad(quadProgram, 0.5, 0.5);
        
        // Position quad at bottom center
        testQuad.x = 0.0;
        testQuad.y = -0.5;
        testQuad.scaleX = 0.6;
        testQuad.scaleY = 0.6;
        
        // Load dev_1.tga texture instead of creating a gradient
        trace("Loading dev_1.tga texture...");
        app.resources.loadTexture("textures/dev_1.tga")
            .then(function(textureData:data.TextureData) {
                trace("Successfully loaded dev_1.tga, uploading to GPU...");
                testQuad.createTextureFromData(textureData);
                trace("dev_1.tga texture uploaded to quad!");
            })
            .onError(function(error:String) {
                trace("Failed to load dev_1.tga: " + error + ", falling back to gradient");
                // Fallback to gradient texture if loading fails
                var gradientTexture = createGradientTexture(64, 64);
                testQuad.createTextureFromData(gradientTexture);
            });
        
        trace("Test textured quad initialized successfully!");
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
