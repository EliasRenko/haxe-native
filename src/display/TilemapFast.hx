package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import math.Matrix;

/**
 * High-performance Tilemap implementation with bufferSubData optimizations
 * Features:
 * - Efficient partial buffer updates using bufferSubData
 * - Optimized tile change tracking for minimal GPU uploads  
 * - Perfect for particle effects, destructible tiles, and animations
 * - Dynamic buffer growth and shrinking
 * - Batch processing of multiple tile changes
 */
class TilemapFast extends DisplayObject {
    
    // Tilemap configuration
    public var tileSize:Float;              // Size of each tile in world units
    public var mapWidth:Int;                // Width in tiles
    public var mapHeight:Int;               // Height in tiles
    
    // Tile data
    public var tileData:Array<Array<Int>>;  // 2D array of tile IDs [y][x]
    
    // Texture atlas configuration
    public var atlasTexture:Texture = null;     // Atlas texture object
    public var atlasWidth:Int = 0;          // Atlas texture width in pixels
    public var atlasHeight:Int = 0;         // Atlas texture height in pixels
    public var tilePixelSize:Int = 32;      // Size of each tile in the atlas (pixels)
    public var tilesPerRow:Int = 0;         // Number of tiles per row in atlas
    public var tilesPerColumn:Int = 0;      // Number of tiles per column in atlas
    
    // Advanced buffer management for optimal performance
    private var __currentBufferCapacity:Int = 0;  // Current buffer size in vertices
    private var __dirtyTiles:Array<{x:Int, y:Int}> = [];  // Tiles that need buffer updates
    private var __entireMapDirty:Bool = true;     // Flag to rebuild entire mesh
    
    // Tile-to-vertex mapping for efficient partial updates
    private var __tileVertexMap:Map<String, Int> = new Map();  // "x,y" -> vertex start index
    private var __tileVertexCount:Int = 20;       // Floats per tile (4 vertices * 5 floats each)
    private var __tileIndexCount:Int = 6;         // Indices per tile (2 triangles * 3 indices each)
    
    // Performance thresholds for optimization decisions
    private var __partialUpdateThreshold:Int = 10;    // Use partial updates for <= 10 tiles
    private var __fullRebuildThreshold:Float = 0.3;   // Rebuild if >30% of tiles changed
    
    // Vertex data cache for efficient updates
    private var __vertexCache:Array<Float> = [];
    private var __indexCache:Array<Int> = [];
    
    /**
     * Create a new high-performance tilemap
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
        
        trace("Created TilemapFast: " + mapWidth + "x" + mapHeight + " tiles, size: " + tileSize);
        trace("  Partial update threshold: " + __partialUpdateThreshold + " tiles");
        trace("  Full rebuild threshold: " + (__fullRebuildThreshold * 100) + "% tile changes");
    }
    
    /**
     * Set the texture atlas for this tilemap
     * @param texture Texture object containing atlas data
     * @param tilePixelSize Size of each tile in atlas (pixels)
     */
    public function setAtlas(texture:Texture, tilePixelSize:Int = 32):Void {
        this.atlasTexture = texture;
        this.atlasWidth = texture.width;
        this.atlasHeight = texture.height;
        this.tilePixelSize = tilePixelSize;
        
        // Calculate atlas layout
        this.tilesPerRow = Std.int(atlasWidth / tilePixelSize);
        this.tilesPerColumn = Std.int(atlasHeight / tilePixelSize);
        
        // Use the inherited texture system
        setTexture(texture);
        
        // Mark entire map as dirty to rebuild mesh
        __entireMapDirty = true;
        if (initialized) {
            needsBufferUpdate = true;
        }
        
        trace("TILEMAPFAST ATLAS DEBUG: Setting atlas texture ID=" + texture.id + " size=" + atlasWidth + "x" + atlasHeight);
        trace("TILEMAPFAST ATLAS DEBUG: Tile pixel size=" + tilePixelSize + ", Grid=" + tilesPerRow + "x" + tilesPerColumn + " tiles");
        trace("TILEMAPFAST ATLAS DEBUG: UV tile size=" + (tilePixelSize/atlasWidth) + "x" + (tilePixelSize/atlasHeight));
    }
    
