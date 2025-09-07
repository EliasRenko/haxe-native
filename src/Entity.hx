package;

import DisplayObject;
import State;
import math.Matrix;

/**
 * Base class for game entities (game objects)
 * Entities are the building blocks of game states - anything that exists in the game world
 */
class Entity {
    
    // Entity properties
    public var displayObject:DisplayObject;
    public var active:Bool = true;
    public var visible:Bool = true;
    public var id:String;
    public var state:State = null; // Reference to parent state
    
    // Transform shortcuts (delegated to displayObject)
    public var x(get, set):Float;
    public var y(get, set):Float;
    public var z(get, set):Float;
    public var rotationX(get, set):Float;
    public var rotationY(get, set):Float;  
    public var rotationZ(get, set):Float;
    public var scaleX(get, set):Float;
    public var scaleY(get, set):Float;
    public var scaleZ(get, set):Float;
    
    // Private entity counter for auto-generating IDs
    private static var __nextId:Int = 0;
    
    public function new(id:String, displayObject:DisplayObject) {
        this.id = id != null ? id : "entity_" + (__nextId++);
        this.displayObject = displayObject;
        
        if (displayObject == null) {
            trace("Warning: Entity '" + this.id + "' created without DisplayObject");
        }
        
        trace("Created entity '" + this.id + "'");
    }
    
    /**
     * Called every frame to update entity logic
     * Override in subclasses for entity-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;
        
        // Base entity update - override in subclasses for custom behavior
        // For example: AI, physics, animation, etc.
    }
    
    /**
     * Called every frame to render this entity
     * Now accepts the view-projection matrix from the State's camera
     */
    public function render(renderer:Dynamic, viewProjectionMatrix:math.Matrix):Void {
        if (!active || !visible || displayObject == null) {
            return;
        }
        
        // Delegate rendering to the displayObject with the view-projection matrix
        renderer.renderDisplayObject(displayObject, viewProjectionMatrix);
    }
    
    /**
     * Clean up entity resources
     */
    public function cleanup(renderer:Renderer):Void {
        if (displayObject != null) {
            displayObject.remove(renderer);
            displayObject = null;
        }
        
        // Remove from state if attached
        if (state != null) {
            state.removeEntity(this);
        }
        
        trace("Entity '" + id + "' cleaned up");
    }
    
    /**
     * Get debug info about this entity
     */
    public function getDebugInfo():String {
        var pos = displayObject != null ? '(${displayObject.x}, ${displayObject.y}, ${displayObject.z})' : '(no display object)';
        return 'Entity "${id}" at ${pos} - Active: ${active}, Visible: ${visible}';
    }
    
    // Transform getters and setters (delegate to displayObject)
    private function get_x():Float {
        return displayObject != null ? displayObject.x : 0.0;
    }
    
    private function set_x(value:Float):Float {
        if (displayObject != null) displayObject.x = value;
        return value;
    }
    
    private function get_y():Float {
        return displayObject != null ? displayObject.y : 0.0;
    }
    
    private function set_y(value:Float):Float {
        if (displayObject != null) displayObject.y = value;
        return value;
    }
    
    private function get_z():Float {
        return displayObject != null ? displayObject.z : 0.0;
    }
    
    private function set_z(value:Float):Float {
        if (displayObject != null) displayObject.z = value;
        return value;
    }
    
    private function get_rotationX():Float {
        return displayObject != null ? displayObject.rotationX : 0.0;
    }
    
    private function set_rotationX(value:Float):Float {
        if (displayObject != null) displayObject.rotationX = value;
        return value;
    }
    
    private function get_rotationY():Float {
        return displayObject != null ? displayObject.rotationY : 0.0;
    }
    
    private function set_rotationY(value:Float):Float {
        if (displayObject != null) displayObject.rotationY = value;
        return value;
    }
    
    private function get_rotationZ():Float {
        return displayObject != null ? displayObject.rotationZ : 0.0;
    }
    
    private function set_rotationZ(value:Float):Float {
        if (displayObject != null) displayObject.rotationZ = value;
        return value;
    }
    
    private function get_scaleX():Float {
        return displayObject != null ? displayObject.scaleX : 1.0;
    }
    
    private function set_scaleX(value:Float):Float {
        if (displayObject != null) displayObject.scaleX = value;
        return value;
    }
    
    private function get_scaleY():Float {
        return displayObject != null ? displayObject.scaleY : 1.0;
    }
    
    private function set_scaleY(value:Float):Float {
        if (displayObject != null) displayObject.scaleY = value;
        return value;
    }
    
    private function get_scaleZ():Float {
        return displayObject != null ? displayObject.scaleZ : 1.0;
    }
    
    private function set_scaleZ(value:Float):Float {
        if (displayObject != null) displayObject.scaleZ = value;
        return value;
    }
}
