package display;

class Tile {
    public var x:Float = 0.0;          // World X position
    public var y:Float = 0.0;          // World Y position
    public var width:Float = 1.0;      // Tile width in world units
    public var height:Float = 1.0;     // Tile height in world units
    public var regionId:Int = 0;       // Atlas region ID to use for UV coordinates
    public var parent:TileBatch; // Reference to parent TileBatch
    public var visible:Bool = true;   // Visibility flag
    public var offsetX:Float = 0.0;   // Offset X position
    public var offsetY:Float = 0.0;   // Offset Y position
    public var rotation:Float = 0.0;  // Rotation in degrees
    public function new(parent:TileBatch, regionId:Int = 0) {
        this.parent = parent;
        this.regionId = regionId;
    }
}