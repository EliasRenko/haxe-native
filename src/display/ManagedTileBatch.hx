package display;

import ProgramInfo;
import Renderer;
import Texture;
import data.Vertices;
import data.Indices;
import math.Matrix;
import display.Tile;
import shaders.TexturedShader;

/**
 * ManagedTileBatch - Extends TileBatch with tile management
 * 
 * Provides the full TileBatch API for adding, removing, and updating tiles,
 * while using the primitive TileBatch for efficient rendering.
 */
class ManagedTileBatch extends DisplayObject {
    
    public static inline var MAX_TILES:Int = 1000; // Maximum tiles supported

    public var atlasRegions:Map<Int, AtlasRegion> = new Map(); // regionId -> AtlasRegion
    public var texture:Texture; // The atlas texture for all tiles
    
    private var __nextRegionId:Int = 1; // Auto-incrementing region ID
    private var __bufferCapacity:Int = 0; // Current buffer capacity in tiles
    private var __matrix:Matrix = new Matrix();
    private var __verticesToRender:Int = 0;
	private var __indicesToRender:UInt = 0;

    private var tiles:Map<Int, Tile> = new Map(); // tileId -> TileInstance
    private var __nextTileId:Int = 1; // Auto-incrementing tile ID
    
    /**
     * Create a new ManagedTileBatch
     * @param programInfo Shader program for rendering (optional when subclass uses @:shader)
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
        shader = new TexturedShader();
        //if (programInfo != null) this.programInfo = programInfo;
        
        //__bufferId = renderer.createBuffers(shader.programInfoIndex);

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
        this.texture = texture;
        
        __bufferCapacity = 0; // Will be allocated on first init
    }
    
    /**
     * Add a tile to the batch using a predefined atlas region
     * @param x World X position
     * @param y World Y position
     * @param width Tile width in world units
     * @param height Tile height in world units
     * @param regionId Atlas region ID (from defineRegion)
     * @return Tile ID for future reference
     */
    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        if (!atlasRegions.exists(regionId)) {
            trace("ManagedTileBatch: Error - Region ID " + regionId + " does not exist!");
            return -1;
        }
        
        var tileId = __nextTileId++;
        
        var tile = new Tile(null);
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.regionId = regionId;
        
        tiles.set(tileId, tile);
        
        return tileId;
    }

    /**
     * Add existing Tile instance
     */
    public function addTileInstance(tile:Tile):Void {
        if (tile == null) return;
        var tileId = __nextTileId++;
        tiles.set(tileId, tile);
    }
    
    /**
     * Remove a tile from the batch
     * @param tileId Tile ID to remove
     * @return True if tile was found and removed
     */
    public function removeTile(tileId:Int):Bool {
        return tiles.remove(tileId);
    }
    
    /**
     * Remove tile instance
     */
    public function removeTileInstance(tile:Tile):Bool {
        for (tileId in tiles.keys()) {
            if (tiles.get(tileId) == tile) {
                tiles.remove(tileId);
                return true;
            }
        }
        return false;
    }
    
    /**
     * Update a tile's position
     * @param tileId Tile ID to update
     * @param x New world X position
     * @param y New world Y position
     * @return True if tile was found and updated
     */
    public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
        if (tiles.exists(tileId)) {
            var tile = tiles.get(tileId);
            tile.x = x;
            tile.y = y;
            return true;
        }
        return false;
    }
    
    /**
     * Clear all tiles from the batch
     */
    public function clear():Void {
        tiles.clear();
    }
    
    /**
     * Get the number of tiles in the batch
     */
    public function getTileCount():Int {
        var count = 0;
        for (key in tiles.keys()) count++;
        return count;
    }
    
    /**
     * Check if a tile exists
     */
    public function hasTile(tileId:Int):Bool {
        return tiles.exists(tileId);
    }
    
    /**
     * Get tile instance (for reading properties)
     */
    public function getTile(tileId:Int):Tile {
        return tiles.get(tileId);
    }
    
    /**
     * Update buffers - build tile data from stored tiles and pass to base class
     */
    override public function updateBuffers(renderer:Renderer):Void {
        // Build all tiles into the vertices/indices arrays
        for (tile in tiles) {
            if (tile.visible) buildTile(tile);
        }
        
        if (vertices.length > 0) {
            renderer.orphanAndUploadData(__bufferId, vertices, indices, MAX_TILES * 4 * 5 * 4);
        }
        
        __needsBufferUpdate = false;
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
        region.u1 = atlasX / texture.width;
        region.v1 = atlasY / texture.height;
        region.u2 = (atlasX + atlasWidth) / texture.width;
        region.v2 = (atlasY + atlasHeight) / texture.height;
        
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

        region.u1 = atlasX / texture.width;
        region.v1 = atlasY / texture.height;
        region.u2 = (atlasX + atlasWidth) / texture.width;
        region.v2 = (atlasY + atlasHeight) / texture.height;

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

    public function buildTile(tile:Tile):Void {
        generateTileVertices(tile);
        __verticesToRender += 4;
        __indicesToRender += 6;
    }
    
    public function render(renderer:Renderer):Void {
        vertices.dispose();
        __verticesToRender = 0;
        __indicesToRender = 0;

        __needsBufferUpdate = true;
        updateBuffers(renderer);

        if (__verticesToRender == 0 || __indicesToRender == 0) return;

        var finalMatrix = Matrix.copy(__matrix);
        finalMatrix.append(renderer.matrix);
        shader.setUniform("uMatrix", finalMatrix.data);
        //uniforms.set("uMatrix", finalMatrix.data);

        // 1. Get the program info for the current shader program
		var programInfo = renderer.programInfosGen[shader.programInfoIndex];

		// 2. Use the shader program (binds the program and VAO)
		renderer.useProgram(programInfo);

		// 3. Bind the buffers (VAO) for this object
		renderer.bindBuffers(__bufferId, programInfo.vertexStride);

		// 4. Set the blending factors for transparency
		renderer.setBlendFunction(blending.source, blending.destination);

		// 5. Set the uniform values for the shader program
		//renderer.renderUniforms(programInfo, this);

        renderer.renderUniforms(programInfo, this);

		// 6. Set the textures for the shader program
		renderer.bindTexture(texture.id, 0);

		// 7. Draw the object using the specified mode and count
		renderer.drawElements(mode, __indicesToRender);
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