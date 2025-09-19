import SDL;
import Promise;
import sys.FileSystem;
import haxe.io.Bytes;
import cpp.Pointer;
import cpp.UInt64;
import cpp.NativeString;
import loaders.TGALoader;
import data.Resource;
import data.TextureData;

private class __Resources {
    // Privates
    private var __resources:Map<String, Resource> = new Map<String, Resource>();
    private var __parent:AppNative;
    private var __resourceFolder:String;

    public function new(app:AppNative, resourceFolder:String = "res") {
        this.__parent = app;
        this.__resourceFolder = resourceFolder;
    }

    public function cached(name:String):Bool {
        var fullPath = __resourceFolder + "/" + name;
        if (__resources.exists(fullPath)) {
            return true;
        }
        return false;
    }

    public function exists(path:String):Bool {
        var fullPath = __resourceFolder + "/" + path;
        try {
            return FileSystem.exists(fullPath);
        } catch (e:Dynamic) {
            return false;
        }
    }

    public function getText(name:String):String {
        var fullPath = __resourceFolder + "/" + name;
        if (__resources.exists(fullPath)) {
            var _resource:Resource = __resources.get(fullPath);
            if (_resource == null) {
                return null;
            }
            return cast(_resource.data, String);
        }
        return null;
    }

    public function getTexture(name:String):TextureData {
        var fullPath = __resourceFolder + "/" + name;
        if (__resources.exists(fullPath)) {
            var _resource:Resource = __resources.get(fullPath);
            if (_resource == null || _resource.type != 'texture') {
                return null;
            }
            return cast(_resource.data, TextureData);
        }
        return null;
    }

    public function loadText(path:String, cache:Bool = true):Promise<String> {
        var fullPath = __resourceFolder + "/" + path;
        return new Promise<String>((resolve, reject) -> {

            var size:UInt64 = 0; // Size in bytes
            var ptrSize:Pointer<UInt64> = Pointer.addressOf(size);
            var ptrData = SDL.loadFile(fullPath, ptrSize.ptr);
            if (ptrData == null) {
                reject("Failed to open file: " + fullPath);
            }

            var data:String = NativeString.fromPointer(ptrData);
            if (cache) __resources.set(fullPath, {type: 'text', data: data, size: size.toInt()});
            resolve(data);

            // trace("Loaded file: " + fullPath + " with size: " + size.toInt() + " bytes"); // Disabled - RESOURCES category
            SDL.free(ptrData);
        });
    }

    public function loadShader(vertexPath:String, fragmentPath:String, cache:Bool = true):Promise<{vertex:String, fragment:String}> {
        return new Promise<{vertex:String, fragment:String}>((resolve, reject) -> {
            var vertexPromise = loadText(vertexPath, cache);
            var fragmentPromise = loadText(fragmentPath, cache);
            
            Promise.all([vertexPromise, fragmentPromise])
                .then(function(results:Array<String>) {
                    resolve({
                        vertex: results[0],
                        fragment: results[1]
                    });
                })
                .onError(function(error:String) {
                    reject(error);
                });
        });
    }

    public function loadTexture(path:String, cache:Bool = true):Promise<TextureData> {
        var fullPath = __resourceFolder + "/" + path;
        return new Promise<TextureData>((resolve, reject) -> {
            
            var size:UInt64 = 0;
            var ptrSize:Pointer<UInt64> = Pointer.addressOf(size);
            var ptrData = SDL.loadFile(fullPath, ptrSize.ptr);
            if (ptrData == null) {
                reject("Failed to open texture file: " + fullPath);
                return;
            }

            try {
                // Convert raw data to Haxe Bytes
                var bytes = haxe.io.Bytes.alloc(size.toInt());
                for (i in 0...size.toInt()) {
                    bytes.set(i, ptrData[i]);
                }
                
                // Parse TGA
                var textureData = TGALoader.loadFromBytes(bytes);
                
                if (cache) {
                    __resources.set(fullPath, {type: 'texture', data: textureData, size: size.toInt()});
                }
                
                // trace("Loaded texture: " + fullPath + " (" + textureData.width + "x" + textureData.height + ")"); // Disabled - RESOURCES category
                resolve(textureData);
                
            } catch (e:Dynamic) {
                reject("Failed to parse TGA file: " + e);
            }
            
            SDL.free(ptrData);
        });
    }
    
    public function release():Void {
        // trace("Cleaning up resources..."); // Disabled - RESOURCES category
        var count = 0;
        for (key in __resources.keys()) {
            var resource = __resources.get(key);
            if (resource != null) {
                count++;
                // Dispose texture data if it's a texture
                if (resource.type == 'texture') {
                    var textureData:TextureData = cast(resource.data, TextureData);
                    if (textureData != null) {
                        textureData.dispose();
                    }
                }
                // For text resources, data is just a String reference, no special cleanup needed
                // Future: Add specific cleanup for other resource types
            }
        }
        __resources.clear();
        // trace('Cleared $count cached resources'); // Disabled - RESOURCES category
    }
}

typedef Resources = __Resources;