package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import Texture;
import math.Matrix;
import data.Vertices;
import data.Indices;
import display.Tile;

#if js
typedef UIntData = UInt;
#else
typedef UIntData = cpp.UInt32;
#end

/**
 * TileBatch - Primitive orphaning renderer
 * 
 * Strategy:
 * - Allocate buffer once for MAX_TILES capacity (GL_STREAM_DRAW)
 * - Pre-generate all indices (uploaded once with GL_STATIC_DRAW)
 * - Every frame: take tile data and build vertex array
 * - Orphan buffer with glBufferData(NULL, size, GL_STREAM_DRAW)
 * - Upload actual data with glBufferFloatArray()
 * - Draw using actual vertex/index counts
 * 
 * This prevents GPU stalls by allowing the driver to allocate new buffer
 * regions while the GPU is still reading from old ones.
 */
class TileBatch extends DisplayObject {
    
    // Maximum tile capacity (buffer allocated for this many tiles)
    private static inline var MAX_TILES:Int = 1000;
    
    //public var atlasTexture:Texture = null;
    public var atlasRegions:Map<Int, AtlasRegion> = new Map(); // regionId -> AtlasRegion
    
    // Current tile data (set each frame)
    //private var __currentTileData:Array<{x:Float, y:Float, width:Float, height:Float, regionId:Int, visible:Bool}> = [];
    
    // Buffer management
    private var __nextRegionId:Int = 1; // Auto-incrementing region ID
    private var __bufferCapacity:Int = 0; // Current buffer capacity in tiles
    
    /**
     * Create a new TileBatch
     * @param programInfo Shader program for rendering
     * @param texture Atlas texture for all tiles
     */
    public function new(renderer:Renderer, texture:Texture) {
        
        // Start with empty vertices but pre-generate indices for MAX_TILES
        var emptyVertices = new Vertices([]);
        var indices = generateIndices(MAX_TILES);
        
        // Call super first so @:shader metadata (if present on a subclass) can
        // auto-resolve programInfo via getShaderName(). Only override with the
        // explicitly passed programInfo when one is provided.
        super(renderer, emptyVertices, indices);
        //if (programInfo != null) this.programInfo = programInfo;
        
        // Set OpenGL properties
        mode = GL.TRIANGLES;
        
        // Premultiplied-alpha blending — pairs with TGALoader's premultiplication.
        // GL_ONE because RGB is already scaled by alpha in the texture data.
        blending = {
            source: GL.ONE,
            //source: GL.ONE,
            destination: GL.ONE_MINUS_SRC_ALPHA
        };
        
        // Set the texture for the display object
        setTexture(texture);
        
        __bufferCapacity = 0; // Will be allocated on first init
    }
    
    /**
     * Pre-generate all indices for maximum tile capacity
     * Indices never change, so we generate them once
     */
    private function generateIndices(tileCount:Int):Indices {
        var indices:Array<UIntData> = [];
        
        for (i in 0...tileCount) {
            var vertexIndex:UIntData = i * 4;
            
            // Triangle 1
            indices.push(vertexIndex + 0);  // Top-left
            indices.push(vertexIndex + 1);  // Top-right
            indices.push(vertexIndex + 2);  // Bottom-right
            
            // Triangle 2
            indices.push(vertexIndex + 0);  // Top-left
            indices.push(vertexIndex + 2);  // Bottom-right
            indices.push(vertexIndex + 3);  // Bottom-left
        }
        
        return new Indices(indices);
    }
    
    /**
     * Define an atlas region using pixel coordinates
     * @param atlasX Atlas X coordinate in pixels
     * @param atlasY Atlas Y coordinate in pixels
     * @param atlasWidth Atlas width in pixels
     * @param atlasHeight Atlas height in pixels
     * @return Region ID for use in addTile
     */
    public function defineRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
        var regionId = __nextRegionId++;
        
        var region = new AtlasRegion();
        region.x = atlasX;
        region.y = atlasY;
        region.width = atlasWidth;
        region.height = atlasHeight;
        
