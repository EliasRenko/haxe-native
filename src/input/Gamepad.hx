package input;

import core.EventDispacher;
import input.Device;
import types.GamepadInputEvent;


class Gamepad extends EventDispacher<GamepadInputEvent> {

    // Publics
    
    public var index(get, null):UInt;
    public var id(get, null):UInt;

    // Privates

    private var __index:UInt;

    public function new(index:UInt) {
        super();
        
        __index = index;
    }

    public function close():Void {
        
    }

    // Getters and setters

    private function get_index():UInt {
        return __index;
    }

    public function get_id():UInt {
        return 0;
    }
}