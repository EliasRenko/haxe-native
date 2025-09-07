package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import math.Matrix;

/**
 * Tilemap implementation with dynamic tile size and texture atlas support
 * Features:
 * - Dynamic buffer growth using bufferSubData
 * - Texture atlas support for multiple tile graphics
 * - Tile animation support (future)
 * - Efficient batch rendering
 */
class Tilemap extends DisplayObject {
    
    // Tilemap configuration
    public var tileSize:Float;              // Size of each tile in world units
    public var mapWidth:Int;                // Width in tiles
    public var mapHeight:Int;               // Height in tiles
    
    // Tile data
    public var tileData:Array<Array<Int>>;  // 2D array of tile IDs [y][x]
    
    // Texture atlas configuration
    public var atlasTexture:GlUInt = 0;     // OpenGL texture ID for atlas
    public var atlasWidth:Int = 0;          // Atlas texture width in pixels
    public var atlasHeight:Int = 0;         // Atlas texture height in pixels
    public var tilePixelSize:Int = 32;      // Size of each tile in the atlas (pixels)
    public var tilesPerRow:Int = 0;         // Number of tiles per row in atlas
    public var tilesPerColumn:Int = 0;      // Number of tiles per column in atlas
    
    // Buffer management for dynamic growth
    private var __currentBufferCapacity:Int = 0;  // Current buffer size in vertices
    private var __dirtyTiles:Array<{x:Int, y:Int}> = [];  // Tiles that need buffer updates
    private var __entireMapDirty:Bool = true;     // Flag to rebuild entire mesh
    
    // Vertex data cache for efficient updates
    private var __vertexCache:Array<Float> = [];
    private var __indexCache:Array<Int> = [];
    
    /**
     * Create a new tilemap
     * @param programInfo Shader program for rendering
     * @param mapWidth Width in tiles
     * @param mapHeight Height in tiles  
     * @param tileSize Size of each tile in world units
     */
    public function new(programInfo:ProgramInfo, mapWidth:Int, mapHeight:Int, tileSize:Float = 1.0) {
        this.mapWidth = mapWidth;
        this.mapHeight = mapHeight;
        this.tileSize = tileSize;
        
        // Initialize tile data with empty tiles (ID 0)
        this.tileData = [];
        for (y in 0...mapHeight) {
            this.tileData[y] = [];
            for (x in 0...mapWidth) {
                this.tileData[y][x] = 0;  // Empty tile
            }
        }
        
        // Start with empty vertices and indices - will be populated when atlas is set
        var emptyVertices = new Vertices([]);
        var emptyIndices = new Indices([]);
        
        super(programInfo, emptyVertices, emptyIndices);
        
        trace("Created Tilemap: " + mapWidth + "x" + mapHeight + " tiles, size: " + tileSize);
    }
    
