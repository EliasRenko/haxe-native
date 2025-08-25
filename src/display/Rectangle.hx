package display;

import GL;
import SDL;
import DisplayObject;
import ProgramInfo;

class Rectangle extends DisplayObject {
    // Rectangle-specific properties
    public var width:Float = 1.0;
    public var height:Float = 1.0;
    
    // Color properties for each corner
    public var topLeftColor:Array<Float> = [1.0, 0.0, 0.0];      // Red
    public var topRightColor:Array<Float> = [0.0, 1.0, 0.0];     // Green
    public var bottomLeftColor:Array<Float> = [0.0, 0.0, 1.0];   // Blue
    public var bottomRightColor:Array<Float> = [1.0, 1.0, 0.0];  // Yellow
    
    public function new(programInfo:ProgramInfo, ?width:Float = 0.8, ?height:Float = 0.6) {
        this.width = width;
        this.height = height;
        
        // Create rectangle vertices (interleaved: pos.x, pos.y, pos.z, color.r, color.g, color.b)
        var halfWidth = width / 2;
        var halfHeight = height / 2;
        
        var rectangleVertices = new Vertices([
            // Top-left vertex
            -halfWidth,  halfHeight, 0.0,  1.0, 0.0, 0.0,  // Red
            // Top-right vertex
             halfWidth,  halfHeight, 0.0,  0.0, 1.0, 0.0,  // Green
            // Bottom-right vertex
             halfWidth, -halfHeight, 0.0,  1.0, 1.0, 0.0,  // Yellow
            // Bottom-left vertex
            -halfWidth, -halfHeight, 0.0,  0.0, 0.0, 1.0   // Blue
        ]);
        
        // Indices for two triangles to form a rectangle
        var rectangleIndices = new Indices([
            0, 1, 2,  // First triangle (top-left, top-right, bottom-right)
            2, 3, 0   // Second triangle (bottom-right, bottom-left, top-left)
        ]);
        
        super(programInfo, rectangleVertices, rectangleIndices);
        
        // Set up rectangle-specific properties
        mode = GL.TRIANGLES;
        __verticesToRender = 4;
        __indicesToRender = 6;
    }
    
    // Set the rectangle dimensions
    public function setSize(newWidth:Float, newHeight:Float):Void {
        width = newWidth;
        height = newHeight;
        
        // Update vertex positions
        updateVertexPositions();
    }
    
    // Set individual corner colors
    public function setCornerColors(topLeft:Array<Float>, topRight:Array<Float>, bottomRight:Array<Float>, bottomLeft:Array<Float>):Void {
        topLeftColor = topLeft.copy();
        topRightColor = topRight.copy();
        bottomRightColor = bottomRight.copy();
        bottomLeftColor = bottomLeft.copy();
        
        // Update the vertex data
        updateVertexColors();
    }
    
    // Update the vertex buffer with new positions
    private function updateVertexPositions():Void {
        var halfWidth = width / 2;
        var halfHeight = height / 2;
        
        // Update positions (keeping colors the same)
        // Top-left
        vertices.data[0] = -halfWidth; vertices.data[1] = halfHeight; vertices.data[2] = 0.0;
        // Top-right
        vertices.data[6] = halfWidth; vertices.data[7] = halfHeight; vertices.data[8] = 0.0;
        // Bottom-right
        vertices.data[12] = halfWidth; vertices.data[13] = -halfHeight; vertices.data[14] = 0.0;
        // Bottom-left
        vertices.data[18] = -halfWidth; vertices.data[19] = -halfHeight; vertices.data[20] = 0.0;
        
        // Update the GPU buffer
        if (initialized) {
            updateBuffers();
        }
    }
    
    // Update the vertex buffer with new colors
    private function updateVertexColors():Void {
        // Update the vertices array with new colors (keeping positions the same)
        // Top-left color
        vertices.data[3] = topLeftColor[0]; vertices.data[4] = topLeftColor[1]; vertices.data[5] = topLeftColor[2];
        // Top-right color
        vertices.data[9] = topRightColor[0]; vertices.data[10] = topRightColor[1]; vertices.data[11] = topRightColor[2];
        // Bottom-right color
        vertices.data[15] = bottomRightColor[0]; vertices.data[16] = bottomRightColor[1]; vertices.data[17] = bottomRightColor[2];
        // Bottom-left color
        vertices.data[21] = bottomLeftColor[0]; vertices.data[22] = bottomLeftColor[1]; vertices.data[23] = bottomLeftColor[2];
        
        // Update the GPU buffer
        if (initialized) {
            updateBuffers();
        }
    }
    
    // Get shader source for rectangle vertex shader (same as triangle)
    public static function getVertexShader():String {
        return '
        #version 330 core
        layout (location = 0) in vec3 aPos;
        layout (location = 1) in vec3 aColor;
        
        out vec3 vertexColor;
        
        uniform mat4 uMatrix;
        
        void main() {
            // Apply matrix transformation
            gl_Position = uMatrix * vec4(aPos, 1.0);
            vertexColor = aColor;
        }
        ';
    }
    
    // Get shader source for rectangle fragment shader (same as triangle)
    public static function getFragmentShader():String {
        return '
        #version 330 core
        in vec3 vertexColor;
        out vec4 FragColor;
        
        void main() {
            FragColor = vec4(vertexColor, 1.0);
        }
        ';
    }
}
