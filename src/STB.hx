package;

import cpp.RawPointer;
import cpp.UInt8;
import cpp.ConstCharStar;
import cpp.Pointer;
import cpp.Star;

@:keep
@:buildXml(
'<files id="haxe">
    <compilerflag value="-Iinclude"/>
    <compilerflag value="-Iinclude/stb"/>
    <compilerflag value="-DHXCPP_NO_PCH"/>
    <compilerflag value="-DHXCPP_NO_PRECOMPILED_HEADERS"/>
</files>')
@:include("stb/stb_image.h")
extern class STB {
    
    /**
     * Load an image from file (supports PNG, JPG, TGA, BMP, PSD, GIF, HDR, PIC)
     * @param filename Path to the image file
     * @param x Pointer to store image width
     * @param y Pointer to store image height  
     * @param channels_in_file Pointer to store number of channels in the original file
     * @param desired_channels Number of channels you want (0=auto, 1=grey, 2=grey+alpha, 3=RGB, 4=RGBA)
     * @return Pointer to image data (unsigned char array), or null on failure
     */
    @:native("stbi_load")
    static function load(filename:ConstCharStar, x:Pointer<Int>, y:Pointer<Int>, channels_in_file:Pointer<Int>, desired_channels:Int):RawPointer<UInt8>;
    
    /**
     * Load an image from memory buffer
     * @param buffer Pointer to image data in memory
     * @param len Length of the buffer in bytes
     * @param x Pointer to store image width
     * @param y Pointer to store image height
     * @param channels_in_file Pointer to store number of channels in the original file
     * @param desired_channels Number of channels you want (0=auto, 1=grey, 2=grey+alpha, 3=RGB, 4=RGBA)
     * @return Pointer to image data (unsigned char array), or null on failure
     */
    @:native("stbi_load_from_memory")
    static function loadFromMemory(buffer:RawPointer<UInt8>, len:Int, x:Pointer<Int>, y:Pointer<Int>, channels_in_file:Pointer<Int>, desired_channels:Int):RawPointer<UInt8>;
    
    /**
     * Free image data returned by stbi_load or stbi_load_from_memory
     * @param retval_from_stbi_load Pointer returned from stbi_load/stbi_load_from_memory
     */
    @:native("stbi_image_free")
    static function imageFree(retval_from_stbi_load:RawPointer<UInt8>):Void;
    
    /**
     * Get image info without loading the full image (from file)
     * @param filename Path to the image file
     * @param x Pointer to store image width
     * @param y Pointer to store image height
     * @param comp Pointer to store number of components
     * @return 1 on success, 0 on failure
     */
    @:native("stbi_info")
    static function info(filename:ConstCharStar, x:Pointer<Int>, y:Pointer<Int>, comp:Pointer<Int>):Int;
    
    /**
     * Get image info without loading the full image (from memory)
     * @param buffer Pointer to image data in memory
     * @param len Length of the buffer in bytes
     * @param x Pointer to store image width
     * @param y Pointer to store image height
     * @param comp Pointer to store number of components
     * @return 1 on success, 0 on failure
     */
    @:native("stbi_info_from_memory")
    static function infoFromMemory(buffer:RawPointer<UInt8>, len:Int, x:Pointer<Int>, y:Pointer<Int>, comp:Pointer<Int>):Int;
    
    /**
     * Get failure reason string for the last stbi_load operation
     * @return Error message string
     */
    @:native("stbi_failure_reason")
    static function failureReason():ConstCharStar;
    
    // Channel format constants
    @:native("STBI_grey")
    static var GREY(default, null):Int;
    
    @:native("STBI_grey_alpha") 
    static var GREY_ALPHA(default, null):Int;
    
    @:native("STBI_rgb")
    static var RGB(default, null):Int;
    
    @:native("STBI_rgb_alpha")
    static var RGB_ALPHA(default, null):Int;
    
    // Convenience functions for easier usage
    
    /**
     * Helper function to create pointers for width/height/channels
     */
    static inline function createImageInfo():{width:Pointer<Int>, height:Pointer<Int>, channels:Pointer<Int>} {
        var width:Pointer<Int> = null;
        var height:Pointer<Int> = null; 
        var channels:Pointer<Int> = null;
        untyped __cpp__("
            int w, h, c;
            {0} = &w;
            {1} = &h; 
            {2} = &c;
        ", width, height, channels);
        return {width: width, height: height, channels: channels};
    }
}