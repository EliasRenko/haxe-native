
package data;

import display.Tile;

/**
 * TileBatch manages tile instances and atlas regions.
 *
 * Rendering, geometry generation, GPU buffers, textures, and shaders
 * are handled by the renderer or rendering pipeline.
 */
class TileBatch {

    public static inline var MAX_TILES:Int = 1000;

    /** Atlas dimensions in pixels, used to calculate normalized UVs. */
    public var atlasWidth(default, null):Int;
    public var atlasHeight(default, null):Int;

    /** Atlas regions indexed by region ID. */
    public var atlasRegions:Map<Int, AtlasRegion> = new Map();

    /** Tile instances indexed by tile ID. */
    private var tiles:Map<Int, Tile> = new Map();

    private var __nextRegionId:Int = 1;
    private var __nextTileId:Int = 1;

    /**
     * Create a TileBatch.
     *
     * @param atlasWidth Width of the atlas coordinate space in pixels.
     * @param atlasHeight Height of the atlas coordinate space in pixels.
     */
    public function new(atlasWidth:Int, atlasHeight:Int) {
        if (atlasWidth <= 0 || atlasHeight <= 0) {
            throw "TileBatch: Atlas dimensions must be greater than zero.";
        }

        this.atlasWidth = atlasWidth;
        this.atlasHeight = atlasHeight;
    }

    // -------------------------------------------------------------------------
    // Tile management
    // -------------------------------------------------------------------------

    /**
     * Add a tile using a predefined atlas region.
     *
     * @return The tile ID, or -1 if the region does not exist.
     */
    public function addTile(
        x:Float,
        y:Float,
        width:Float,
        height:Float,
        regionId:Int
    ):Int {
        if (!atlasRegions.exists(regionId)) {
            trace("TileBatch: Error - Region ID " + regionId + " does not exist!");
            return -1;
        }

        var tileId = __nextTileId++;

        var tile = new Tile(this);
        tile.x = x;
        tile.y = y;
        tile.width = width;
        tile.height = height;
        tile.regionId = regionId;

        tiles.set(tileId, tile);

        return tileId;
    }

    /**
     * Add an existing Tile instance.
     */
    public function addTileInstance(tile:Tile):Void {
        if (tile == null) {
            return;
        }

        var tileId = __nextTileId++;
        tiles.set(tileId, tile);
    }

    /**
     * Remove a tile by ID.
     *
     * @return True if the tile was found and removed.
     */
    public function removeTile(tileId:Int):Bool {
        return tiles.remove(tileId);
    }

    /**
     * Remove a tile instance.
     *
     * @return True if the tile was found and removed.
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
     * Update a tile's position.
     */
    public function updateTilePosition(
        tileId:Int,
        x:Float,
        y:Float
    ):Bool {
        var tile = tiles.get(tileId);

        if (tile == null) {
            return false;
        }

        tile.x = x;
        tile.y = y;

        return true;
    }

    /**
     * Remove all tiles.
     */
    public function clear():Void {
        tiles.clear();
    }

    /**
     * Get the number of tiles in the batch.
     */
    public function getTileCount():Int {
        var count = 0;

        for (_ in tiles.keys()) {
            count++;
        }

        return count;
    }

    /**
     * Check whether a tile exists.
     */
    public function hasTile(tileId:Int):Bool {
        return tiles.exists(tileId);
    }

    /**
     * Get a tile instance by ID.
     */
    public function getTile(tileId:Int):Tile {
        return tiles.get(tileId);
    }

    /**
     * Iterate over all tile instances.
     *
     * The renderer uses this to generate geometry.
     */
    public function getTiles():Iterator<Tile> {
        return tiles.iterator();
    }

    // -------------------------------------------------------------------------
    // Atlas region management
    // -------------------------------------------------------------------------

    /**
     * Define an atlas region using pixel coordinates.
     *
     * @return The new region ID.
     */
    public function defineRegion(
        atlasX:Int,
        atlasY:Int,
        regionWidth:Int,
        regionHeight:Int
    ):Int {
        var regionId = __nextRegionId++;

        var region = new AtlasRegion();
        region.x = atlasX;
        region.y = atlasY;
        region.width = regionWidth;
        region.height = regionHeight;

        updateRegionUVs(region);

        atlasRegions.set(regionId, region);

        return regionId;
    }

    /**
     * Update an existing atlas region without changing its ID.
     *
     * @return True if the region was found and updated.
     */
    public function updateRegion(
        regionId:Int,
        atlasX:Int,
        atlasY:Int,
        regionWidth:Int,
        regionHeight:Int
    ):Bool {
        var region = atlasRegions.get(regionId);

        if (region == null) {
            return false;
        }

        region.x = atlasX;
        region.y = atlasY;
        region.width = regionWidth;
        region.height = regionHeight;

        updateRegionUVs(region);

        return true;
    }

    /**
     * Recalculate normalized UV coordinates from pixel coordinates.
     *
     * V orientation is preserved as in the original implementation.
     * Any vertex-level V flip remains the renderer's responsibility.
     */
    private function updateRegionUVs(region:AtlasRegion):Void {
        region.u1 = region.x / atlasWidth;
        region.v1 = region.y / atlasHeight;
        region.u2 = (region.x + region.width) / atlasWidth;
        region.v2 = (region.y + region.height) / atlasHeight;
    }

    /**
     * Get an atlas region by ID.
     */
    public function getRegion(regionId:Int):AtlasRegion {
        return atlasRegions.get(regionId);
    }

    /**
     * Check whether an atlas region exists.
     */
    public function hasRegion(regionId:Int):Bool {
        return atlasRegions.exists(regionId);
    }

    /**
     * Get the number of defined atlas regions.
     */
    public function getRegionCount():Int {
        var count = 0;

        for (_ in atlasRegions.keys()) {
            count++;
        }

        return count;
    }

    /**
     * Remove all atlas regions and reset region ID allocation.
     *
     * Existing tiles are not removed.
     */
    public function clearRegions():Void {
        atlasRegions.clear();
        __nextRegionId = 1;
    }
}

/**
 * Atlas region in pixel coordinates and normalized UV coordinates.
 */
class AtlasRegion {
    public var x:Int = 0;
    public var y:Int = 0;

    public var width:Int = 1;
    public var height:Int = 1;

    public var u1:Float = 0.0;
    public var v1:Float = 0.0;
    public var u2:Float = 1.0;
    public var v2:Float = 1.0;

    public function new() {}
}
