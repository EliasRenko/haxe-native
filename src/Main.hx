package;

import SDL;
import GL;
import Renderer;

class Main {
    public static function main() {
        trace("Clean engine starting...");
        
        // Initialize SDL
        if (!SDL.init(SDL.INIT_VIDEO)) {
            trace("Failed to initialize SDL: " + SDL.getError());
            return;
        }
        
        trace("SDL initialized successfully");
        
        // Set OpenGL attributes (3.3 Core)
        SDL.setAttribute(SDL.GL_CONTEXT_MAJOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_MINOR_VERSION, 3);
        SDL.setAttribute(SDL.GL_CONTEXT_PROFILE_MASK, SDL.GL_CONTEXT_PROFILE_CORE);
        
        // Create window
        var window = SDL.createWindow("Clean SDL Engine", 640, 480, SDL.WINDOW_OPENGL);
        if (window == null) {
            trace("Failed to create window: " + SDL.getError());
            SDL.quit();
            return;
        }
        
        trace("Window created successfully");
        
        // Create OpenGL context
        var context = SDL.createContext(window);
        if (context == null) {
            trace("Failed to create OpenGL context: " + SDL.getError());
            SDL.quit();
            return;
        }
        
        SDL.makeCurrent(window, context);
        
        // Load OpenGL functions
        var gladResult = GL.gladLoadGLLoader(SDL.getProcAddress);
        if (gladResult == 0) {
            trace("Failed to load OpenGL functions");
            SDL.quit();
            return;
        }
        
        trace("OpenGL loaded successfully");
        trace("OpenGL Version: " + GL.version.major + "." + GL.version.minor);
        
        // Create renderer
        trace("About to create renderer...");
        var renderer = new Renderer(800, 600);
        trace("Renderer created successfully!");
        
        trace("Starting render loop... (Close the window to exit)");
        
        // Main loop
        var running = true;
        var frameCount = 0;
        while (running) {
            frameCount++;
            
            // Poll events
            var event = SDL.getEvent();
            while (SDL.pollEvent(event)) {
                if (event.value.type == SDL.EVENT_QUIT) {
                    trace("Quit event received");
                    running = false;
                } else if (event.value.type == SDL.EVENT_WINDOW_CLOSE_REQUESTED) {
                    trace("Window close requested");
                    running = false;
                }
            }
            
            // Render
            renderer.render();
            
            // Swap buffers
            SDL.swapWindow(window);
            
            // Show progress occasionally
            if (frameCount % 60 == 0) {
                trace("Frame: " + frameCount + " (Window should be visible - close it to exit)");
            }
        }
        
        // Cleanup
        renderer.cleanup();
        SDL.quit();
        
        trace("Clean shutdown complete");
    }
}