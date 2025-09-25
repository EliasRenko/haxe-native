package states;

import State;
import App;
import Entity;
import Renderer;
import display.Image;

/**
 * A test state that demonstrates Image rendering
 */
class ImageTestState extends State {
    
    public function new(app:App) {
        super("ImageTestState", app);
    }
    
    override public function onActivate():Void {
        super.onActivate();
        
        trace("ImageTestState activated - creating image test");
        
        // Use camera at default position to understand baseline coordinate system
        camera.ortho = true;
        // Leave camera at default position (0,0,0) with default orientation
        
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Create ProgramInfo for image (uses textured shaders)
        var imageVertShader = app.resources.getText("shaders/textured.vert");
        var imageFragShader = app.resources.getText("shaders/textured.frag");
        var imageProgramInfo = renderer.createProgramInfo("Image", imageVertShader, imageFragShader);
        
        // Get a texture from preloaded resources
        var textureData = app.resources.getTexture("textures/dev1.tga");
        if (textureData == null) {
            trace("Error: Could not load dev1.tga texture!");
            return;
        }
        
        // Upload texture to GPU and get Texture object
        var texture = renderer.uploadTexture(textureData);
        
        // Create an image entity using texture dimensions automatically
        var imageDisplay = new Image(imageProgramInfo, texture);
        
        // Now with pixel-perfect camera, position image at center of screen
        // Screen size from App constants, so center is at (WINDOW_WIDTH/2, WINDOW_HEIGHT/2)
        // But we want to position by the image's top-left corner, so subtract half the image size
        imageDisplay.x = (__app.WINDOW_WIDTH / 2) - (texture.width / 2);   // Center horizontally 
        imageDisplay.y = (__app.WINDOW_HEIGHT / 2) - (texture.height / 2);  // Center vertically
        imageDisplay.z = 0.0;   // Default Z position
        
        // No scaling needed - image will render at 1:1 pixel size
        
        // Create entity and add to state
        var imageEntity = new Entity("image", imageDisplay);
        addEntity(imageEntity);
        
        trace("ImageTestState setup complete - 1 image entity created");
        trace("Camera configured: pixel-perfect orthographic (0,0 at top-left)");
        trace("Image positioned at screen center: " + imageDisplay.x + ", " + imageDisplay.y);
        trace("Window size: " + __app.WINDOW_WIDTH + "x" + __app.WINDOW_HEIGHT + " pixels");
    }
    
    override public function onDeactivate():Void {
        super.onDeactivate();
        trace("ImageTestState deactivated");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Optional: Add some animation to the image
        var imageEntity = getEntity("image");
        if (imageEntity != null && imageEntity.displayObject != null) {
            var image = cast(imageEntity.displayObject, Image);
            // Rotate the image slowly clockwise (positive values now rotate clockwise)
            image.rotationZ += 1.0 * deltaTime; // 1 degree per second clockwise
        }
    }
}