    /**
     * Set a tile at the specified position with optimization tracking
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
            var oldTileId = tileData[y][x];
            tileData[y][x] = tileId;
            
            // Track this tile as dirty for optimized buffer update
            var tileKey = x + "," + y;
            var alreadyDirty = false;
            for (dirtyTile in __dirtyTiles) {
                if (dirtyTile.x == x && dirtyTile.y == y) {
                    alreadyDirty = true;
                    break;
                }
            }
            
            if (!alreadyDirty) {
                __dirtyTiles.push({x: x, y: y});
            }
            
            if (initialized) {
                needsBufferUpdate = true;
            }
            
            // Debug tile changes for performance analysis
            trace("TilemapFast: Set tile (" + x + ", " + y + ") " + oldTileId + " -> " + tileId + " (dirty tiles: " + __dirtyTiles.length + ")");
        }
    }
    
    /**
     * Batch set multiple tiles efficiently
     * @param tiles Array of {x:Int, y:Int, tileId:Int} tile updates
     */
    public function setTilesBatch(tiles:Array<{x:Int, y:Int, tileId:Int}>):Void {
        trace("TilemapFast: Batch setting " + tiles.length + " tiles");
        
        var changedCount = 0;
        for (tile in tiles) {
            if (tile.x >= 0 && tile.x < mapWidth && tile.y >= 0 && tile.y < mapHeight) {
                if (tileData[tile.y][tile.x] != tile.tileId) {
                    tileData[tile.y][tile.x] = tile.tileId;
                    
                    // Check if already dirty
                    var alreadyDirty = false;
                    for (dirtyTile in __dirtyTiles) {
                        if (dirtyTile.x == tile.x && dirtyTile.y == tile.y) {
                            alreadyDirty = true;
                            break;
                        }
                    }
                    
                    if (!alreadyDirty) {
                        __dirtyTiles.push({x: tile.x, y: tile.y});
                    }
                    
                    changedCount++;
                }
            }
        }
        
        if (changedCount > 0 && initialized) {
            needsBufferUpdate = true;
        }
        
        trace("TilemapFast: Batch complete - " + changedCount + " tiles changed, " + __dirtyTiles.length + " total dirty");
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
        
        // TEMPORARY: Hardcode UV coordinates for testing different atlas positions
        // For a 4x4 atlas (128x128 with 32x32 tiles), let's test different positions
        if (tileId == 1) {
            return [0.0, 1.0, 0.25, 0.75];
        }
        if (tileId == 2) {
            return [0.0, 0.75, 0.25, 0.5];
        }
        if (tileId == 3) {
            return [0.0, 0.5, 0.25, 0.25];
        }
        if (tileId == 4) {
            return [0.0, 0.25, 0.25, 0.0];
        }
        
        // Calculate tile position in atlas grid
        var tileX = (tileId - 1) % tilesPerRow;  // -1 because tileId 1 = first tile
        var tileY = Std.int((tileId - 1) / tilesPerRow);
        
        // Convert to UV coordinates (0.0 to 1.0) with proper flipping
        var tileUVWidth = tilePixelSize / atlasWidth;
        var tileUVHeight = tilePixelSize / atlasHeight;
        
        var u1 = tileX * tileUVWidth;
        var rawV1 = tileY * tileUVHeight;
        var u2 = u1 + tileUVWidth;
        var rawV2 = rawV1 + tileUVHeight;
        
        // Apply V-coordinate flipping for OpenGL
        var topV = 1.0 - rawV1;
        var bottomV = 1.0 - rawV2;
        
        return [u1, topV, u2, bottomV];
    }
    
    /**
     * Generate vertex data for a single tile
     * @param x Tile X coordinate
     * @param y Tile Y coordinate
     * @param tileId Tile ID
     * @return Array of 20 floats (4 vertices * 5 components each)
     */
    private function generateTileVertices(x:Int, y:Int, tileId:Int):Array<Float> {
        var vertices = [];
        
        if (tileId <= 0) {
            // Return empty/invisible tile data (all zeros or degenerate)
            for (i in 0...20) {
                vertices.push(0.0);
            }
            return vertices;
        }
        
        // Calculate world position for this tile
        var worldX = x * tileSize;
        var worldY = y * tileSize;
        
        // Get UV coordinates for this tile
        var uvs = getTileUVs(tileId);
        var u1 = uvs[0], v1 = uvs[1], u2 = uvs[2], v2 = uvs[3];
        
        // Create quad vertices: top-left, top-right, bottom-right, bottom-left
        // Format: [x, y, z, u, v] per vertex
        
        // Top-left
        vertices.push(worldX);
        vertices.push(worldY + tileSize);
        vertices.push(0.0);
        vertices.push(u1);
        vertices.push(v1);
        
        // Top-right
        vertices.push(worldX + tileSize);
        vertices.push(worldY + tileSize);
        vertices.push(0.0);
        vertices.push(u2);
        vertices.push(v1);
        
        // Bottom-right
        vertices.push(worldX + tileSize);
        vertices.push(worldY);
        vertices.push(0.0);
        vertices.push(u2);
        vertices.push(v2);
        
        // Bottom-left
        vertices.push(worldX);
        vertices.push(worldY);
        vertices.push(0.0);
        vertices.push(u1);
        vertices.push(v2);
        
        return vertices;
    }
    
