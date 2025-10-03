package;

import Entity;
import Camera;
import App;

/**
 * Base class for game states (worlds/scenes/levels)
 * States manage collections of entities and handle state-specific logic
 */
class State {
    
    // State properties
    public var active:Bool = true;
    public var app(get, null):App;
    public var camera:Camera;
    public var entities:Array<Entity> = [];
    public var name:String;
    public var id:Int;
    
    // Private reference to app for accessing renderer
    private var __app:App;
    
    // Private state counter for auto-generating IDs
    private static var __nextId:Int = 0;
    
    public function new(name:String, app:App) {
        this.name = name;
        this.id = __nextId++;
        this.entities = [];
        this.__app = app;
        
        // Initialize camera for this state
        this.camera = new Camera();
        // Set reasonable defaults for 3D perspective
        camera.ortho = false;
        camera.x = 0.0;
        camera.y = 0.0;
        camera.z = 3.0; // Move camera back to see objects
        camera.pitch = 0.0;
        camera.yaw = 0.0;
        camera.roll = 0.0;
        
        trace("Created state '" + name + "' with ID " + id + " and camera");
    }
    
    /**
     * Called every frame to update state logic
     * Override in subclasses for state-specific behavior
     */
    public function update(deltaTime:Float):Void {
        if (!active) return;
        
        // Update all active entities in this state
        for (entity in entities) {
            if (entity != null && entity.active) {
                entity.update(deltaTime);
            }
        }
    }
    
    /**
     * Called every frame to render state entities
     * Override in subclasses for custom rendering order/effects
     */
    public function render(renderer:Dynamic):Void {
        if (!active) return;
        
        // Calculate camera matrix for this state's world
        // This creates the View + Projection matrix
        camera.renderMatrix(renderer.windowWidth, renderer.windowHeight);
        var viewProjectionMatrix = camera.getMatrix();
        
        // Render all active entities in this state with the camera matrix
        for (entity in entities) {
            if (entity != null && entity.active && entity.visible) {
                if (entity.displayObject == null) {
                    trace("ERROR: Entity '" + entity.id + "' has null displayObject!");
                    continue;
                }
                entity.render(renderer, viewProjectionMatrix);
            }
        }
    }
    
    /**
     * Add an entity to this state
     */
    public function addEntity(entity:Entity):Entity {
        if (entity == null) {
            trace("Warning: Attempted to add null entity to state '" + name + "'");
            return null;
        }
        
        entities.push(entity);
        entity.state = this;
        
        // Initialize DisplayObject when entity is added to state
        if (entity.displayObject != null && !entity.displayObject.initialized) {
            entity.displayObject.init(__app.renderer);
            trace("Initialized DisplayObject for entity '" + entity.id + "'");
        }
        
        trace("Added entity '" + entity.id + "' to state '" + name + "'");
        return entity;
    }
    
    /**
     * Remove an entity from this state
     */
    public function removeEntity(entity:Entity):Bool {
        if (entity == null) return false;
        
        var removed = entities.remove(entity);
        if (removed) {
            entity.state = null;
            trace("Removed entity '" + entity.id + "' from state '" + name + "'");
        }
        return removed;
    }
    
    /**
     * Remove entity by ID
     */
    public function removeEntityById(id:String):Bool {
        for (entity in entities) {
            if (entity.id == id) {
                return removeEntity(entity);
            }
        }
        return false;
    }
    
    /**
     * Find entity by ID
     */
    public function getEntity(id:String):Entity {
        for (entity in entities) {
            if (entity.id == id) {
                return entity;
            }
        }
        return null;
    }
    
    /**
     * Get all entities of a specific type
     */
    public function getEntitiesByType<T:Entity>(type:Class<T>):Array<T> {
        var result:Array<T> = [];
        for (entity in entities) {
            if (Std.isOfType(entity, type)) {
                result.push(cast entity);
            }
        }
        return result;
    }
    
    /**
     * Clear all entities from this state
     */
    public function clearEntities(renderer:Renderer):Void {
        trace("Clearing " + entities.length + " entities from state '" + name + "'");
        for (entity in entities) {
            if (entity != null) {
                entity.state = null;
                // Optionally call cleanup on entities
                if (entity.displayObject != null) {
                    entity.displayObject.remove(renderer);
                }
            }
        }
        entities = [];
    }
    
    /**
     * Called when state becomes active
     * Override in subclasses for state-specific initialization
     */
    public function onActivate():Void {
        trace("State '" + name + "' activated");
        active = true;
    }
    
    /**
     * Called when state becomes inactive
     * Override in subclasses for state-specific cleanup
     */
    public function onDeactivate():Void {
        trace("State '" + name + "' deactivated");
        active = false;
    }
    
    /**
     * Get current entity count
     */
    public function getEntityCount():Int {
        return entities.length;
    }
    
    /**
     * Get debug info about this state
     */
    public function getDebugInfo():String {
        return 'State "${name}" (ID: ${id}) - Entities: ${entities.length}, Active: ${active}';
    }
    
    /**
     * Get app reference
     */
    private function get_app():App {
        return __app;
    }
}
