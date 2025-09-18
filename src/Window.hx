package;

class Window {

    // Publics
    public var ptr(get, null):WindowPtr;

    // Privates
    private var __windowPtr:WindowPtr;

    public function new(ptr:WindowPtr) {
        __windowPtr = ptr;
    }
    
    // Getters and setters
    private function get_ptr():WindowPtr {
        return __windowPtr;
    }
}


// import cpp.Pointer;

// @:include("SDL3/SDL.h")
// @:native("SDL_Window")
// extern class SDL_Window {}

// typedef Window = Pointer<SDL_Window>;