    /**
     * Generate mesh data for the entire tilemap with vertex mapping
     */
    private function generateMesh():Void {
        __vertexCache = [];
        __indexCache = [];
        __tileVertexMap.clear();
        
        var vertexIndex = 0;  // Track current vertex index for indices
        
        // Generate mesh for each tile
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                var tileId = tileData[y][x];
                
                // Skip empty tiles (tileId 0) but reserve space for potential future tiles
                var tileKey = x + "," + y;
                __tileVertexMap.set(tileKey, Std.int(__vertexCache.length / 5)); // Store vertex start index
                
                if (tileId <= 0) {
                    // Add degenerate/empty vertices to maintain consistent indexing
                    for (i in 0...20) {
                        __vertexCache.push(0.0);
                    }
                    // Add degenerate indices that won't render
                    for (i in 0...6) {
                        __indexCache.push(vertexIndex);  // All point to same vertex
                    }
                    vertexIndex += 4;
                    continue;
                }
                
                // Generate vertices for this tile
                var tileVertices = generateTileVertices(x, y, tileId);
                for (vertex in tileVertices) {
                    __vertexCache.push(vertex);
                }
                
                // Create indices for two triangles (quad)
                __indexCache.push(vertexIndex + 0);  // Top-left
                __indexCache.push(vertexIndex + 1);  // Top-right
                __indexCache.push(vertexIndex + 2);  // Bottom-right
                
                __indexCache.push(vertexIndex + 0);  // Top-left
                __indexCache.push(vertexIndex + 2);  // Bottom-right
                __indexCache.push(vertexIndex + 3);  // Bottom-left
                
                vertexIndex += 4;  // Move to next quad
            }
        }
        
        // Update DisplayObject vertex data
        this.vertices = __vertexCache;
        this.indices = __indexCache;
        
        // Update render counts
        __verticesToRender = Std.int(__vertexCache.length / 5);  // 5 floats per vertex
        __indicesToRender = __indexCache.length;
        
        trace("TilemapFast: Generated mesh - " + __verticesToRender + " vertices, " + __indicesToRender + " indices");
        
        // Count vertex mappings
        var mappingCount = 0;
        for (key in __tileVertexMap.keys()) {
            mappingCount++;
        }
        trace("TilemapFast: Vertex mapping created for " + mappingCount + " tiles");
    }
    
    /**
     * High-performance buffer update with intelligent optimization selection
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!initialized || atlasTexture == null) return;
        
        // If entire map is dirty, do a full rebuild
        if (__entireMapDirty) {
            trace("TilemapFast: Full mesh rebuild triggered");
            generateMesh();
            
            // Always upload full buffer for complete rebuilds
            renderer.uploadVertexData(vao, vbo, this.vertices.data);
            renderer.uploadIndexData(ebo, this.indices.data);
            renderer.setupVertexAttributes(programInfo);
            
            __currentBufferCapacity = this.vertices.data.length;
            __entireMapDirty = false;
            __dirtyTiles = [];
            needsBufferUpdate = false;
            
            trace("TilemapFast: Full rebuild complete - buffer capacity: " + __currentBufferCapacity);
            return;
        }
        
        // Determine update strategy based on dirty tile count
        var dirtyCount = __dirtyTiles.length;
        var totalTiles = mapWidth * mapHeight;
        var dirtyPercentage = dirtyCount / totalTiles;
        
        trace("TilemapFast: Updating " + dirtyCount + " dirty tiles (" + Math.round(dirtyPercentage * 100) + "% of map)");
        
        if (dirtyCount == 0) {
            needsBufferUpdate = false;
            return;
        }
        
        // Strategy selection
        if (dirtyCount <= __partialUpdateThreshold && dirtyPercentage < __fullRebuildThreshold) {
            // Use efficient partial updates
            updateTilesPartial(renderer);
        } else {
            // Fall back to full regeneration for major changes
            trace("TilemapFast: Dirty count/percentage exceeds thresholds, using full regeneration");
            generateMesh();
            renderer.uploadVertexData(vao, vbo, this.vertices.data);
            renderer.uploadIndexData(ebo, this.indices.data);
        }
        
        __dirtyTiles = [];
        needsBufferUpdate = false;
    }
    
    /**
     * Update only the dirty tiles using bufferSubData for maximum performance
     */
    private function updateTilesPartial(renderer:Renderer):Void {
        trace("TilemapFast: Performing partial update for " + __dirtyTiles.length + " tiles");
        
        for (dirtyTile in __dirtyTiles) {
            var x = dirtyTile.x;
            var y = dirtyTile.y;
            var tileKey = x + "," + y;
            
            // Get the vertex start index for this tile
            if (!__tileVertexMap.exists(tileKey)) {
                trace("Warning: No vertex mapping found for tile (" + x + ", " + y + ")");
                continue;
            }
            
            var vertexStartIndex = __tileVertexMap.get(tileKey);
            var tileId = tileData[y][x];
            
            // Generate new vertices for this tile
            var newVertices = generateTileVertices(x, y, tileId);
            
            // Update the main vertex cache
            for (i in 0...newVertices.length) {
                var cacheIndex = vertexStartIndex * 5 + i;  // 5 floats per vertex
                if (cacheIndex < __vertexCache.length) {
                    __vertexCache[cacheIndex] = newVertices[i];
                }
            }
            
            // Calculate offset for bufferSubData in floats
            var offsetInFloats = vertexStartIndex * 5;  // vertex index * floats per vertex
            
            // Upload partial vertex data using optimized renderer method
            renderer.uploadVertexDataPartial(vbo, offsetInFloats, newVertices);
            
            trace("TilemapFast: Updated tile (" + x + ", " + y + ") tileId=" + tileId + " at vertex offset " + vertexStartIndex);
        }
        
        // Update the main DisplayObject data
        this.vertices = __vertexCache;
        
        trace("TilemapFast: Partial update complete");
    }
    
    /**
     * Override render to manage 2D rendering state
     */
    override public function render(cameraMatrix:math.Matrix):Void {
        if (!visible || !initialized || atlasTexture == null) {
            return;
        }
        
        // Check if we actually have vertices to render
        if (__verticesToRender == 0 || __indicesToRender == 0) {
            return;
        }
        
        // Save current render state and set up for 2D rendering
        // var savedDepthTest = renderer.pushRenderState();
        // renderer.setDepthTest(false);
        
        // Update transformation matrix based on current properties
        updateTransform();
        
        // Create final matrix by combining object matrix with camera matrix
        var finalMatrix = math.Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        
        // Set uniforms for tilemap rendering
        uniforms.set("uMatrix", finalMatrix.data);
        
        // Restore previous render state
        //renderer.popRenderState(savedDepthTest);
    }

    /**
     * Fill an area of the tilemap with a specific tile using batch optimization
     * @param startX Starting X coordinate
     * @param startY Starting Y coordinate  
     * @param width Width in tiles
     * @param height Height in tiles
     * @param tileId Tile ID to fill with
     */
    public function fillArea(startX:Int, startY:Int, width:Int, height:Int, tileId:Int):Void {
        var tilesToUpdate = [];
        
        for (y in startY...(startY + height)) {
            for (x in startX...(startX + width)) {
                if (x >= 0 && x < mapWidth && y >= 0 && y < mapHeight) {
                    tilesToUpdate.push({x: x, y: y, tileId: tileId});
                }
            }
        }
        
        setTilesBatch(tilesToUpdate);
        trace("TilemapFast: Filled area (" + startX + ", " + startY + ") " + width + "x" + height + " with tile " + tileId);
    }
    
    /**
     * Clear the entire tilemap (set all tiles to 0) efficiently
     */
    public function clear():Void {
        for (y in 0...mapHeight) {
            for (x in 0...mapWidth) {
                tileData[y][x] = 0;
            }
        }
        __entireMapDirty = true;
        __dirtyTiles = [];
        __tileVertexMap.clear();
        
        if (initialized) {
            needsBufferUpdate = true;
        }
        trace("TilemapFast: Cleared tilemap");
    }
    
    /**
     * Configure performance thresholds for update optimization
     * @param partialThreshold Max tiles for partial updates (default: 10)
     * @param rebuildThreshold Percentage threshold for full rebuild (default: 0.3 = 30%)
     */
    public function setPerformanceThresholds(partialThreshold:Int, rebuildThreshold:Float):Void {
        __partialUpdateThreshold = partialThreshold;
        __fullRebuildThreshold = rebuildThreshold;
        
        trace("TilemapFast: Performance thresholds updated - partial: " + partialThreshold + ", rebuild: " + (rebuildThreshold * 100) + "%");
    }
    
    /**
     * Get performance statistics for optimization analysis
     */
    public function getPerformanceStats():{dirtyTiles:Int, bufferCapacity:Int, vertexCount:Int, indexCount:Int} {
        return {
            dirtyTiles: __dirtyTiles.length,
            bufferCapacity: __currentBufferCapacity,
            vertexCount: __verticesToRender,
            indexCount: __indicesToRender
        };
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
