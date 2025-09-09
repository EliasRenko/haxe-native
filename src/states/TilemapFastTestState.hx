package states;

import State;
import App;
import Entity;
import display.TilemapFast;
import ProgramInfo;
import Renderer;

/**
 * Test state to demonstrate TilemapFast performance optimizations
 * Shows efficient partial updates using bufferSubData
 */
class TilemapFastTestState extends State {
    
    private var tilemap:TilemapFast;
    private var frameCount:Int = 0;
    
    public function new(app:App) {
        super("TilemapFastTestState", app);
    }
    
    override public function onActivate():Void {
        super.onActivate();
        trace("TilemapFastTestState activated - creating optimized tilemap test");
        
        // Set up orthographic camera for 2D tilemap
        camera.ortho = true;
        
        createTilemapTest();
    }
    
    private function createTilemapTest():Void {
        // Get the renderer
        var renderer = app.getRenderer();
        
        // Create or get the tilemap shader program
        var tilemapVertShader = app.resources.getText("shaders/textured.vert");
        var tilemapFragShader = app.resources.getText("shaders/textured.frag");
        var tilemapProgramInfo = renderer.createProgramInfo("Tilemap", tilemapVertShader, tilemapFragShader);
        
        if (tilemapProgramInfo == null) {
            trace("Error: Failed to create tilemap shader program");
            return;
        }
        
        // Get texture data from preloaded resources
        var textureData = app.resources.getTexture("textures/dev_tiles.tga");
        if (textureData == null) {
            trace("Error: Could not load dev_tiles.tga texture!");
            return;
        }
        
        // Upload texture to GPU and get Texture object
        var atlasTexture = renderer.uploadTexture(textureData);
        
        // Create a TilemapFast instance with optimized performance settings
        tilemap = new TilemapFast(tilemapProgramInfo, 10, 8, 32.0);
        
        // Configure performance thresholds for testing
        tilemap.setPerformanceThresholds(5, 0.25);  // Partial updates for <=5 tiles, rebuild at >25%
        
        // Set the texture atlas
        tilemap.setAtlas(atlasTexture, 32);
        
        // Create initial test pattern using batch operations
        createInitialPattern();
        
        // Position the tilemap at center of screen
        tilemap.x = (App.WINDOW_WIDTH / 2) - (10 * 32 / 2);   // Center horizontally 
        tilemap.y = (App.WINDOW_HEIGHT / 2) - (8 * 32 / 2);   // Center vertically
        tilemap.z = 0.0;   // Default Z position
        
        // Create entity and add to state
        var tilemapEntity = new Entity("tilemap_fast", tilemap);
        addEntity(tilemapEntity);
        
        trace("TilemapFast setup complete - ready for performance testing");
        trace("Performance thresholds: 5 tiles for partial updates, 25% for full rebuild");
        trace("Atlas texture: " + atlasTexture.width + "x" + atlasTexture.height + " (ID: " + atlasTexture.id + ")");
        trace("Tilemap positioned at: " + tilemap.x + ", " + tilemap.y);
    }
    
    private function createInitialPattern():Void {
        trace("Creating initial pattern with batch operations...");
        
        var initialTiles = [];
        
        // Create border tiles (ID 0 = empty for transparency)
        // Create corner markers
        initialTiles.push({x: 1, y: 1, tileId: 2});  // Top-left corner
        initialTiles.push({x: 8, y: 1, tileId: 2});  // Top-right corner
        initialTiles.push({x: 1, y: 6, tileId: 2});  // Bottom-left corner
        initialTiles.push({x: 8, y: 6, tileId: 2});  // Bottom-right corner
        
        // Create a cross pattern in the center
        for (x in 3...7) {
            initialTiles.push({x: x, y: 3, tileId: 4});  // Horizontal line
            initialTiles.push({x: x, y: 4, tileId: 3});  // Center line
        }
        for (y in 2...6) {
            initialTiles.push({x: 4, y: y, tileId: 4});  // Vertical line
            initialTiles.push({x: 5, y: y, tileId: 3});  // Center line
        }
        
        // Use batch operation for efficient initial setup
        tilemap.setTilesBatch(initialTiles);
        
        trace("Initial pattern created with " + initialTiles.length + " tiles using batch operation");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
        frameCount++;
        
        // Demonstrate dynamic tile updates for performance testing
        if (frameCount % 180 == 0) {  // Every 3 seconds
            performanceTest();
        }
    }
    
