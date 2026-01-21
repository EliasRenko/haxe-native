package stb;

import cpp.Pointer;
import cpp.RawPointer;
import cpp.Star;
import cpp.ConstPointer;
import cpp.UInt8;
import cpp.UInt16;

/**
 * Haxe externs for stb_truetype.h - TrueType font processing library
 * 
 * Key features:
 * - Parse TrueType/OpenType font files
 * - Extract glyph metrics
 * - Render glyphs to bitmaps with antialiasing
 * - Generate Signed Distance Field (SDF) bitmaps
 * - Pack multiple fonts into texture atlases
 */
@:keep
@:include("stb/stb_truetype.h")
@:buildXml('
<files id="haxe">
  <compilerflag value="-I${haxelib:haxe-native}/include" />
  <file name="${haxelib:haxe-native}/src/stb/stb_truetype_impl.c" />
</files>
')
@:unreflective
extern class STB_Truetype {
    
    //////////////////////////////////////////////////////////////////////////////
    // TEXTURE BAKING API (Simple 2-function API)
    //////////////////////////////////////////////////////////////////////////////
    
    /**
     * Bake a font bitmap for a range of characters
     * 
     * @param data Font file data (TTF/OTF bytes)
     * @param offset Font offset (use 0 for plain .ttf files)
     * @param pixel_height Height of font in pixels
     * @param pixels Output bitmap buffer (1 channel, 8bpp)
     * @param pw Bitmap width
     * @param ph Bitmap height
     * @param first_char First character to bake (e.g., 32 for space)
     * @param num_chars Number of characters to bake (e.g., 96 for ASCII printable)
     * @param chardata Output array of character data (must be num_chars long)
     * @return Positive: first unused row, Negative: -(characters that fit), 0: no fit
     */
    @:native("stbtt_BakeFontBitmap")
    static function bakeFontBitmap(
        data:ConstPointer<UInt8>,
        offset:Int,
        pixel_height:Float,
        pixels:Pointer<UInt8>,
        pw:Int,
        ph:Int,
        first_char:Int,
        num_chars:Int,
        chardata:Pointer<BakedChar>
    ):Int;
    
    /**
     * Get quad coordinates for rendering a baked character
     * 
     * @param chardata Character data from bakeFontBitmap
     * @param pw Bitmap width
     * @param ph Bitmap height
     * @param char_index Character index (character - first_char)
     * @param xpos Pointer to current X position (updated)
     * @param ypos Pointer to current Y position (updated)
     * @param q Output quad coordinates
     * @param opengl_fillrule Use OpenGL fill rule (1) or D3D9 (0)
     */
    @:native("stbtt_GetBakedQuad")
    static function getBakedQuad(
        chardata:ConstPointer<BakedChar>,
        pw:Int,
        ph:Int,
        char_index:Int,
        xpos:Star<Float>,
        ypos:Star<Float>,
        q:Pointer<AlignedQuad>,
        opengl_fillrule:Int
    ):Void;
    
    /**
     * Query font vertical metrics without creating a font
     * 
     * @param fontdata Font file data
     * @param index Font index in collection (0 for single fonts)
     * @param size Font size in pixels
     * @param ascent Output ascent
     * @param descent Output descent
     * @param lineGap Output line gap
     */
    @:native("stbtt_GetScaledFontVMetrics")
    static function getScaledFontVMetrics(
        fontdata:ConstPointer<UInt8>,
        index:Int,
        size:Float,
        ascent:Star<Float>,
        descent:Star<Float>,
        lineGap:Star<Float>
    ):Void;
    
    //////////////////////////////////////////////////////////////////////////////
    // ADVANCED PACKING API (Better packing, multiple fonts)
    //////////////////////////////////////////////////////////////////////////////
    
    /**
     * Initialize font packing context
     * 
     * @param spc Pack context to initialize
     * @param pixels Bitmap buffer (1 channel)
     * @param width Bitmap width
     * @param height Bitmap height
     * @param stride_in_bytes Row stride (0 = tightly packed)
     * @param padding Padding between characters (typically 1)
     * @param alloc_context Allocator context (NULL for default)
     * @return 1 on success, 0 on failure
     */
    @:native("stbtt_PackBegin")
    static function packBegin(
        spc:Pointer<PackContext>,
        pixels:Pointer<UInt8>,
        width:Int,
        height:Int,
        stride_in_bytes:Int,
        padding:Int,
        alloc_context:RawPointer<cpp.Void>
    ):Int;
    
    /**
     * Clean up packing context and free memory
     */
    @:native("stbtt_PackEnd")
    static function packEnd(spc:Pointer<PackContext>):Void;
    
    /**
     * Pack a range of characters into the atlas
     * 
     * @param spc Pack context
     * @param fontdata Font file data
     * @param font_index Font index (0 for single fonts)
     * @param font_size Font size in pixels
     * @param first_unicode_char First Unicode character
     * @param num_chars Number of characters
     * @param chardata_for_range Output character data
     * @return 1 on success, 0 on failure
     */
    @:native("stbtt_PackFontRange")
    static function packFontRange(
        spc:Pointer<PackContext>,
        fontdata:ConstPointer<UInt8>,
        font_index:Int,
        font_size:Float,
        first_unicode_char:Int,
        num_chars:Int,
        chardata_for_range:Pointer<PackedChar>
    ):Int;
    
    /**
     * Pack multiple ranges into the atlas
     */
    @:native("stbtt_PackFontRanges")
    static function packFontRanges(
        spc:Pointer<PackContext>,
        fontdata:ConstPointer<UInt8>,
        font_index:Int,
        ranges:Pointer<PackRange>,
        num_ranges:Int
    ):Int;
    
    /**
     * Set oversampling for better quality at small sizes
     * 
     * @param spc Pack context
     * @param h_oversample Horizontal oversampling (1 = none, 2 = 2x, etc.)
     * @param v_oversample Vertical oversampling
     */
    @:native("stbtt_PackSetOversampling")
    static function packSetOversampling(
        spc:Pointer<PackContext>,
        h_oversample:Int,
        v_oversample:Int
    ):Void;
    
    /**
     * Get quad coordinates for rendering a packed character
     */
    @:native("stbtt_GetPackedQuad")
    static function getPackedQuad(
        chardata:ConstPointer<PackedChar>,
        pw:Int,
        ph:Int,
        char_index:Int,
        xpos:Star<Float>,
        ypos:Star<Float>,
        q:Pointer<AlignedQuad>,
        align_to_integer:Int
    ):Void;
    
    //////////////////////////////////////////////////////////////////////////////
    // FONT LOADING
    //////////////////////////////////////////////////////////////////////////////
    
    /**
     * Get number of fonts in a font file (.ttc may have multiple)
     */
    @:native("stbtt_GetNumberOfFonts")
    static function getNumberOfFonts(data:ConstPointer<UInt8>):Int;
    
    /**
     * Get byte offset of a font in a collection file
     * 
     * @param data Font file data
     * @param index Font index (0 for first font)
     * @return Byte offset, or -1 if invalid
     */
    @:native("stbtt_GetFontOffsetForIndex")
    static function getFontOffsetForIndex(data:ConstPointer<UInt8>, index:Int):Int;
    
    /**
     * Initialize a fontinfo structure
     * 
     * @param info Font info to initialize
     * @param data Font file data (must remain valid)
     * @param offset Offset from getFontOffsetForIndex (0 for single fonts)
     * @return 1 on success, 0 on failure
     */
    @:native("stbtt_InitFont")
    static function initFont(
        info:Pointer<FontInfo>,
        data:ConstPointer<UInt8>,
        offset:Int
    ):Int;
    
    //////////////////////////////////////////////////////////////////////////////
    // CHARACTER PROPERTIES
    //////////////////////////////////////////////////////////////////////////////
    
    /**
     * Calculate scale factor for a given pixel height
     * 
     * @param info Font info
     * @param pixels Desired height in pixels
     * @return Scale factor to apply to font units
     */
    @:native("stbtt_ScaleForPixelHeight")
    static function scaleForPixelHeight(info:ConstPointer<FontInfo>, pixels:Float):Float;
    
    /**
     * Calculate scale factor for a given EM size
     */
    @:native("stbtt_ScaleForMappingEmToPixels")
    static function scaleForMappingEmToPixels(info:ConstPointer<FontInfo>, pixels:Float):Float;
    
    /**
     * Get font vertical metrics (unscaled)
     * 
     * @param info Font info
     * @param ascent Output ascent above baseline
     * @param descent Output descent below baseline (negative)
     * @param lineGap Output spacing between rows
     */
    @:native("stbtt_GetFontVMetrics")
    static function getFontVMetrics(
        info:ConstPointer<FontInfo>,
        ascent:Star<Int>,
        descent:Star<Int>,
        lineGap:Star<Int>
    ):Void;
    
    /**
     * Get font bounding box
     */
    @:native("stbtt_GetFontBoundingBox")
    static function getFontBoundingBox(
        info:ConstPointer<FontInfo>,
        x0:Star<Int>,
        y0:Star<Int>,
        x1:Star<Int>,
        y1:Star<Int>
    ):Void;
    
    /**
     * Get horizontal metrics for a codepoint
     * 
     * @param info Font info
     * @param codepoint Unicode codepoint
     * @param advanceWidth Output advance width
     * @param leftSideBearing Output left side bearing
     */
    @:native("stbtt_GetCodepointHMetrics")
    static function getCodepointHMetrics(
        info:ConstPointer<FontInfo>,
        codepoint:Int,
        advanceWidth:Star<Int>,
        leftSideBearing:Star<Int>
    ):Void;
    
    /**
     * Get kerning advance between two codepoints
     */
    @:native("stbtt_GetCodepointKernAdvance")
    static function getCodepointKernAdvance(
        info:ConstPointer<FontInfo>,
        ch1:Int,
        ch2:Int
    ):Int;
    
    /**
     * Get bounding box for a codepoint
     */
    @:native("stbtt_GetCodepointBox")
    static function getCodepointBox(
        info:ConstPointer<FontInfo>,
        codepoint:Int,
        x0:Star<Int>,
        y0:Star<Int>,
        x1:Star<Int>,
        y1:Star<Int>
    ):Int;
    
    /**
     * Find glyph index for a codepoint
     */
    @:native("stbtt_FindGlyphIndex")
    static function findGlyphIndex(info:ConstPointer<FontInfo>, unicode_codepoint:Int):Int;
    
    //////////////////////////////////////////////////////////////////////////////
    // BITMAP RENDERING
    //////////////////////////////////////////////////////////////////////////////
    
    /**
     * Render a codepoint to a bitmap (allocates memory)
     * 
     * @param info Font info
     * @param scale_x Horizontal scale
     * @param scale_y Vertical scale
     * @param codepoint Unicode codepoint
     * @param width Output bitmap width
     * @param height Output bitmap height
     * @param xoff Output X offset
     * @param yoff Output Y offset
     * @return Bitmap data (1 channel, 8bpp, must be freed with stbtt_FreeBitmap)
     */
    @:native("stbtt_GetCodepointBitmap")
    static function getCodepointBitmap(
        info:ConstPointer<FontInfo>,
        scale_x:Float,
        scale_y:Float,
        codepoint:Int,
        width:Star<Int>,
        height:Star<Int>,
        xoff:Star<Int>,
        yoff:Star<Int>
    ):Pointer<UInt8>;
    
    /**
     * Render a codepoint to pre-allocated bitmap
     */
    @:native("stbtt_MakeCodepointBitmap")
    static function makeCodepointBitmap(
        info:ConstPointer<FontInfo>,
        output:Pointer<UInt8>,
        out_w:Int,
        out_h:Int,
        out_stride:Int,
        scale_x:Float,
        scale_y:Float,
        codepoint:Int
    ):Void;
    
    /**
     * Get bitmap box for a codepoint
     */
    @:native("stbtt_GetCodepointBitmapBox")
    static function getCodepointBitmapBox(
        font:ConstPointer<FontInfo>,
        codepoint:Int,
        scale_x:Float,
        scale_y:Float,
        ix0:Star<Int>,
        iy0:Star<Int>,
        ix1:Star<Int>,
        iy1:Star<Int>
    ):Void;
    
    /**
     * Free bitmap allocated by stbtt_GetCodepointBitmap
     */
    @:native("stbtt_FreeBitmap")
    static function freeBitmap(bitmap:Pointer<UInt8>, userdata:RawPointer<cpp.Void>):Void;
    
    //////////////////////////////////////////////////////////////////////////////
    // SIGNED DISTANCE FIELD (SDF) RENDERING
    //////////////////////////////////////////////////////////////////////////////
    
    /**
     * Generate SDF bitmap for a glyph (allocates memory)
     * 
     * @param info Font info
     * @param scale Scale factor
     * @param glyph Glyph index
     * @param padding Padding around glyph
     * @param onedge_value Value for pixels on edge (typically 128)
     * @param pixel_dist_scale Distance scale
     * @param width Output bitmap width
     * @param height Output bitmap height
     * @param xoff Output X offset
     * @param yoff Output Y offset
     * @return SDF bitmap (must be freed with stbtt_FreeSDF)
     */
    @:native("stbtt_GetGlyphSDF")
    static function getGlyphSDF(
        info:ConstPointer<FontInfo>,
        scale:Float,
        glyph:Int,
        padding:Int,
        onedge_value:Int,
        pixel_dist_scale:Float,
        width:Star<Int>,
        height:Star<Int>,
        xoff:Star<Int>,
        yoff:Star<Int>
    ):Pointer<UInt8>;
    
    /**
     * Generate SDF bitmap for a codepoint
     */
    @:native("stbtt_GetCodepointSDF")
    static function getCodepointSDF(
        info:ConstPointer<FontInfo>,
        scale:Float,
        codepoint:Int,
        padding:Int,
        onedge_value:Int,
        pixel_dist_scale:Float,
        width:Star<Int>,
        height:Star<Int>,
        xoff:Star<Int>,
        yoff:Star<Int>
    ):Pointer<UInt8>;
    
    /**
     * Free SDF bitmap
     */
    @:native("stbtt_FreeSDF")
    static function freeSDF(bitmap:Pointer<UInt8>, userdata:RawPointer<cpp.Void>):Void;
}

//////////////////////////////////////////////////////////////////////////////
// DATA STRUCTURES
//////////////////////////////////////////////////////////////////////////////

/**
 * Baked character data (simple baking API)
 */
@:native("stbtt_bakedchar")
@:structAccess
extern class BakedChar {
    var x0:UInt16;       // Bitmap coordinates
    var y0:UInt16;
    var x1:UInt16;
    var y1:UInt16;
    var xoff:Float;      // Offsets for rendering
    var yoff:Float;
    var xadvance:Float;  // Horizontal advance
}

/**
 * Packed character data (advanced packing API)
 */
@:native("stbtt_packedchar")
@:structAccess
extern class PackedChar {
    var x0:UInt16;       // Bitmap coordinates
    var y0:UInt16;
    var x1:UInt16;
    var y1:UInt16;
    var xoff:Float;      // Offsets for rendering
    var yoff:Float;
    var xadvance:Float;  // Horizontal advance
    var xoff2:Float;     // Additional offsets
    var yoff2:Float;
}

/**
 * Aligned quad for rendering
 */
@:native("stbtt_aligned_quad")
@:structAccess
extern class AlignedQuad {
    var x0:Float;  // Top-left position
    var y0:Float;
    var s0:Float;  // Top-left UV
    var t0:Float;
    var x1:Float;  // Bottom-right position
    var y1:Float;
    var s1:Float;  // Bottom-right UV
    var t1:Float;
}

/**
 * Font packing context (opaque)
 */
@:native("stbtt_pack_context")
@:structAccess
extern class PackContext {
    // Opaque structure - don't access members directly
}

/**
 * Font range for packing multiple character sets
 */
@:native("stbtt_pack_range")
@:structAccess
extern class PackRange {
    var font_size:Float;
    var first_unicode_codepoint_in_range:Int;
    var array_of_unicode_codepoints:Pointer<Int>;
    var num_chars:Int;
    var chardata_for_range:Pointer<PackedChar>;
    var h_oversample:UInt8;
    var v_oversample:UInt8;
}

/**
 * Font info structure (opaque - use init/query functions)
 */
@:native("stbtt_fontinfo")
@:structAccess
extern class FontInfo {
    // Opaque structure - don't access members directly
}
