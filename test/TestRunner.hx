package test;

/**
 * Simple test runner for the engine
 * Provides utilities for running and organizing tests
 */
class TestRunner {
    
    private static var tests:Array<{name:String, func:()->Void}> = [];
    
    public static function addTest(name:String, testFunc:()->Void):Void {
        tests.push({name: name, func: testFunc});
    }
    
    public static function runAllTests():Void {
        trace("=== Running Engine Tests ===");
        
        var passed = 0;
        var failed = 0;
        
        for (test in tests) {
            trace('Running test: ${test.name}');
            
            try {
                test.func();
                trace('✓ ${test.name} PASSED');
                passed++;
            } catch (e:Dynamic) {
                trace('✗ ${test.name} FAILED: $e');
                failed++;
            }
        }
        
        trace("=== Test Results ===");
        trace('Passed: $passed, Failed: $failed, Total: ${passed + failed}');
        
        if (failed == 0) {
            trace("🎉 All tests passed!");
        } else {
            trace("❌ Some tests failed.");
        }
    }
    
    public static function runSpecificTests():Void {
        trace("=== Running Specific Engine Tests ===");
        
        // Promise API tests
        PromiseTest.testPromises();
        
        // Add more specific test calls here as we create them
        
        trace("=== Specific tests complete ===");
    }
}