    private function performanceTest():Void {
        trace("TilemapFast: Starting performance test at frame " + frameCount);
        
        var testType = Std.int(frameCount / 180) % 4;  // Cycle through 4 test types
        
        switch (testType) {
            case 0:
                // Test 1: Single tile update (should use partial update)
                testSingleTileUpdate();
                
            case 1:
                // Test 2: Few tile updates (should use partial update)
                testFewTileUpdates();
                
            case 2:
                // Test 3: Many tile updates (should trigger full rebuild)
                testManyTileUpdates();
                
            case 3:
                // Test 4: Area fill (batch operation)
                testAreaFill();
        }
        
        // Print performance stats
        var stats = tilemap.getPerformanceStats();
        trace("Performance stats: dirtyTiles=" + stats.dirtyTiles + 
              ", bufferCapacity=" + stats.bufferCapacity + 
              ", vertices=" + stats.vertexCount + 
              ", indices=" + stats.indexCount);
    }
    
    private function testSingleTileUpdate():Void {
        trace("Performance Test 1: Single tile update (partial update expected)");
        
        // Change a single tile - should trigger partial update
        var randomX = 2 + Std.random(6);  // Random position in center area
        var randomY = 2 + Std.random(4);
        var randomTileId = 1 + Std.random(4);  // Random tile ID 1-4
        
        tilemap.setTile(randomX, randomY, randomTileId);
        trace("Updated single tile at (" + randomX + ", " + randomY + ") to ID " + randomTileId);
    }
    
    private function testFewTileUpdates():Void {
        trace("Performance Test 2: Few tile updates (partial update expected)");
        
        // Change 3-4 tiles - should still use partial updates
        var tilesToUpdate = [];
        for (i in 0...4) {
            var randomX = 2 + Std.random(6);
            var randomY = 2 + Std.random(4);
            var randomTileId = 1 + Std.random(4);
            tilesToUpdate.push({x: randomX, y: randomY, tileId: randomTileId});
        }
        
        tilemap.setTilesBatch(tilesToUpdate);
        trace("Updated " + tilesToUpdate.length + " tiles using batch operation");
    }
    
    private function testManyTileUpdates():Void {
        trace("Performance Test 3: Many tile updates (full rebuild expected)");
        
        // Change many tiles - should trigger full rebuild
        var tilesToUpdate = [];
        for (i in 0...25) {  // 25 tiles = significant portion of 80 tile map
            var randomX = 1 + Std.random(8);
            var randomY = 1 + Std.random(6);
            var randomTileId = Std.random(5);  // Include empty tiles
            tilesToUpdate.push({x: randomX, y: randomY, tileId: randomTileId});
        }
        
        tilemap.setTilesBatch(tilesToUpdate);
        trace("Updated " + tilesToUpdate.length + " tiles - should trigger full rebuild");
    }
    
    private function testAreaFill():Void {
        trace("Performance Test 4: Area fill operation");
        
        // Fill a rectangular area
        var startX = 2 + Std.random(4);
        var startY = 2 + Std.random(3);
        var width = 2 + Std.random(3);
        var height = 2 + Std.random(3);
        var fillTileId = 1 + Std.random(4);
        
        tilemap.fillArea(startX, startY, width, height, fillTileId);
        trace("Filled area (" + startX + ", " + startY + ") " + width + "x" + height + " with tile " + fillTileId);
    }
}
