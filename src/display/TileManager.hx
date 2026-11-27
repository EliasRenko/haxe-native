package display;

import Renderer;
import Texture;
import data.Vertices;
import data.Indices;
import math.Matrix;
import shaders.TexturedShader;
import ds.SlotArray;

enum abstract TileUpdateMode(Int) {
    var Static;
    var Dynamic;
    var Stream;
}

/**
 * TileManager owns tile and atlas data and can rebuild/upload a tile batch.
 *
 * Subclasses may override buildTile and buildOrder to add custom vertex data
 * or UI metadata while retaining the same dirty-state and upload policies.
 */
class TileManager extends DisplayObject {
    public static inline var DEFAULT_CAPACITY:Int = 1000;

    public var texture(get, set):Texture;
    public var updateMode(default, set):TileUpdateMode = Dynamic;
    public var debugName:String = "";
    public var needsBufferUpdate(get, set):Bool;

    public var atlasRegions:SlotArray<AtlasRegion>;

    private var __texture:Texture;
    private var __tiles:SlotArray<Tile>;
    private var __capacity:Int;
    private var __matrix:Matrix = new Matrix();
    private var __finalMatrix:Matrix = new Matrix();
    private var __verticesToRender:Int = 0;
    private var __indicesToRender:UInt = 0;

    private var __uploadFunction:(Renderer) -> Void;

	public function new(renderer:Renderer, texture:Texture, capacity:Int = DEFAULT_CAPACITY, updateMode:TileUpdateMode = Dynamic) {
		if (texture == null)
			throw "TileManager requires a texture";
		if (capacity < 1)
			throw "TileManager capacity must be positive";

		__capacity = capacity;
        atlasRegions = new SlotArray<AtlasRegion>();
        __tiles = new SlotArray<Tile>(capacity);
		super(renderer, new Vertices([]), generateIndices(capacity));

		mode = GL.TRIANGLES;
		blending = {
			source: GL.ONE,
			destination: GL.ONE_MINUS_SRC_ALPHA
		};

		this.texture = texture;
		this.updateMode = updateMode;
		markDirty();
	}

    private function assignShader():data.Shader {
        return new TexturedShader();
    }

    private function get_texture():Texture {
        return __texture;
    }

    private function set_texture(value:Texture):Texture {
        __texture = value;
        if (value != null) shader.setUniform("uTexture", value);
        markDirty();
        return value;
    }

    private function get_updateMode():TileUpdateMode {
        return updateMode;
    }

    private function set_updateMode(value:TileUpdateMode):TileUpdateMode {
        updateMode = value;

        if (value == Stream) {
            __uploadFunction = function(renderer:Renderer):Void {
                renderer.orphanAndUploadData(
                    __bufferId,
                    vertices,
                    indices,
                    __capacity * 4 * 5 * 4
                );
            };
        } else {
            __uploadFunction = function(renderer:Renderer):Void {
                renderer.uploadData(__bufferId, vertices, indices);
            };
        }

        markDirty();
        return value;
    }

    public function setCapacity(capacity:Int):Void {
        if (capacity < 1) throw "TileManager capacity must be positive";
        if (capacity == __capacity) return;
        if (capacity < __tiles.count) throw "TileManager capacity cannot be smaller than its tile count";

        __capacity = capacity;
        __tiles.reserve(capacity);
        indices.dispose();
        var newIndices = generateIndices(capacity);
        for (index in newIndices.data) indices.push(index);
        markDirty();
    }

    public function setTexture(value:Texture):Void {
        texture = value;
    }

    private function get_needsBufferUpdate():Bool {
        return __needsBufferUpdate;
    }

    private function set_needsBufferUpdate(value:Bool):Bool {
        __needsBufferUpdate = value;
        return value;
    }

    public function markDirty():Void {
        __needsBufferUpdate = true;
    }

    public function markTileDirty(tile:Tile):Void {
        markDirty();
    }

	public function defineRegion(atlasX:Int, atlasY:Int, regionWidth:Int, regionHeight:Int):Int {
		if (__texture == null)
			throw "TileManager has no atlas texture";

		var region = new AtlasRegion();
		region.x = atlasX;
		region.y = atlasY;
		region.width = regionWidth;
		region.height = regionHeight;
		updateRegionUVs(region);
		var regionId = atlasRegions.add(region);
		markDirty();
		return regionId;
	}

	public function updateRegion(regionId:Int, atlasX:Int, atlasY:Int, regionWidth:Int, regionHeight:Int):Bool {
		var region = atlasRegions.get(regionId);
		if (region == null)
			return false;

		region.x = atlasX;
		region.y = atlasY;
		region.width = regionWidth;
		region.height = regionHeight;
		updateRegionUVs(region);
		markDirty();
		return true;
	}

    private function updateRegionUVs(region:AtlasRegion):Void {
        if (__texture == null) return;
        region.u1 = region.x / __texture.width;
        region.v1 = region.y / __texture.height;
        region.u2 = (region.x + region.width) / __texture.width;
        region.v2 = (region.y + region.height) / __texture.height;
    }

    public function getRegion(regionId:Int):AtlasRegion {
        return atlasRegions.get(regionId);
    }

    public function hasRegion(regionId:Int):Bool {
        return atlasRegions.isValid(regionId);
    }

    public function getRegionCount():Int {
        return atlasRegions.count;
    }

    public function clearRegions():Void {
        for (tile in __tiles) {
            tile.onChanged = null;
            if (tile.parent == this) tile.parent = null;
        }
        __tiles.clear();
        atlasRegions.clear();
        markDirty();
    }

