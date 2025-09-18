import SDL;
import EventDispacher;
import haxe.ds.Vector;

private class __Input {
    private var __parent:App;
    private var __gamepads:Map<SDL.SDL_JoystickID, cpp.Pointer<SDL.SDL_Gamepad>> = new Map<SDL.SDL_JoystickID, cpp.Pointer<SDL.SDL_Gamepad>>();
    
    // Input state tracking
    private var __keyStates:Map<Int, Bool> = new Map<Int, Bool>();
    private var __keyPressed:Array<Int> = [];
    private var __keyReleased:Array<Int> = [];
    
    private var __mouseStates:Map<Int, Bool> = new Map<Int, Bool>();
    private var __mousePressed:Array<Int> = [];
    private var __mouseReleased:Array<Int> = [];
    private var __mouseX:Float = 0;
    private var __mouseY:Float = 0;
    private var __mouseDeltaX:Float = 0;
    private var __mouseDeltaY:Float = 0;
    private var __mouseWheelX:Float = 0;
    private var __mouseWheelY:Float = 0;
    
    private var __gamepadStates:Map<String, Bool> = new Map<String, Bool>(); // "gamepadId_button" -> pressed
    private var __gamepadPressed:Array<String> = [];
    private var __gamepadReleased:Array<String> = [];
    private var __gamepadAxes:Map<String, Float> = new Map<String, Float>(); // "gamepadId_axis" -> value
    
    public function new(app:App) {
        this.__parent = app;
    }
    
    public function init():Void {
        __parent.log.info(Log.CATEGORY_INPUT, "Input system initialized");
    }

    public function release():Void {
        __parent.log.info(Log.CATEGORY_INPUT, "Input system shutting down");
        
        // TODO: Close all open gamepads when SDL gamepad bindings are available
        // for (gamepadId in __gamepads.keys()) {
        //     var gamepad = __gamepads.get(gamepadId);
        //     if (gamepad != null) {
        //         SDL.closeGamepad(gamepad);
        //     }
        // }
        __gamepads.clear();
        
        // Clear all input states
        __keyStates.clear();
        __keyPressed = [];
        __keyReleased = [];
        __mouseStates.clear();
        __mousePressed = [];
        __mouseReleased = [];
        __gamepadStates.clear();
        __gamepadPressed = [];
        __gamepadReleased = [];
        __gamepadAxes.clear();
    }

    public function update():Void {
        // Reset delta values
        __mouseDeltaX = 0;
        __mouseDeltaY = 0;
        __mouseWheelX = 0;
        __mouseWheelY = 0;
    }

    public function postUpdate():Void {
        // Clear pressed/released arrays for next frame
        __keyPressed = [];
        __keyReleased = [];
        __mousePressed = [];
        __mouseReleased = [];
        __gamepadPressed = [];
        __gamepadReleased = [];
    }
    
    // === GAMEPAD EVENT HANDLERS ===
    
    public function onGamepadConnected():Void {
        __parent.log.info(Log.CATEGORY_INPUT, "Gamepad connected");
        
        // Get all available gamepad instance IDs
        var count:Int = 0;
        var countPtr = cpp.Pointer.addressOf(count);
        var gamepadIds = SDL.getGamepads(countPtr);
        
        if (gamepadIds != null && count > 0) {
            __parent.log.info(Log.CATEGORY_INPUT, "Found " + count + " gamepads");
            
            for (i in 0...count) {
                var id = gamepadIds[i];
                if (!__gamepads.exists(id)) {
                    var gamepad = SDL.openGamepad(id);
                    if (gamepad != null) {
                        __gamepads.set(id, gamepad);
                        var name = SDL.getGamepadName(gamepad);
                        __parent.log.info(Log.CATEGORY_INPUT, "Opened gamepad " + id + ": " + name);
                    } else {
                        __parent.log.info(Log.CATEGORY_INPUT, "Failed to open gamepad " + id);
                    }
                }
            }
        } else {
            __parent.log.info(Log.CATEGORY_INPUT, "No gamepads found during connection event");
        }
    }
    
