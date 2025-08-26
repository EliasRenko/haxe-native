package utils;

import Promise;
//import data.TextureData;

typedef Resource = {
    var type:String;
    var data:Dynamic;
}

class Resources {
    private var __resources:Map<String, Resource> = new Map<String, Resource>();

    public function new() {}

    public function exists(name:String):Bool {
        if (__resources.exists(name)) {
            return true;
        }
        return false;
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

    // public function getTexture(name:String):TextureData {
    //     if (__resources.exists(name)) {
    //         var _resource:Resource = __resources.get(name);
    //         return cast(_resource.data, TextureData);
    //     }
    //     return null;
    // }

    public function getShader(name:String):String {
        if (__resources.exists(name)) {
            var _resource:Resource = __resources.get(name);
            return cast(_resource.data, String);
        }
        return null;
    }

    public function loadText(path:String, cache:Bool = true):Promise<String> {
       return null;
    }

    public function loadShader(path:String, cache:Bool = true):Promise<String> {
       return null;
    }

    // public function loadTexture(path:String, cache:Bool = true):Promise<TextureData> {
    //     return null;
    // }
}