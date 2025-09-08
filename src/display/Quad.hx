package display;

import GL;
import SDL;
import DisplayObject;
import ProgramInfo;
import data.TextureData;
import math.Matrix;

class Quad extends DisplayObject {
    // Quad-specific properties
    public var width:Float = 1.0;
    public var height:Float = 1.0;
    public var textureId:GlUInt = 0;
    public var hasTexture:Bool = false;
    
    // UV coordinates for texture mapping (flipped V for 2D)
    public var uvs:Array<Float> = [
        0.0, 0.0,  // Top-left
        1.0, 0.0,  // Top-right
        1.0, 1.0,  // Bottom-right
        0.0, 1.0   // Bottom-left
    ];
    
    public function new(programInfo:ProgramInfo, ?width:Float = 0.8, ?height:Float = 0.8) {
        this.width = width;
        this.height = height;
        
        // Create quad vertices (interleaved: pos.x, pos.y, pos.z, u, v)
        var halfWidth = width / 2;
        var halfHeight = height / 2;
        
        var quadVertices = new Vertices([
            // Position (x, y, z) + UV coordinates (u, v)
            // Top-left vertex - flipped V for 2D (0,0 at top-left)
            -halfWidth,  halfHeight, 0.0,  0.0, 0.0,
            // Top-right vertex - flipped V for 2D
             halfWidth,  halfHeight, 0.0,  1.0, 0.0,
            // Bottom-right vertex - flipped V for 2D
             halfWidth, -halfHeight, 0.0,  1.0, 1.0,
            // Bottom-left vertex - flipped V for 2D
            -halfWidth, -halfHeight, 0.0,  0.0, 1.0
        ]);
        
        trace("Quad created: " + width + "x" + height + " with UV coordinates (0,0) to (1,1)");
        
        // Indices for two triangles to form a quad
        var quadIndices = new Indices([
            0, 1, 2,  // First triangle (top-left, top-right, bottom-right)
            2, 3, 0   // Second triangle (bottom-right, bottom-left, top-left)
        ]);
        
        super(programInfo, quadVertices, quadIndices);
        
        // Set up quad-specific properties
        mode = GL.TRIANGLES;
        __verticesToRender = 4;
        __indicesToRender = 6;
        
        // Create a simple white texture by default
        createDefaultTexture();
    }
    
    // Create a simple white 1x1 texture as default
    private function createDefaultTexture():Void {
        textureId = untyped __cpp__("
            [](){ 
                unsigned int texId;
                glGenTextures(1, &texId);
                return texId;
            }()
        ");
        
        GL.bindTexture(GL.TEXTURE_2D, textureId);
        
        // Create a 1x1 white pixel
        var whitePixel = haxe.io.Bytes.alloc(4);
        whitePixel.set(0, 255); // R
        whitePixel.set(1, 255); // G
        whitePixel.set(2, 255); // B
        whitePixel.set(3, 255); // A
        
        untyped __cpp__("glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, {0}->b->GetBase())", whitePixel);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        
        GL.bindTexture(GL.TEXTURE_2D, 0);
        
        hasTexture = true;
        trace("Default white texture created with ID: " + textureId);
    }
    
    // Create a checkerboard pattern texture for testing
    public function createCheckerboardTexture(size:Int = 64):Void {
        if (textureId != 0) {
            // Delete old texture
            untyped __cpp__("
                {
                    unsigned int texId = {0};
                    glDeleteTextures(1, &texId);
                }
            ", textureId);
        }
        
        textureId = untyped __cpp__("
            [](){ 
                unsigned int texId;
                glGenTextures(1, &texId);
                return texId;
            }()
        ");
        
        GL.bindTexture(GL.TEXTURE_2D, textureId);
        
        // Create checkerboard pattern
        var textureData = haxe.io.Bytes.alloc(size * size * 4);
        var checkSize = 8; // Size of each checker square
        
        for (y in 0...size) {
            for (x in 0...size) {
                var index = (y * size + x) * 4;
                
                // Determine if we're in a white or black square
                var checkerX = Std.int(x / checkSize);
                var checkerY = Std.int(y / checkSize);
                var isWhite = (checkerX + checkerY) % 2 == 0;
                
                if (isWhite) {
                    textureData.set(index + 0, 255); // R
                    textureData.set(index + 1, 255); // G
                    textureData.set(index + 2, 255); // B
                } else {
                    textureData.set(index + 0, 0);   // R
                    textureData.set(index + 1, 0);   // G
                    textureData.set(index + 2, 0);   // B
                }
                textureData.set(index + 3, 255); // A
            }
        }
        
        untyped __cpp__("glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, {0}, {1}, 0, GL_RGBA, GL_UNSIGNED_BYTE, {2}->b->GetBase())", size, size, textureData);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.LINEAR);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT);
        
        GL.bindTexture(GL.TEXTURE_2D, 0);
        
        hasTexture = true;
        trace("Checkerboard texture created with ID: " + textureId + " (size: " + size + "x" + size + ")");
    }

    // Create OpenGL texture from TextureData
    public function createTextureFromData(textureData:data.TextureData):Void {
        if (textureId != 0) {
            // Delete old texture
            untyped __cpp__("
                {
                    unsigned int texId = {0};
                    glDeleteTextures(1, &texId);
                }
            ", textureId);
        }
        
        // Convert grayscale to RGB for better compatibility
        var processedTexture = textureData.toRGB();
        
        // TEMP: Don't auto-resize for testing - keep manual size
        // setSize(processedTexture.width, processedTexture.height);
        trace("Texture size: " + processedTexture.width + "x" + processedTexture.height + ", Quad size: " + width + "x" + height);
        
        textureId = untyped __cpp__("
            [](){ 
                unsigned int texId;
                glGenTextures(1, &texId);
                return texId;
            }()
        ");
        
        GL.bindTexture(GL.TEXTURE_2D, textureId);
        
        // Determine OpenGL format based on bytes per pixel
        var glFormat:Int;
        var glInternalFormat:Int;
        
        switch (processedTexture.bytesPerPixel) {
            case 1: // Grayscale - use GL_RED and handle in shader
                glFormat = 0x1903; // GL_RED
                glInternalFormat = 0x8229; // GL_R8
            case 3: // RGB
                glFormat = 0x1907; // GL_RGB
                glInternalFormat = 0x1907; // GL_RGB
            case 4: // RGBA
                glFormat = GL.RGBA;
                glInternalFormat = GL.RGBA;
            default:
                throw "Unsupported texture format: " + processedTexture.bytesPerPixel + " bytes per pixel";
        }
        
        // Upload texture data to GPU
        // Convert UInt8Array to Bytes for OpenGL upload
        var bytes = haxe.io.Bytes.alloc(processedTexture.width * processedTexture.height * processedTexture.bytesPerPixel);
        for (i in 0...bytes.length) {
            bytes.set(i, processedTexture.bytes[i]);
        }
        
        untyped __cpp__("glTexImage2D(GL_TEXTURE_2D, 0, {0}, {1}, {2}, 0, {3}, GL_UNSIGNED_BYTE, {4}->b->GetBase())", 
            glInternalFormat, processedTexture.width, processedTexture.height, glFormat, bytes);
        
        trace("Texture uploaded: " + processedTexture.width + "x" + processedTexture.height + " pixels, mapped to " + this.width + "x" + this.height + " quad");
        
        // Set texture parameters
        if (processedTexture.powerOfTwo) {
            // Power-of-two textures can use mipmaps and repeat wrapping
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST_MIPMAP_NEAREST);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.REPEAT);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.REPEAT);
            GL.generateMipmap(GL.TEXTURE_2D);
        } else {
            // Non-power-of-two textures should use clamp and no mipmaps
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
            GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        }
        
        GL.bindTexture(GL.TEXTURE_2D, 0);
        
        hasTexture = true;
    }
    
