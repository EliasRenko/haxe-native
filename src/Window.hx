package;

import cpp.Pointer;

@:include("SDL3/SDL.h")
@:native("SDL_Window")
extern class SDL_Window {}

typedef Window = Pointer<SDL_Window>;