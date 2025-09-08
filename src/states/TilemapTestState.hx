package states;

import State;
import App;
import Entity;
import Renderer;
import display.Tilemap;

/**
 * A test state that demonstrates Tilemap rendering
 */
class TilemapTestState extends State {
    
    public function new(app:App) {
        super("TilemapTestState", app);
    }
    
    override public function onActivate():Void {
        super.onActivate();
        
        trace("TilemapTestState activated - creating tilemap test");
        
        // Use camera at default position to understand baseline coordinate system
        camera.ortho = true;
        // Leave camera at default position (0,0,0) with default orientation
        
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Create ProgramInfo for tilemap (uses textured shaders)
        var tilemapVertShader = app.resources.getText("shaders/textured.vert");
        var tilemapFragShader = app.resources.getText("shaders/textured.frag");
        var tilemapProgramInfo = renderer.createProgramInfo("Tilemap", tilemapVertShader, tilemapFragShader);
        
        // Get a texture from preloaded resources for tilemap atlas
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("Error: Could not load dev_tiles.tga texture!");
            return;
        }
        
        // Upload texture to GPU and get Texture object
        var atlasTexture = renderer.uploadTexture(textureData);
        
        // Create a tilemap - 10x8 tiles, each 32 world units to match 32px atlas tiles
        var tilemap = new Tilemap(tilemapProgramInfo, 10, 8, 32.0);
        
        // Set the atlas texture (32px tiles in the atlas)
        tilemap.setAtlas(atlasTexture, 32);
        
        // Create a simple test pattern
        createTestPattern(tilemap);
        
        // Position tilemap at center of screen
        // Center the entire tilemap (10 tiles * 32 units = 320 width, 8 tiles * 32 units = 256 height)
        tilemap.x = (App.WINDOW_WIDTH / 2) - (10 * 32 / 2);   // Center horizontally 
        tilemap.y = (App.WINDOW_HEIGHT / 2) - (8 * 32 / 2);   // Center vertically
        tilemap.z = 0.0;   // Default Z position
        
        // Create entity and add to state
        var tilemapEntity = new Entity("tilemap", tilemap);
        addEntity(tilemapEntity);
        
        trace("TilemapTestState setup complete - 1 tilemap entity created");
        trace("Tilemap: 10x8 tiles, 32 units per tile");
        trace("Atlas texture: " + atlasTexture.width + "x" + atlasTexture.height + " (ID: " + atlasTexture.id + ")");
        trace("Tilemap positioned at: " + tilemap.x + ", " + tilemap.y);
        trace("Window size: " + App.WINDOW_WIDTH + "x" + App.WINDOW_HEIGHT + " pixels");
    }
    
    /**
     * Create a simple test pattern on the tilemap
     */
    private function createTestPattern(tilemap:Tilemap):Void {
        // Create a test pattern
        for (x in 0...10) {
            for (y in 0...8) {
                var tileId = 0; // Default empty tile
                
                // Leave border as empty (tile ID 0) to show background
                if (x == 0 || x == 9 || y == 0 || y == 7) {
                    tileId = 0; // Empty tile to show background
                }
                // Corner tiles (assuming tile ID 2 exists in atlas)
                else if ((x == 1 || x == 8) && (y == 1 || y == 6)) {
                    tileId = 2;
                }
                // Center cross pattern (assuming tile ID 3 exists in atlas)
                else if (x == 5 || y == 4) {
                    tileId = 3;
                }
                // Checkerboard in remaining areas (assuming tile ID 4 exists in atlas)
                else if ((x + y) % 2 == 0) {
                    tileId = 4;
                }
                
                tilemap.setTile(x, y, tileId);
            }
        }
        
        trace("Test pattern created: border, corners, cross, and checkerboard");
    }
    
    override public function onDeactivate():Void {
        super.onDeactivate();
        trace("TilemapTestState deactivated");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        
        // Optional: Add some animation to the tilemap
        var tilemapEntity = getEntity("tilemap");
        if (tilemapEntity != null && tilemapEntity.displayObject != null) {
            var tilemap = cast(tilemapEntity.displayObject, Tilemap);
            // Rotate the tilemap slowly
            //tilemap.rotationZ += 10.0 * deltaTime; // 10 degrees per second
        }
    }
}
