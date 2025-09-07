package data;

import data.TextureData;

/**
 * Represents an OpenGL texture that has been uploaded to the GPU.
 * Contains the GL texture ID and essential metadata like dimensions.
 */
class Texture {
    
    // ** Publics.
    
    /**
     * The OpenGL texture ID.
     */
    public var id(get, null):UInt;
    
    /**
     * The width of the texture in pixels.
     */
    public var width(get, null):Int;
    
    /**
     * The height of the texture in pixels.
     */
    public var height(get, null):Int;
    
    /**
     * Whether the texture has transparency.
     */
    public var transparent(get, null):Bool;
    
    /**
     * The number of bytes per pixel.
     */
    public var bytesPerPixel(get, null):Int;
    
    // ** Privates.
    
    private var __id:UInt;
    private var __width:Int;
    private var __height:Int;
    private var __transparent:Bool;
    private var __bytesPerPixel:Int;
    
    /**
     * Creates a new Texture instance.
     * @param id The OpenGL texture ID
     * @param textureData The original TextureData used to create this texture
     */
    public function new(id:UInt, textureData:TextureData) {
        __id = id;
        __width = textureData.width;
        __height = textureData.height;
        __transparent = textureData.transparent;
        __bytesPerPixel = textureData.bytesPerPixel;
    }
    
    /**
     * Creates a new Texture instance with explicit parameters.
     * @param id The OpenGL texture ID
     * @param width The texture width in pixels
     * @param height The texture height in pixels
     * @param transparent Whether the texture has transparency
     * @param bytesPerPixel The number of bytes per pixel
     */
    public static function create(id:UInt, width:Int, height:Int, transparent:Bool = false, bytesPerPixel:Int = 4):Texture {
        var texture = new Texture.__createEmpty();
        texture.__id = id;
        texture.__width = width;
        texture.__height = height;
        texture.__transparent = transparent;
        texture.__bytesPerPixel = bytesPerPixel;
        return texture;
    }
    
    /**
     * Private constructor for static create method.
     */
    private function __createEmpty() {
        // Empty constructor for static creation
    }
    
    /**
     * Returns a string representation of this texture.
     */
    public function toString():String {
        return 'Texture(id=$__id, ${__width}x${__height}, bpp=$__bytesPerPixel, transparent=$__transparent)';
    }
    
    // ** Getters.
    
    private function get_id():UInt {
        return __id;
    }
    
    private function get_width():Int {
        return __width;
    }
    
    private function get_height():Int {
        return __height;
    }
    
    private function get_transparent():Bool {
        return __transparent;
    }
    
    private function get_bytesPerPixel():Int {
        return __bytesPerPixel;
    }
}