    // Clean up texture resources
    public function dispose():Void {
        if (textureId != 0) {
            untyped __cpp__("
                {
                    unsigned int texId = {0};
                    glDeleteTextures(1, &texId);
                }
            ", textureId);
            textureId = 0;
            hasTexture = false;
        }
    }
    
    // Set the quad dimensions
    public function setSize(newWidth:Float, newHeight:Float):Void {
        width = newWidth;
        height = newHeight;
        
        // Update vertex positions
        updateVertexPositions();
    }
    
    // Update the vertex buffer with new positions
    private function updateVertexPositions():Void {
        var halfWidth = width / 2;
        var halfHeight = height / 2;
        
        // Update positions (keeping UVs the same)
        // Each vertex has 5 floats: x, y, z, u, v
        // Top-left
        vertices.data[0] = -halfWidth; vertices.data[1] = halfHeight; vertices.data[2] = 0.0;
        // Top-right
        vertices.data[5] = halfWidth; vertices.data[6] = halfHeight; vertices.data[7] = 0.0;
        // Bottom-right
        vertices.data[10] = halfWidth; vertices.data[11] = -halfHeight; vertices.data[12] = 0.0;
        // Bottom-left
        vertices.data[15] = -halfWidth; vertices.data[16] = -halfHeight; vertices.data[17] = 0.0;
        
        // Mark for buffer update on next render
        if (initialized) {
            needsBufferUpdate = true;
        }
    }
    
    // Override render to bind texture
    public override function render(cameraMatrix:Matrix, renderer:Renderer):Void {
        if (!visible || !initialized) return;
        
        // Update transformation matrix based on current properties
        updateTransform();
        
        // Create final matrix by combining camera matrix with object matrix
        var finalMatrix = Matrix.copy(cameraMatrix);
        finalMatrix.append(matrix);
        
        // Use the program
        GL.useProgram(programInfo.program);
        
        // Bind texture
        if (hasTexture && textureId != 0) {
            GL.activeTexture(GL.TEXTURE0);
            GL.bindTexture(GL.TEXTURE_2D, textureId);
            
            // Set the texture uniform
            var textureLoc = GL.getUniformLocation(programInfo.program, "uTexture");
            if (textureLoc >= 0) {
                GL.uniform1i(textureLoc, 0); // Texture unit 0
            } else {
                trace("ERROR: uTexture uniform not found in shader!");
            }
        } else {
            trace("Quad render - no texture: hasTexture=" + hasTexture + ", textureId=" + textureId);
        }
    }
}
