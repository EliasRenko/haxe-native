package test;

class TestMain {
    public static function main() {
        trace("=== Engine Test Suite ===");
        
        trace("Running tests without SDL initialization for basic functionality...");
        
        // Run all tests that don't require SDL/OpenGL
        TestRunner.runAllTests();
        TestRunner.runSpecificTests();
        
        trace("=== Test Suite Complete ===");
    }
}
