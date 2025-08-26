package;

import SDL;
import GL;
import Renderer;

typedef Resources = __Resources;

class App {

    // Publics
    public var resources(get, null):Resources;

    // Privates
    private var running:Bool = false;
    private var window:Window;
    private var context:GLContext;
    private var renderer:Renderer;

    private var __resources:__Resources;
    
    public function new() {
        // Constructor - initialize basic properties
    }
    
    public function init():Bool {
        trace("Initializing application...");
        
        // Initialize SDL video
        if (!SDL.init(SDL.INIT_VIDEO)) {
            trace("Failed to initialize SDL: " + SDL.getError());
            return false;
        }
        
        // Set OpenGL attributes (3.3 Core)
        SDL.setAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_MINOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_PROFILE_MASK, SDL.GL_CONTEXT_PROFILE_CORE);
        
        // Create window
        window = SDL.createWindow("Clean SDL Engine", 640, 480, SDL.WINDOW_OPENGL);
        if (window == null) {
            trace("Failed to create window: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        trace("Window created successfully");
        
        // Create OpenGL context
        context = SDL.createContext(window);
        if (context == null) {
            trace("Failed to create OpenGL context: " + SDL.getError());
            SDL.quit();
            return false;
        }
        
        SDL.makeCurrent(window, context);
        
        // Load OpenGL functions
        var gladResult = GL.gladLoadGLLoader(SDL.getProcAddress);
        if (gladResult == 0) {
            trace("Failed to load OpenGL functions");
            SDL.quit();
            return false;
        }
        
        trace("OpenGL loaded successfully");
        trace("OpenGL Version: " + GL.version.major + "." + GL.version.minor);
        
        // Create renderer
        trace("About to create renderer...");
        renderer = new Renderer(800, 600);
        trace("Renderer created successfully!");
        
        // Run tests only in test builds
        #if test
        test.TestRunner.runSpecificTests();
        #end
        
        trace("Application initialized successfully!");
        return true;
    }
    
    public function run():Void {
        if (renderer == null) {
            trace("Error: Application not initialized! Call init() first.");
            return;
        }
        
        trace("Starting main loop... (Close the window to exit)");
        
        running = true;
        var frameCount = 0;
        
        while (running) {
            frameCount++;
            
            // Handle events
            handleEvents();
            
            // Update application logic
            update();
            
            // Render frame
            render();
            
            // Swap buffers
            SDL.swapWindow(window);
            
            // Show progress occasionally
            if (frameCount % 60 == 0) {
                trace("Frame: " + frameCount + " (Window should be visible - close it to exit)");
            }
        }
        
        trace("Main loop ended");
    }
    
    private function handleEvents():Void {
        // Poll SDL events
        var event = SDL.getEvent();
        while (SDL.pollEvent(event)) {
            if (event.value.type == SDL.EVENT_QUIT) {
                trace("Quit event received");
                running = false;
            } else if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                trace("Window close requested");
                running = false;
            }
            // TODO: Add more event handling (keyboard, mouse, etc.)
        }
    }
    
    private function update():Void {
        // TODO: Add application update logic here
        // This is where game logic, physics, etc. would go
    }
    
    private function render():Void {
        // Render the frame
        renderer.render();
    }
    
    public function cleanup():Void {
        trace("Cleaning up application...");
        
        if (renderer != null) {
            renderer.cleanup();
            renderer = null;
        }
        
        SDL.quit();
        
        trace("Application cleanup complete");
    }
    
    public function stop():Void {
        running = false;
    }
    
    // Getters for external access if needed
    public function isRunning():Bool {
        return running;
    }
    
    public function getRenderer():Renderer {
        return renderer;
    }
    
    public function getWindow():Dynamic {
        return window;
    }
}

private class __Resources {
    // Privates
    private var __resources:Map<String, Resource> = new Map<String, Resource>();
    private var __parent:App;

    public function new(app:App) {
        this.__parent = app;
    }

    public function cached(name:String):Bool {
        if (__resources.exists(name)) {
            return true;
        }
        return false;
    }

    public function exists(path:String):Bool {
        try {
            return FileSystem.exists(path);
        } catch (e:Dynamic) {
            return false;
        }
    }

    public function getText(name:String):String {
        if (__resources.exists(name)) {
            var _resource:Resource = __resources.get(name);
            if (_resource == null) {
                return null;
            }
            return cast(_resource.data, String);
        }
        return null;
    }

    public function loadText(path:String, cache:Bool = true):Promise<String> {
        return new Promise<String>((resolve, reject) -> {

            var size:UInt64 = 0; // Size in bytes
            var ptrSize:Pointer<UInt64> = Pointer.addressOf(size);
            var ptrData = SDL.loadFile(path, ptrSize.ptr);
            if (ptrData == null) {
                reject("Failed to open file: " + path);
            }

            var data:String = NativeString.fromPointer(ptrData);
            if (cache) __resources.set(path, {type: 'text', data: data, size: size.toInt()});
            resolve(data);

            __parent.log("Loaded file: " + path + " with size: " + size.toInt() + " bytes");
            SDL.free(ptrData);
        });
    }
}
