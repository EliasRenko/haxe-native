package loaders;

import haxe.io.UInt8Array;
import haxe.io.BytesInput;
import haxe.io.Bytes;
import data.TextureData;

class TGALoader {
    
    // TGA Header structure (18 bytes)
    private static inline var TGA_HEADER_SIZE = 18;
    
    // Image type constants
    private static inline var TGA_NO_IMAGE = 0;
    private static inline var TGA_UNCOMPRESSED_COLOR_MAPPED = 1;
    private static inline var TGA_UNCOMPRESSED_RGB = 2;
    private static inline var TGA_UNCOMPRESSED_GRAYSCALE = 3;
    private static inline var TGA_RLE_COLOR_MAPPED = 9;
    private static inline var TGA_RLE_RGB = 10;
    private static inline var TGA_RLE_GRAYSCALE = 11;

    public static function loadFromBytes(bytes:Bytes):TextureData {
        if (bytes.length < TGA_HEADER_SIZE) {
            throw "Invalid TGA file: too small";
        }

        var input = new BytesInput(bytes);
        
        // Read TGA header
        var idLength = input.readByte();           // 0: ID field length
        var colorMapType = input.readByte();       // 1: Color map type
        var imageType = input.readByte();          // 2: Image type
        
        // Color map specification (5 bytes)
        var colorMapStart = input.readUInt16();    // 3-4: Color map start
        var colorMapLength = input.readUInt16();   // 5-6: Color map length  
        var colorMapDepth = input.readByte();      // 7: Color map depth
        
        // Image specification (10 bytes)
        var xOrigin = input.readUInt16();          // 8-9: X origin
        var yOrigin = input.readUInt16();          // 10-11: Y origin
        var width = input.readUInt16();            // 12-13: Width
        var height = input.readUInt16();           // 14-15: Height
        var pixelDepth = input.readByte();         // 16: Pixel depth
        var imageDescriptor = input.readByte();    // 17: Image descriptor

        // Skip ID field if present
        if (idLength > 0) {
            input.read(idLength);
        }

        // We'll support uncompressed RGB/RGBA for now
        if (imageType != TGA_UNCOMPRESSED_RGB && imageType != TGA_UNCOMPRESSED_GRAYSCALE) {
            throw "Unsupported TGA format: only uncompressed RGB/RGBA supported (type: " + imageType + ")";
        }

        // Determine bytes per pixel
        var bytesPerPixel = Math.floor(pixelDepth / 8);
        if (bytesPerPixel < 1 || bytesPerPixel > 4) {
            throw "Unsupported pixel depth: " + pixelDepth + " bits";
        }

        // Calculate expected data size
        var expectedDataSize = width * height * bytesPerPixel;
        var remainingBytes = bytes.length - input.position;
        
        if (remainingBytes < expectedDataSize) {
            throw "Invalid TGA file: insufficient image data";
        }

        // Read pixel data
        var pixelData = new UInt8Array(expectedDataSize);
        var rawData = input.read(expectedDataSize);
        
        // TGA stores data as BGR(A), we need RGB(A)
        for (i in 0...Math.floor(expectedDataSize / bytesPerPixel)) {
            var srcOffset = i * bytesPerPixel;
            var dstOffset = i * bytesPerPixel;
            
            if (bytesPerPixel >= 3) {
                // Swap B and R channels (BGR -> RGB)
                pixelData[dstOffset + 0] = rawData.get(srcOffset + 2); // R
                pixelData[dstOffset + 1] = rawData.get(srcOffset + 1); // G
                pixelData[dstOffset + 2] = rawData.get(srcOffset + 0); // B
                
                if (bytesPerPixel == 4) {
                    pixelData[dstOffset + 3] = rawData.get(srcOffset + 3); // A
                }
            } else {
                // Grayscale - direct copy
                pixelData[dstOffset] = rawData.get(srcOffset);
            }
        }

        // Check if image has alpha channel
        var hasAlpha = (bytesPerPixel == 4) || (bytesPerPixel == 2);

        trace("Loaded TGA: " + width + "x" + height + ", " + pixelDepth + " bits, " + bytesPerPixel + " BPP");

        return new TextureData(pixelData, bytesPerPixel, width, height, hasAlpha);
    }
}
