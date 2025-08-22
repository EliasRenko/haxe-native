package;

import GL;
import ProgramInfo;
import DisplayObject;
import display.Image;
import display.Triangle;
import display.Rectangle;

class Renderer {
    
    private var shaderProgram:GlUInt;
    private var vbo:GlUInt;
    private var vao:GlUInt;
    
    // DisplayObjects
    private var testTriangle:Triangle;
    private var triangleProgram:ProgramInfo;
    
    // Test rectangle using DisplayObject architecture
    private var testRectangle:Rectangle;
    private var rectangleProgram:ProgramInfo;
    
    // Test image using DisplayObject architecture
    private var testImage:Image;
    private var imageProgram:ProgramInfo;
    
    public function new(windowWidth:Int, windowHeight:Int) {
        trace("Creating clean renderer...");
        initializeTestTriangle();
        initializeTestRectangle();
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
            renderDisplayObject(testRectangle);
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
        
        // Configure triangle properties
        testTriangle.setRotationSpeed(2.0);
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
        
        // You can customize colors if desired
        // testRectangle.setCornerColors([1.0, 0.5, 0.0], [0.5, 1.0, 0.0], [0.0, 0.5, 1.0], [1.0, 0.0, 0.5]);
        
        trace("Test rectangle initialized successfully!");
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
        
        if (testImage != null) {
            // DisplayObjects automatically clean up their VAO/VBO in their cleanup
        }
        
        // Cleanup shader programs
        if (triangleProgram != null) triangleProgram.dispose();
        if (rectangleProgram != null) rectangleProgram.dispose();
        if (imageProgram != null) imageProgram.dispose();
        
        // Simple cleanup for now - just shader if it exists
        if (shaderProgram != 0) {
            GL.deleteShader(shaderProgram);
        }
        trace("Renderer cleanup complete");
    }
}
