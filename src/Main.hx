package;

import App;

class Main {
    public static function main() {
        trace("Clean engine starting...");
        
        // Create application instance
        var app = new App();
        
        // Initialize the application
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }
        
        // Run the application
        app.run();
        
        // Cleanup
        app.cleanup();
        
        trace("Clean shutdown complete");
    }
}