    public function onGamepadDisconnected():Void {
        __parent.log.info(Log.CATEGORY_INPUT, "Gamepad disconnected");
        
        // Find and remove disconnected gamepads
        var count:Int = 0;
        var countPtr = cpp.Pointer.addressOf(count);
        var gamepadIds = SDL.getGamepads(countPtr);
        var connectedIds:Array<SDL.SDL_JoystickID> = [];
        
        if (gamepadIds != null && count > 0) {
            for (i in 0...count) {
                connectedIds.push(gamepadIds[i]);
            }
        }
        
        // Check which gamepads we have open but are no longer connected
        var toRemove:Array<SDL.SDL_JoystickID> = [];
        for (id in __gamepads.keys()) {
            if (connectedIds.indexOf(id) == -1) {
                toRemove.push(id);
            }
        }
        
        // Close and remove disconnected gamepads
        for (id in toRemove) {
            var gamepad = __gamepads.get(id);
            if (gamepad != null) {
                SDL.closeGamepad(gamepad);
                __parent.log.info(Log.CATEGORY_INPUT, "Closed gamepad " + id);
            }
            __gamepads.remove(id);
            
            // Clear all input states for this gamepad
            var keysToRemove:Array<String> = [];
            for (key in __gamepadStates.keys()) {
                if (key.indexOf(id + "_") == 0) {
                    keysToRemove.push(key);
                }
            }
            for (key in keysToRemove) {
                __gamepadStates.remove(key);
            }
        }
    }
    
    public function onGamepadButtonPressed(event:SDL.PtrEvent):Void {
        // Extract gamepad and button info from event
        var gamepadId = event.value.gbutton.which;
        var button = event.value.gbutton.button;
        __parent.log.info(Log.CATEGORY_INPUT, "Gamepad button pressed - ID: " + gamepadId + ", Button: " + button);
        
        var key = gamepadId + "_" + button;
        __gamepadStates.set(key, true);
    }
    
    public function onGamepadButtonReleased(event:SDL.PtrEvent):Void {
        var gamepadId = event.value.gbutton.which;
        var button = event.value.gbutton.button;
        __parent.log.info(Log.CATEGORY_INPUT, "Gamepad button released - ID: " + gamepadId + ", Button: " + button);
        
        var key = gamepadId + "_" + button;
        __gamepadStates.set(key, false);
    }
    
    public function onGamepadAxisMotion(event:SDL.PtrEvent):Void {
        var gamepadId = event.value.gaxis.which;
        var axis = event.value.gaxis.axis;
        var value = event.value.gaxis.value / 32767.0; // Normalize to -1.0 to 1.0
        
        // Only log significant axis changes to avoid spam (threshold of 0.1)
        if (Math.abs(value) > 0.1) {
            __parent.log.info(Log.CATEGORY_INPUT, "Gamepad axis motion - ID: " + gamepadId + ", Axis: " + axis + ", Value: " + value);
        }
        
        // Store axis value (you can implement gamepad axis storage if needed)
        // var key = gamepadId + "_" + axis;
        // __gamepadAxes.set(key, value);
    }
    
    // === KEYBOARD EVENT HANDLERS ===
    
    public function onKeyPressed(event:Dynamic):Void {
        __parent.log.debug(Log.CATEGORY_INPUT, "Key pressed");
        
        // TODO: When SDL bindings are complete:
        // var scancode = event.value.key.scancode;
        // __keyStates.set(scancode, true);
        // __keyPressed.push(scancode);
    }
    
    public function onKeyReleased(event:Dynamic):Void {
        __parent.log.debug(Log.CATEGORY_INPUT, "Key released");
        
        // TODO: When SDL bindings are complete:
        // var scancode = event.value.key.scancode;
        // __keyStates.set(scancode, false);
        // __keyReleased.push(scancode);
    }
    
    // === MOUSE EVENT HANDLERS ===
    
    public function onMouseButtonPressed(event:Dynamic):Void {
        __parent.log.debug(Log.CATEGORY_INPUT, "Mouse button pressed");
        
        // TODO: When SDL bindings are complete:
        // var button = event.value.button.button;
        // __mouseStates.set(button, true);
        // __mousePressed.push(button);
    }
    
    public function onMouseButtonReleased(event:Dynamic):Void {
        __parent.log.debug(Log.CATEGORY_INPUT, "Mouse button released");
        
        // TODO: When SDL bindings are complete:
        // var button = event.value.button.button;
        // __mouseStates.set(button, false);
        // __mouseReleased.push(button);
    }
    
    public function onMouseMotion(event:Dynamic):Void {
        // TODO: When SDL bindings are complete:
        // var newX = event.value.motion.x;
        // var newY = event.value.motion.y;
        // __mouseDeltaX = newX - __mouseX;
        // __mouseDeltaY = newY - __mouseY;
        // __mouseX = newX;
        // __mouseY = newY;
    }
    
