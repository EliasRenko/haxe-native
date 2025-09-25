
// TODO: Replace sys.FileSystem with SDL IO functions (SDL_GetPathInfo)
import sys.FileSystem;

import Promise;
import loaders.TGALoader;
import data.Resource;
import data.TextureData;

private class __Resources {
    // Privates
    private var __resources:Map<String, Resource> = new Map<String, Resource>();
    private var __parent:App;
    private var __resourceFolder:String;

    public function new(app:App, resourceFolder:String = "res") {
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

            try {
                var bytes = __parent.loadBytes(fullPath);
                var data:String = bytes.toString();
                if (cache) __resources.set(fullPath, {type: 'text', data: data, size: bytes.length});
                resolve(data);
            } catch (e:Dynamic) {
                reject("Failed to load text file: " + fullPath + " - " + e);
            }
        });
    }

    public function loadShader(vertexPath:String, fragmentPath:String, cache:Bool = true):Promise<{vertex:String, fragment:String}> {
        var fullVertexPath = __resourceFolder + "/" + vertexPath;
        var fullFragmentPath = __resourceFolder + "/" + fragmentPath;
        return new Promise<{vertex:String, fragment:String}>((resolve, reject) -> {
            try {
                var vertexBytes = __parent.loadBytes(fullVertexPath);
                var fragmentBytes = __parent.loadBytes(fullFragmentPath);
                var vertex = vertexBytes.toString();
                var fragment = fragmentBytes.toString();
                if (cache) {
                    __resources.set(fullVertexPath, {type: 'text', data: vertex, size: vertexBytes.length});
                    __resources.set(fullFragmentPath, {type: 'text', data: fragment, size: fragmentBytes.length});
                }
                resolve({vertex: vertex, fragment: fragment});
            } catch (e:Dynamic) {
                reject("Failed to load shader files: " + e);
            }
        });
    }

    public function loadTexture(path:String, cache:Bool = true):Promise<TextureData> {
        var fullPath = __resourceFolder + "/" + path;
        return new Promise<TextureData>((resolve, reject) -> {
            try {
                var bytes = __parent.loadBytes(fullPath);
                // Parse TGA
                var textureData = TGALoader.loadFromBytes(bytes);
                
                if (cache) {
                    __resources.set(fullPath, {type: 'texture', data: textureData, size: bytes.length});
                }
                
                // trace("Loaded texture: " + fullPath + " (" + textureData.width + "x" + textureData.height + ")"); // Disabled - RESOURCES category
                resolve(textureData);
                
            } catch (e:Dynamic) {
                reject("Failed to load texture: " + e);
            }
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
    }
}

typedef Resources = __Resources;