	public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
		if (!hasRegion(regionId))
			return -1;
		if (__tiles.count >= __capacity)
			growCapacity();

		var tile = new Tile(this, regionId);
		tile.onChanged = markDirty;
		tile.x = x;
		tile.y = y;
		tile.width = width;
		tile.height = height;
		var tileId = __tiles.add(tile);
		markDirty();
		return tileId;
	}

    public function addTileInstance(tile:Tile):Int {
        if (tile == null) return -1;

        var existingId = __tiles.indexOf(tile);
        if (existingId >= 0) return existingId;

        if (__tiles.count >= __capacity) growCapacity();

        tile.parent = this;
        tile.onChanged = markDirty;
        var tileId = __tiles.add(tile);
        markDirty();
        return tileId;
    }

    public function removeTile(tileId:Int):Bool {
        var tile = __tiles.get(tileId);
        if (tile == null) return false;

        __tiles.remove(tileId);
        tile.onChanged = null;
        if (tile.parent == this) tile.parent = null;
        markDirty();
        return true;
    }

    public function removeTileInstance(tile:Tile):Bool {
        if (tile == null) return false;

        var tileId = __tiles.indexOf(tile);
        if (tileId < 0) return false;

        __tiles.remove(tileId);
        tile.onChanged = null;
        if (tile.parent == this) tile.parent = null;
        markDirty();
        return true;
    }

    public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
        var tile = __tiles.get(tileId);
        if (tile == null) return false;

        tile.x = x;
        tile.y = y;
        markDirty();
        return true;
    }

    public function clear():Void {
        if (__tiles.count == 0) return;

        for (tile in __tiles) {
            tile.onChanged = null;
            if (tile.parent == this) tile.parent = null;
        }
        __tiles.clear();
        markDirty();
    }

    public function getTileCount():Int {
        return __tiles.count;
    }

    public function hasTile(tileId:Int):Bool {
        return __tiles.isValid(tileId);
    }

    public function getTile(tileId:Int):Tile {
        return __tiles.get(tileId);
    }

    public function getTiles():Iterator<Tile> {
        return __tiles.iterator();
    }

    public function getCapacity():Int {
        return __capacity;
    }

    private function growCapacity():Void {
        setCapacity(__capacity * 2);
    }

    private static function generateIndices(tileCount:Int):Indices {
        var indices:Array<UIntData> = [];

        for (i in 0...tileCount) {
            var vertexIndex:UIntData = i * 4;
            indices.push(vertexIndex + 0);
            indices.push(vertexIndex + 1);
            indices.push(vertexIndex + 2);
            indices.push(vertexIndex + 0);
            indices.push(vertexIndex + 2);
            indices.push(vertexIndex + 3);
        }

        return new Indices(indices);
    }

    /**
     * Override this method to emit a custom vertex layout.
     * The default layout is x, y, z, u, v.
     */
    public function buildTile(tile:Tile):Void {
        var region = getRegion(tile.regionId);
        if (region == null) return;

        var uvTop = region.v2;
        var uvBottom = region.v1;
        var x = tile.x + tile.offsetX;
        var y = tile.y + tile.offsetY;
        var hw = tile.width * 0.5;
        var hh = tile.height * 0.5;
        var cx = x + hw;
        var cy = y + hh;

        var cosA = 1.0;
        var sinA = 0.0;
        if (tile.rotation != 0.0) {
            var rad = tile.rotation * Math.PI / 180.0;
            cosA = Math.cos(rad);
            sinA = Math.sin(rad);
        }

        pushVertex(-hw * cosA - hh * sinA + cx, -hw * sinA + hh * cosA + cy, region.u1, uvTop);
        pushVertex(hw * cosA - hh * sinA + cx, hw * sinA + hh * cosA + cy, region.u2, uvTop);
        pushVertex(hw * cosA + hh * sinA + cx, hw * sinA - hh * cosA + cy, region.u2, uvBottom);
        pushVertex(-hw * cosA + hh * sinA + cx, -hw * sinA - hh * cosA + cy, region.u1, uvBottom);

        __verticesToRender += 4;
        __indicesToRender += 6;
    }

    private function pushVertex(x:Float, y:Float, u:Float, v:Float):Void {
        vertices.push(x);
        vertices.push(y);
        vertices.push(0.0);
        vertices.push(u);
        vertices.push(v);
    }

    override public function updateBuffers(renderer:Renderer):Void {
        if (!__needsBufferUpdate) return;

        vertices.dispose();
        __verticesToRender = 0;
        __indicesToRender = 0;

        for (tile in __tiles) {
            if (tile.visible) buildTile(tile);
        }

        if (vertices.length > 0) {
            __uploadFunction(renderer);
        }

        __needsBufferUpdate = false;
    }

    public function render(renderer:Renderer):Void {
        if (!visible) return;

        updateBuffers(renderer);
        if (__verticesToRender == 0 || __indicesToRender == 0) return;

        Matrix.multiplyInto(__finalMatrix, __matrix, renderer.matrix);
        shader.setUniform("uMatrix", __finalMatrix.data);

        var programInfo = renderer.getProgramInfo(shader.programInfoIndex);
        renderer.useProgram(programInfo);
        renderer.bindBuffers(__bufferId, programInfo.vertexStride);
        renderer.setBlendFunction(blending.source, blending.destination);
        renderer.renderUniforms(programInfo, shader);
        renderer.drawElements(mode, __indicesToRender);
    }
}

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