    public function onMouseWheel(event:Dynamic):Void {
        __parent.log.debug(Log.CATEGORY_INPUT, "Mouse wheel");
        
        // TODO: When SDL bindings are complete:
        // __mouseWheelX = event.value.wheel.x;
        // __mouseWheelY = event.value.wheel.y;
    }
    
    // === PUBLIC INPUT QUERY METHODS ===
    
    // Keyboard methods
    public function isKeyDown(scancode:Int):Bool {
        return __keyStates.exists(scancode) && __keyStates.get(scancode);
    }
    
    public function isKeyPressed(scancode:Int):Bool {
        return __keyPressed.indexOf(scancode) != -1;
    }
    
    public function isKeyReleased(scancode:Int):Bool {
        return __keyReleased.indexOf(scancode) != -1;
    }
    
    // Mouse methods
    public function isMouseButtonDown(button:Int):Bool {
        return __mouseStates.exists(button) && __mouseStates.get(button);
    }
    
    public function isMouseButtonPressed(button:Int):Bool {
        return __mousePressed.indexOf(button) != -1;
    }
    
    public function isMouseButtonReleased(button:Int):Bool {
        return __mouseReleased.indexOf(button) != -1;
    }
    
    public function getMouseX():Float { return __mouseX; }
    public function getMouseY():Float { return __mouseY; }
    public function getMouseDeltaX():Float { return __mouseDeltaX; }
    public function getMouseDeltaY():Float { return __mouseDeltaY; }
    public function getMouseWheelX():Float { return __mouseWheelX; }
    public function getMouseWheelY():Float { return __mouseWheelY; }
    
    // Gamepad methods
    public function isGamepadButtonDown(gamepadId:Int, button:Int):Bool {
        var key = gamepadId + "_" + button;
        return __gamepadStates.exists(key) && __gamepadStates.get(key);
    }
    
    public function isGamepadButtonPressed(gamepadId:Int, button:Int):Bool {
        var key = gamepadId + "_" + button;
        return __gamepadPressed.indexOf(key) != -1;
    }
    
    public function isGamepadButtonReleased(gamepadId:Int, button:Int):Bool {
        var key = gamepadId + "_" + button;
        return __gamepadReleased.indexOf(key) != -1;
    }
    
    public function getGamepadAxis(gamepadId:Int, axis:Int):Float {
        var key = gamepadId + "_" + axis;
        return __gamepadAxes.exists(key) ? __gamepadAxes.get(key) : 0.0;
    }
    
    public function getConnectedGamepads():Array<Int> {
        var ids:Array<Int> = [];
        for (id in __gamepads.keys()) {
            ids.push(id);
        }
        return ids;
    }
    
    public function getGamepadName(gamepadId:Int):String {
        // TODO: Implement when SDL gamepad bindings are available
        // var gamepad = __gamepads.get(gamepadId);
        // return gamepad != null ? SDL.getGamepadName(gamepad) : "Unknown";
        return "Gamepad " + gamepadId;
    }
}

class InputDevice<T> extends EventDispacher<T> {

	// ** Privates
	private var __checkControls:Vector<Bool>;
    private var __checkCount:Int = 0;
    private var __controlsCount:Int;
    private var __pressControls:Array<Int>;
    private var __pressCount:Int = 0;
    private var __releaseControls:Array<Int>;
    private var __releaseCount:Int = 0;
	
	public function check(control:Int):Bool{
		return control < 0 ? __checkCount > 0 : __checkControls[control];
	}
	
	public function pressed(control:Int):Bool {
		return control < 0 ? __pressCount > 0 : __pressControls.indexOf(control) >= 0;
	}

	public function getAllPressed():Array<Int> {
		var pressed:Array<Int> = new Array<Int>();
		for (i in 0...__pressCount) {
			pressed.push(__pressControls[i]);
		}
		return pressed;
	}
	
	public function released(control:Int):Bool {
		return control < 0 ? __releaseCount > 0 : __releaseControls.indexOf(control) >= 0;
	}
	
	private function __indexOf(vector:Array<Int>, index:Int):Int {
		for (i in 0...vector.length) {
			if (vector[i] == index) {
				return i;
			}
		}

		return -1;
	}
	
	public function postUpdate():Void {

		// Clear every pressed control for the next frame.
		while (__pressCount > 0) {
			__pressControls[-- __pressCount] = -1;
		}
		
		// Clear every released control for the next frame.
		while (__releaseCount > 0) {
			__releaseControls[-- __releaseCount] = -1;
		}
	}
}

typedef Input = __Input;