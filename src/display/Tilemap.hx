package display;

import Renderer;
import Texture;
import data.Vertices;
import data.Indices;
import math.Matrix;
import display.Tile;
import shaders.TexturedShader;

/**
 * Tilemap - Renders tiles managed by a TileBatch.
 *
 * TileBatch owns tile instances and atlas-region data.
 * Tilemap owns vertex generation, GPU buffers, and draw submission.
 */
class Tilemap extends DisplayObject {
	public static inline var MAX_TILES:Int = 1000;

	public var tileBatch(default, null):TileBatch;
	public var texture:Texture;

	private var __matrix:Matrix = new Matrix();
	private var __verticesToRender:Int = 0;
	private var __indicesToRender:UInt = 0;

	public function new(renderer:Renderer, texture:Texture) {
		super(renderer, new Vertices([]), generateIndices(MAX_TILES));

		shader = new TexturedShader();
		this.texture = texture;
		this.tileBatch = new TileBatch(texture.width, texture.height);

		mode = GL.TRIANGLES;

		// Premultiplied-alpha blending, matching the original implementation.
		blending = {
			source: GL.ONE,
			destination: GL.ONE_MINUS_SRC_ALPHA
		};
	}

	// -------------------------------------------------------------------------
	// Tile management — delegated to TileBatch
	// -------------------------------------------------------------------------

	public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
		if (!tileBatch.hasRegion(regionId)) {
			trace("Tilemap: Error - Region ID " + regionId + " does not exist!");
			return -1;
		}

		var tileId = tileBatch.addTile(x, y, width, height, regionId);
		markDirty();
		return tileId;
	}

	public function addTileInstance(tile:Tile):Void {
		if (tile == null)
			return;
		tileBatch.addTileInstance(tile);
		markDirty();
	}

	public function removeTile(tileId:Int):Bool {
		var removed = tileBatch.removeTile(tileId);
		if (removed)
			markDirty();
		return removed;
	}

	public function removeTileInstance(tile:Tile):Bool {
		var removed = tileBatch.removeTileInstance(tile);
		if (removed)
			markDirty();
		return removed;
	}

	public function updateTilePosition(tileId:Int, x:Float, y:Float):Bool {
		var updated = tileBatch.updateTilePosition(tileId, x, y);
		if (updated)
			markDirty();
		return updated;
	}

	public function clear():Void {
		tileBatch.clear();
		markDirty();
	}

	public function getTileCount():Int {
		return tileBatch.getTileCount();
	}

	public function hasTile(tileId:Int):Bool {
		return tileBatch.hasTile(tileId);
	}

	public function getTile(tileId:Int):Tile {
		return tileBatch.getTile(tileId);
	}

	// -------------------------------------------------------------------------
	// Atlas regions — delegated to TileBatch
	// -------------------------------------------------------------------------

	public function defineRegion(atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Int {
		var regionId = tileBatch.defineRegion(atlasX, atlasY, atlasWidth, atlasHeight);

		markDirty();
		return regionId;
	}

	public function updateRegion(regionId:Int, atlasX:Int, atlasY:Int, atlasWidth:Int, atlasHeight:Int):Bool {
		var updated = tileBatch.updateRegion(regionId, atlasX, atlasY, atlasWidth, atlasHeight);

		if (updated)
			markDirty();
		return updated;
	}

	public function getRegion(regionId:Int) {
		return tileBatch.getRegion(regionId);
	}

	public function hasRegion(regionId:Int):Bool {
		return tileBatch.hasRegion(regionId);
	}

	public function getRegionCount():Int {
		return tileBatch.getRegionCount();
	}

	public function clearRegions():Void {
		tileBatch.clearRegions();
		markDirty();
	}

	// -------------------------------------------------------------------------
	// Rendering
	// -------------------------------------------------------------------------

	private function markDirty():Void {
		__needsBufferUpdate = true;
	}

	/**
	 * Pre-generate indices once. Each tile uses four vertices and six indices.
	 */
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
	 * Build vertex data for one tile.
	 *
	 * Vertex format: x, y, z, u, v.
	 * Retains the original V-coordinate flip and rotation behavior.
	 */
	private function generateTileVertices(tile:Tile):Void {
		var region = tileBatch.getRegion(tile.regionId);

		if (region == null) {
			// Preserve the old fallback for missing regions.
			vertices.push(-1.0);
			vertices.push(-1.0);
			vertices.push(0.0);
			vertices.push(-1.0);
			vertices.push(-1.0);

			vertices.push(-1.0);
			vertices.push(-1.0);
			vertices.push(0.0);
			vertices.push(-1.0);
			vertices.push(-1.0);

			vertices.push(-1.0);
			vertices.push(-1.0);
			vertices.push(0.0);
			vertices.push(-1.0);
			vertices.push(-1.0);

			vertices.push(-1.0);
			vertices.push(-1.0);
			vertices.push(0.0);
			vertices.push(-1.0);
			vertices.push(-1.0);

			return;
		}

		// Preserve the original V flip.
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

		// Top-left
		vertices.push(-hw * cosA - hh * sinA + cx);
		vertices.push(-hw * sinA + hh * cosA + cy);
		vertices.push(0.0);
		vertices.push(region.u1);
		vertices.push(uvTop);

		// Top-right
		vertices.push(hw * cosA - hh * sinA + cx);
		vertices.push(hw * sinA + hh * cosA + cy);
		vertices.push(0.0);
		vertices.push(region.u2);
		vertices.push(uvTop);

		// Bottom-right
		vertices.push(hw * cosA + hh * sinA + cx);
		vertices.push(hw * sinA - hh * cosA + cy);
		vertices.push(0.0);
		vertices.push(region.u2);
		vertices.push(uvBottom);

		// Bottom-left
		vertices.push(-hw * cosA + hh * sinA + cx);
		vertices.push(-hw * sinA - hh * cosA + cy);
		vertices.push(0.0);
		vertices.push(region.u1);
		vertices.push(uvBottom);
	}

	public function buildTile(tile:Tile):Void {
		generateTileVertices(tile);
		__verticesToRender += 4;
		__indicesToRender += 6;
	}

	override public function updateBuffers(renderer:Renderer):Void {
		// The batch can be changed through TileBatch directly, so rebuild
		// the visible tile geometry whenever this method is called.
		vertices.dispose();
		__verticesToRender = 0;
		__indicesToRender = 0;

		for (tile in tileBatch.getTiles()) {
			if (tile.visible) {
				buildTile(tile);
			}
		}

		if (vertices.length > 0) {
			renderer.orphanAndUploadData(__bufferId, vertices, indices, MAX_TILES * 4 * 5 * 4);
		}

		__needsBufferUpdate = false;
	}

	override public function render(renderer:Renderer):Void {
		vertices.dispose();
		__verticesToRender = 0;
		__indicesToRender = 0;

		__needsBufferUpdate = true;
		updateBuffers(renderer);

		if (__verticesToRender == 0 || __indicesToRender == 0) {
			return;
		}

		var finalMatrix = Matrix.copy(__matrix);
		finalMatrix.append(renderer.matrix);
		shader.setUniform("uMatrix", finalMatrix.data);

		var programInfo = renderer.programInfosGen[shader.programInfoIndex];

		renderer.useProgram(programInfo);
		renderer.bindBuffers(__bufferId, programInfo.vertexStride);
		renderer.setBlendFunction(blending.source, blending.destination);

		renderer.renderUniforms(programInfo, this);

		renderer.bindTexture(texture.id, 0);
		renderer.drawElements(mode, __indicesToRender);
	}
}