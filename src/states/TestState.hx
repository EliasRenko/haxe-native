package states;

import display.Cube;
import display.Triangle;
import display.Tilemap;

/**
 * A test state that demonstrates the State/Entity system
 * This replaces the hardcoded test objects that were in the Renderer
 */
class TestState extends State {
    
    public function new(app:App) {
        super("TestState", app);
    }
    
    override public function onActivate():Void {
        super.onActivate();
        
        trace("TestState activated - creating test entities");
        
        // Configure this state's camera for orthographic 2D view (better for tilemaps)
        camera.ortho = true;
        camera.x = 0.0;
        camera.y = 0.0;
        camera.z = 1.0; // Move camera closer for orthographic
        camera.pitch = 0.0;
        camera.yaw = 0.0;
        camera.roll = 0.0;
        
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Request ProgramInfos from the Renderer using preloaded shaders
        var triangleVertShader = app.resources.getText("shaders/simple.vert");
        var triangleFragShader = app.resources.getText("shaders/simple.frag");
        var triangleProgramInfo = renderer.createProgramInfo("Triangle", triangleVertShader, triangleFragShader);
        
        var cubeVertShader = app.resources.getText("shaders/simple.vert");
        var cubeFragShader = app.resources.getText("shaders/simple.frag");
        var cubeProgramInfo = renderer.createProgramInfo("Cube", cubeVertShader, cubeFragShader);
        
        // Create ProgramInfo for tilemap (uses textured shaders)
        var tilemapVertShader = app.resources.getText("shaders/textured.vert");
        var tilemapFragShader = app.resources.getText("shaders/textured.frag");
        var tilemapProgramInfo = renderer.createProgramInfo("Tilemap", tilemapVertShader, tilemapFragShader);
        
        // Create a test triangle entity (replaces hardcoded triangle in Renderer)
        var triangleDisplay = new Triangle(triangleProgramInfo);
        triangleDisplay.x = -0.5;
        triangleDisplay.y = 0.0;
        triangleDisplay.z = 0.0;
        var triangleEntity = new Entity("triangle", triangleDisplay);
        addEntity(triangleEntity);
        
        // Create a test cube entity (replaces hardcoded cube in Renderer)
        var cubeDisplay = new Cube(cubeProgramInfo);
        cubeDisplay.x = 0.5;
        cubeDisplay.y = 0.0;
        cubeDisplay.z = 0.0;
        var cubeEntity = new Entity("cube", cubeDisplay);
        addEntity(cubeEntity);
        
        // Create a test tilemap (will be visible when atlas is provided) - POSITIONED FOR CAMERA VIEW
        var tilemap = new Tilemap(tilemapProgramInfo, 8, 6, 0.5);  // 8x6 tiles, 0.5 units per tile (4x3 units total)
        tilemap.x = -2.0;  // Center tilemap horizontally in view (-2 to +2 = 4 units wide)
        tilemap.y = -1.5;  // Center tilemap vertically in view (-1.5 to +1.5 = 3 units tall)
        tilemap.z = 0.0;   // Move to center Z for better visibility
        trace("Set tilemap position: (" + tilemap.x + ", " + tilemap.y + ", " + tilemap.z + ")");
        
        // Create a simple test pattern (will only show when atlas is set)
        tilemap.fillArea(0, 0, 8, 1, 1);  // Bottom row with tile ID 1
        tilemap.fillArea(0, 5, 8, 1, 2);  // Top row with tile ID 2
        tilemap.fillArea(0, 1, 1, 4, 3);  // Left column with tile ID 3
        tilemap.fillArea(7, 1, 1, 4, 4);  // Right column with tile ID 4
        tilemap.setTile(3, 2, 5);         // Center tile with ID 5
        tilemap.setTile(4, 2, 6);         // Another center tile with ID 6
        
        var tilemapEntity = new Entity("tilemap", tilemap);
        addEntity(tilemapEntity);
        
        // Atlas will be loaded after assets are preloaded
        // We'll set this up in a delayed call
        
        trace("Created test tilemap: 8x6 tiles, 0.5 units per tile, positioned to fit in camera view");
        trace("Tilemap atlas will be loaded after asset preloading completes");
        
        trace("TestState setup complete - " + entities.length + " entities created");
        trace("Camera configured: Z=" + camera.z + ", ortho=" + camera.ortho + " (orthographic for 2D tilemap)");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Check if we need to load the tilemap atlas (after assets are preloaded)
        var tilemapEntity = getEntity("tilemap");
        if (tilemapEntity != null) {
            var tilemap = cast(tilemapEntity.displayObject, display.Tilemap);
            if (tilemap.atlasTexture == 0) { // No atlas set yet
                trace("Attempting to load tilemap atlas...");
                var atlasTexture = __app.resources.getTexture("textures/dev_tiles.tga");
                if (atlasTexture != null) {
                    trace("Atlas texture found: " + atlasTexture.width + "x" + atlasTexture.height + " pixels");
                    var textureId = __app.getRenderer().uploadTexture(atlasTexture);
                    trace("Atlas uploaded with ID: " + textureId);
                    tilemap.setAtlas(textureId, atlasTexture.width, atlasTexture.height, 32);
                    trace("Tilemap atlas set successfully!");
                } else {
                    trace("ERROR: dev_tiles.tga not found in resources!");
                }
            }
        }
        
        // Add some simple rotation animation to demonstrate entities updating
        for (entity in entities) {
            if (entity.displayObject != null) {
                // Keep tilemap stationary - only rotate triangle and cube
                if (entity.id != "tilemap") {
                    // Very slow rotation: 1 degree per second (convert to radians)
                    entity.rotationY += deltaTime * (1.0 * Math.PI / 180.0);
                }
                
                // Don't override Y position - let entities keep their set positions
                // entity.y = 0.0;  // REMOVED: This was overriding tilemap positioning
            }
        }
    }
    
    override public function onDeactivate():Void {
        trace("TestState deactivated");
        super.onDeactivate();
    }
}