        // Convert pixel coordinates to UV coordinates
        // No V-flipping needed since TGA loader now handles proper orientation
        region.u1 = atlasX / textures[0].width;
        region.v1 = atlasY / textures[0].height;
        region.u2 = (atlasX + atlasWidth) / textures[0].width;
        region.v2 = (atlasY + atlasHeight) / textures[0].height;
        
        atlasRegions.set(regionId, region);
        
        return regionId;
    }
    
    /**
     * Update an existing atlas region's pixel coordinates and recompute its UV values.
     * Use this instead of defineRegion when you want to change the region without
     * allocating a new region ID (avoids orphan accumulation and tile.regionId churn).
     * @param regionId  The existing region ID returned by a previous defineRegion call.
     * @param atlasX    New atlas X coordinate in pixels.
     * @param atlasY    New atlas Y coordinate in pixels.
     * @param atlasWidth  New atlas width in pixels.
     * @param atlasHeight New atlas height in pixels.
     * @return True if the region was found and updated, false if regionId is unknown.
     */
    public function updateRegion(regionId:Int, atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Bool {
        var region = atlasRegions.get(regionId);
        if (region == null) return false;

        region.x = atlasX;
        region.y = atlasY;
        region.width = atlasWidth;
        region.height = atlasHeight;

        region.u1 = atlasX / textures[0].width;
        region.v1 = atlasY / textures[0].height;
        region.u2 = (atlasX + atlasWidth) / textures[0].width;
        region.v2 = (atlasY + atlasHeight) / textures[0].height;

        return true;
    }

    /**
     * Generate vertex data for a single tile
     */
    private function generateTileVertices(tile:Tile):Void {

        // Get UV coordinates from the atlas region
        var region = atlasRegions.get(tile.regionId);
        if (region == null) {
            region = new AtlasRegion();
            region.u1 = -1.0; region.v1 = -1.0;
            region.u2 = -1.0; region.v2 = -1.0;
        }

        // Flip V to compensate for Y-axis orientation — DO NOT CHANGE
        var uv1 = region.v2;
        var uv2 = region.v1;

        var x  = tile.x + tile.offsetX;
        var y  = tile.y + tile.offsetY;
        var hw = tile.width  * 0.5;
        var hh = tile.height * 0.5;

        // Tile centre in world space
        var cx = x + hw;
        var cy = y + hh;

        // Pre-compute rotation (only do trig when the tile is actually rotated)
        var cosA = 1.0;
        var sinA = 0.0;
        if (tile.rotation != 0.0) {
            var rad = tile.rotation * Math.PI / 180.0;
            cosA = Math.cos(rad);
            sinA = Math.sin(rad);
        }

        // Rotate each corner's local offset and translate to world space.
        // Local offsets (x, y) relative to centre:
        //   top-left     (-hw, +hh)
        //   top-right    (+hw, +hh)
        //   bottom-right (+hw, -hh)
        //   bottom-left  (-hw, -hh)
        // Rotation formula:  rx = lx*cos - ly*sin + cx
        //                    ry = lx*sin + ly*cos + cy

        // Top-left
        vertices.push(-hw * cosA - hh * sinA + cx);
        vertices.push(-hw * sinA + hh * cosA + cy);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(uv1);

        // Top-right
        vertices.push( hw * cosA - hh * sinA + cx);
        vertices.push( hw * sinA + hh * cosA + cy);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(uv1);

        // Bottom-right
        vertices.push( hw * cosA + hh * sinA + cx);
        vertices.push( hw * sinA - hh * cosA + cy);
        vertices.push(0.0);
        vertices.push(region.u2);
        vertices.push(uv2);

        // Bottom-left
        vertices.push(-hw * cosA + hh * sinA + cx);
        vertices.push(-hw * sinA - hh * cosA + cy);
        vertices.push(0.0);
        vertices.push(region.u1);
        vertices.push(uv2);
    }

    /**
     * Build vertex array from current tile data
     * Called every frame - no dirty tracking needed
     */
    // private function buildVertexArray():Void {
    //     vertices = [];
        
    //     var tileCount = 0;
        
    //     // Generate vertices for each tile in current data
    //     for (tileData in __currentTileData) {
    //         if (!tileData.visible) continue;
            
    //         // Generate vertices for this tile
    //         var tileVertices = generateTileVertices(tileData);
    //         for (vertex in tileVertices) {
    //             vertices.push(vertex);
    //         }
            
    //         tileCount++;
    //     }
        
    //     // Update render counts (indices are pre-generated, just set count)
    //     __verticesToRender = tileCount * 4;  // 4 vertices per tile
    //     __indicesToRender = tileCount * 6;   // 6 indices per tile (2 triangles)
    // }
    
    public function buildTile(tile:Tile):Void {
        generateTileVertices(tile);
        __verticesToRender += 4;
        __indicesToRender += 6;
    }

    /**
     * Update buffers - orphan and upload strategy
     * Called BEFORE render to update vertex data
     */
    override public function updateBuffers(renderer:Renderer):Void {
        if (!__active || textures[0] == null) return;

        //__verticesToRender = 0;
        //__indicesToRender = 0;
        
        // Allocate buffer on first update only
        // if (__bufferCapacity == 0) {
        //     __bufferCapacity = MAX_TILES;
        //     renderer.allocateTileBatchBuffers(this, MAX_TILES);
        // }
        
        // Rebuild vertex array from visible tiles (every frame)
        //buildVertexArray();
        
        // Update vertices object for renderer
        //this.vertices = new Vertices(__vertexCache);

        if (vertices.length > 0) {

            // GL.bindBuffer(GL.ARRAY_BUFFER, vbo);
            
            // // Orphan old buffer storage
            // var maxBufferSize = MAX_TILES * 4 * 5 * 4;
            // untyped __cpp__("glBufferData({0}, {1}, NULL, {2})", GL.ARRAY_BUFFER, maxBufferSize, GL.STREAM_DRAW);
            
            // // Now upload the actual data using standard method
            // GL.bufferFloatArray(GL.ARRAY_BUFFER, vertices, GL.STREAM_DRAW, vertices.length);
            
            // GL.bindBuffer(GL.ARRAY_BUFFER, 0);
            renderer.orphanAndUploadData(__bufferId, vertices, indices, MAX_TILES * 4 * 5 * 4);
            //renderer.uploadData(this);
        }
        
        needsBufferUpdate = false;
    }
    
    /**
     * Render the tile batch
     * Just sets uniforms - vertex data already updated in updateBuffers()
     */
    override public function render(renderer:Renderer,cameraMatrix:Matrix, cameraDirty:Bool):Void {
        if (!__active || textures[0] == null) return;

        vertices.dispose();
        __verticesToRender = 0;
        __indicesToRender = 0;

        needsBufferUpdate = true;
        updateBuffers(renderer);

        if (__verticesToRender == 0 || __indicesToRender == 0) return;

        var finalMatrix = Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        uniforms.set("uMatrix", finalMatrix.data);

        renderer.renderDisplayObject(this);
    }

    override public function postRender():Void {
        // Reset counts after rendering
        // __verticesToRender = 0;
        // __indicesToRender = 0;

        // vertices = [];
    }
    
    /**
     * Get atlas region (for reading properties)
     */
    public function getRegion(regionId:Int):AtlasRegion {
        return atlasRegions.get(regionId);
    }
    
    /**
     * Check if a region exists
     */
    public function hasRegion(regionId:Int):Bool {
        return atlasRegions.exists(regionId);
    }
    
    /**
     * Get the number of defined regions
     */
    public function getRegionCount():Int {
        var count = 0;
        for (key in atlasRegions.keys()) count++;
        return count;
    }

    public function clearRegions():Void {
        atlasRegions.clear();
        __nextRegionId = 1;
    }
}

/**
 * Data structure representing an atlas region
 */
class AtlasRegion {
    public var x:Int = 0;              // Atlas X coordinate in pixels
    public var y:Int = 0;              // Atlas Y coordinate in pixels
    public var width:Int = 1;          // Atlas width in pixels
    public var height:Int = 1;         // Atlas height in pixels
    public var u1:Float = 0.0;         // Calculated left UV coordinate
    public var v1:Float = 0.0;         // Calculated top UV coordinate
    public var u2:Float = 1.0;         // Calculated right UV coordinate
    public var v2:Float = 1.0;         // Calculated bottom UV coordinate
    
    public function new() {}
}