    /**
     * Set the texture atlas for this tilemap
     * @param textureId OpenGL texture ID
     * @param atlasWidth Atlas width in pixels
     * @param atlasHeight Atlas height in pixels
     * @param tilePixelSize Size of each tile in atlas (pixels)
     */
    public function setAtlas(textureId:GlUInt, atlasWidth:Int, atlasHeight:Int, tilePixelSize:Int = 32):Void {
        this.atlasTexture = textureId;
        this.atlasWidth = atlasWidth;
        this.atlasHeight = atlasHeight;
        this.tilePixelSize = tilePixelSize;
        
        // Calculate atlas layout
        this.tilesPerRow = Std.int(atlasWidth / tilePixelSize);
        this.tilesPerColumn = Std.int(atlasHeight / tilePixelSize);
        
        // Use the new convenience method for texture assignment
        setTexture(textureId);
        
        // Mark entire map as dirty to rebuild mesh
        __entireMapDirty = true;
        if (initialized) {
            needsBufferUpdate = true;
        }
        
        trace("Tilemap atlas set: " + atlasWidth + "x" + atlasHeight + ", " + 
              tilesPerRow + "x" + tilesPerColumn + " tiles");
        
        // Debug: Check how many non-empty tiles we have
        var nonEmptyTiles = 0;
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                if (tileData[y][x] > 0) nonEmptyTiles++;
            }
        }
        trace("Atlas set - Non-empty tiles: " + nonEmptyTiles + " / " + (mapWidth * mapHeight));
    }
    
    /**
     * Set a tile at the specified position
     * @param x Tile X coordinate (0-based)
     * @param y Tile Y coordinate (0-based)
     * @param tileId Tile ID from atlas (0 = empty)
     */
    public function setTile(x:Int, y:Int, tileId:Int):Void {
        if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
            trace("Warning: setTile coordinates out of bounds: (" + x + ", " + y + ")");
            return;
        }
        
        // Only update if tile actually changed
        if (tileData[y][x] != tileId) {
            tileData[y][x] = tileId;
            
            // Mark this tile as dirty for buffer update
            __dirtyTiles.push({x: x, y: y});
            
            if (initialized) {
                needsBufferUpdate = true;
            }
            
            trace("Set tile (" + x + ", " + y + ") to ID " + tileId);
        }
    }
    
    /**
     * Get tile ID at specified position
     * @param x Tile X coordinate
     * @param y Tile Y coordinate
     * @return Tile ID (0 if out of bounds)
     */
    public function getTile(x:Int, y:Int):Int {
        if (x < 0 || x >= mapWidth || y < 0 || y >= mapHeight) {
            return 0;  // Empty tile for out of bounds
        }
        return tileData[y][x];
    }
    
    /**
     * Calculate UV coordinates for a tile ID in the atlas
     * @param tileId Tile ID (0-based)
     * @return UV coordinates as [u1, v1, u2, v2] (top-left, bottom-right)
     */
    private function getTileUVs(tileId:Int):Array<Float> {
        if (tileId <= 0 || tilesPerRow <= 0) {
            // Return UVs for empty/invalid tile (could be transparent area)
            return [0.0, 0.0, 0.0, 0.0];
        }
        
        // Calculate tile position in atlas grid
        var tileX = (tileId - 1) % tilesPerRow;  // -1 because tileId 1 = first tile
        var tileY = Std.int((tileId - 1) / tilesPerRow);
        
        // Convert to UV coordinates (0.0 to 1.0)
        var pixelSize = 1.0 / atlasWidth;  // Size of one pixel in UV space
        var tileUVSize = tilePixelSize / atlasWidth;  // Size of one tile in UV space
        
        var u1 = tileX * tileUVSize;
        var v1 = tileY * tileUVSize;
        var u2 = u1 + tileUVSize;
        var v2 = v1 + tileUVSize;
        
        return [u1, v1, u2, v2];
    }
    
    /**
     * Generate mesh data for the entire tilemap
     * This creates vertices and indices for all visible tiles
     */
    private function generateMesh():Void {
        __vertexCache = [];
        __indexCache = [];
        
        var vertexIndex = 0;  // Track current vertex index for indices
        
        // Generate mesh for each tile
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                var tileId = tileData[y][x];
                
                // Skip empty tiles (tileId 0)
                if (tileId <= 0) continue;
                
                // Calculate world position for this tile
                var worldX = x * tileSize;
                var worldY = y * tileSize;
                
                // Get UV coordinates for this tile
                var uvs = getTileUVs(tileId);
                var u1 = uvs[0], v1 = uvs[1], u2 = uvs[2], v2 = uvs[3];
                
                // Create quad vertices for this tile
                // Format: [x, y, z, u, v] per vertex
                
                // Bottom-left
                __vertexCache.push(worldX);
                __vertexCache.push(worldY);
                __vertexCache.push(0.0);
                __vertexCache.push(u1);
                __vertexCache.push(v2);  // Flipped V for 2D
                
                // Top-left  
                __vertexCache.push(worldX);
                __vertexCache.push(worldY + tileSize);
                __vertexCache.push(0.0);
                __vertexCache.push(u1);
                __vertexCache.push(v1);
                
                // Top-right
                __vertexCache.push(worldX + tileSize);
                __vertexCache.push(worldY + tileSize);
                __vertexCache.push(0.0);
                __vertexCache.push(u2);
                __vertexCache.push(v1);
                
                // Bottom-right
                __vertexCache.push(worldX + tileSize);
                __vertexCache.push(worldY);
                __vertexCache.push(0.0);
                __vertexCache.push(u2);
                __vertexCache.push(v2);
                
                // Create indices for two triangles (quad)
                __indexCache.push(vertexIndex + 0);  // Bottom-left
                __indexCache.push(vertexIndex + 1);  // Top-left
                __indexCache.push(vertexIndex + 2);  // Top-right
                
                __indexCache.push(vertexIndex + 0);  // Bottom-left
                __indexCache.push(vertexIndex + 2);  // Top-right
                __indexCache.push(vertexIndex + 3);  // Bottom-right
                
                vertexIndex += 4;  // Move to next quad
            }
        }
        
        // Update DisplayObject vertex data
        this.vertices.data = __vertexCache;
        this.indices.data = __indexCache;
        
        // Update render counts
        __verticesToRender = Std.int(__vertexCache.length / 5);  // 5 floats per vertex
        __indicesToRender = __indexCache.length;
    }
    
    /**
     * Override updateBuffers to implement efficient buffer management
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!initialized || atlasTexture == 0) return;
        
        // If entire map is dirty, regenerate everything
        if (__entireMapDirty) {
            generateMesh();
            
            // Check if we need to grow buffers - use actual vertex data, not cache
            var requiredCapacity = this.vertices.data.length;
            if (requiredCapacity > __currentBufferCapacity) {
                // Grow buffer by 50% or to required size, whichever is larger
                var newCapacity = Std.int(Math.max(requiredCapacity, __currentBufferCapacity * 1.5));
                __currentBufferCapacity = newCapacity;
                
                // Upload entire new buffer using actual data, not cache
                renderer.uploadVertexData(vao, vbo, this.vertices.data);
                renderer.uploadIndexData(ebo, this.indices.data);
            } else {
                // Use bufferSubData for efficient update
                
                // Update entire buffer using actual data, not cache
                renderer.uploadVertexData(vao, vbo, this.vertices.data);
                renderer.uploadIndexData(ebo, this.indices.data);
            }
            
            renderer.setupVertexAttributes(programInfo);
            __entireMapDirty = false;
        }
        
        // TODO: Implement partial updates for individual dirty tiles
        // This would use bufferSubData to update only changed tile quads
        
        __dirtyTiles = [];  // Clear dirty tile list
        needsBufferUpdate = false;
    }
    
    /**
     * Override render to manage 2D rendering state
     */
    override public function render(cameraMatrix:math.Matrix, renderer:Renderer):Void {
        if (!visible || !initialized || atlasTexture == 0) {
            return;
        }
        
        // Check if we actually have vertices to render
        if (__verticesToRender == 0 || __indicesToRender == 0) {
            return;
        }
        
        // Save current render state and set up for 2D rendering
        var savedDepthTest = renderer.pushRenderState();
        renderer.setDepthTest(false);
        
        // Update transformation matrix based on current properties
        updateTransform();
        
        // Create final matrix by combining object matrix with camera matrix
        var finalMatrix = math.Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        
        // Set uniforms for tilemap rendering
        uniforms.set("uMatrix", finalMatrix.data);
        
        // Set the atlas texture for rendering
        setTexture(atlasTexture);
        
        // Let the Renderer handle all GL operations including texture binding
        renderer.renderObject(this);
        
        // Restore previous render state
        renderer.popRenderState(savedDepthTest);
    }

    /**
     * Fill an area of the tilemap with a specific tile
     * @param startX Starting X coordinate
     * @param startY Starting Y coordinate  
     * @param width Width in tiles
     * @param height Height in tiles
     * @param tileId Tile ID to fill with
     */
    public function fillArea(startX:Int, startY:Int, width:Int, height:Int, tileId:Int):Void {
        for (y in startY...(startY + height)) {
            for (x in startX...(startX + width)) {
                setTile(x, y, tileId);
            }
        }
        trace("Filled area (" + startX + ", " + startY + ") " + width + "x" + height + " with tile " + tileId);
    }
    
    /**
     * Clear the entire tilemap (set all tiles to 0)
     */
    public function clear():Void {
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                tileData[y][x] = 0;
            }
        }
        __entireMapDirty = true;
        if (initialized) {
            needsBufferUpdate = true;
        }
        trace("Cleared tilemap");
    }
    
    /**
     * Get tilemap dimensions
     * @return {width: Int, height: Int} Map size in tiles
     */
    public function getMapSize():{width:Int, height:Int} {
        return {width: mapWidth, height: mapHeight};
    }
    
    /**
     * Convert world coordinates to tile coordinates
     * @param worldX World X coordinate
     * @param worldY World Y coordinate
     * @return {x: Int, y: Int} Tile coordinates (may be out of bounds)
     */
    public function worldToTile(worldX:Float, worldY:Float):{x:Int, y:Int} {
        return {
            x: Std.int(worldX / tileSize),
            y: Std.int(worldY / tileSize)
        };
    }
    
    /**
     * Convert tile coordinates to world coordinates (center of tile)
     * @param tileX Tile X coordinate
     * @param tileY Tile Y coordinate
     * @return {x: Float, y: Float} World coordinates
     */
    public function tileToWorld(tileX:Int, tileY:Int):{x:Float, y:Float} {
        return {
            x: tileX * tileSize + tileSize * 0.5,
            y: tileY * tileSize + tileSize * 0.5
        };
    }
}
