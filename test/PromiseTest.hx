package test;

import Promise;

class PromiseTest {
    public static function testPromises():Void {
        trace("=== Testing Modern Promise API ===");
        
        // Test 1: Simple resolve
        trace("Test 1: Simple resolve");
        var promise1 = new Promise<String>(function(resolve, reject) {
            resolve("Hello World!");
        });
        
        promise1.then(function(result:String) {
            trace("Promise 1 resolved with: " + result);
        });
        
        // Test 2: Delayed resolve
        trace("Test 2: Delayed resolve (simulated)");
        var promise2 = new Promise<Int>(function(resolve, reject) {
            // Simulate async operation
            resolve(42);
        });
        
        promise2
            .then(function(result:Int) {
                trace("Promise 2 resolved with: " + result);
            })
            .onError(function(error:String) {
                trace("Promise 2 error: " + error);
            });
        
        // Test 3: Rejection
        trace("Test 3: Rejection");
        var promise3 = new Promise<String>(function(resolve, reject) {
            reject("Something went wrong!");
        });
        
        promise3
            .then(function(result:String) {
                trace("This should not be called");
            })
            .onError(function(error:String) {
                trace("Promise 3 rejected with: " + error);
            });
        
        // Test 4: Static methods
        trace("Test 4: Static resolve");
        Promise.resolve("Static resolve test")
            .then(function(result:String) {
                trace("Static promise resolved: " + result);
            });
        
        // Test 5: Promise.all
        trace("Test 5: Promise.all");
        var promises = [
            Promise.resolve(1),
            Promise.resolve(2),
            Promise.resolve(3)
        ];
        
        Promise.all(promises)
            .then(function(results:Array<Int>) {
                trace("Promise.all resolved with: " + results);
            })
            .onError(function(error:String) {
                trace("Promise.all error: " + error);
            });
        
        trace("=== Promise tests complete ===");
    }
}
