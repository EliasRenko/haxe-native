package display;

import GL;
import SDL;
import DisplayObject;
import Renderer;
import math.Matrix;

class Triangle extends DisplayObject {
    // Triangle-specific properties
    public var rotationSpeed:Float = 0.1;
    public var autoRotate:Bool = true;
    
    // Color properties for each vertex
    public var topColor:Array<Float> = [1.0, 0.0, 0.0];      // Red
    public var leftColor:Array<Float> = [0.0, 1.0, 0.0];     // Green
    public var rightColor:Array<Float> = [0.0, 0.0, 1.0];    // Blue
    
    public function new(programInfo:ProgramInfo) {
        // Create triangle vertices (interleaved: pos.x, pos.y, pos.z, color.r, color.g, color.b)
        var triangleVertices = new Vertices([
            // Use simple coordinates that work with identity matrix
             0.0,  0.5, 0.0,  1.0, 0.0, 0.0,  // Top vertex - Red
            -0.5, -0.5, 0.0,  0.0, 1.0, 0.0,  // Bottom left - Green
             0.5, -0.5, 0.0,  0.0, 0.0, 1.0   // Bottom right - Blue
        ]);
        
        // No indices needed for simple triangle
        super(programInfo, triangleVertices, null);
        
        // Set up triangle-specific properties
        mode = GL.TRIANGLES;
        __verticesToRender = 3;
        
        trace("TRIANGLE: Created with coordinates in range -0.5 to 0.5");
    }
    
    // Update the triangle (called each frame)
    public function update(deltaTime:Float):Void {
        if (autoRotate) {
            rotationZ += rotationSpeed * deltaTime;
        }
    }
    
    // Set individual vertex colors
    public function setVertexColors(top:Array<Float>, left:Array<Float>, right:Array<Float>):Void {
        topColor = top.copy();
        leftColor = left.copy();
        rightColor = right.copy();
        
        // Update the vertex data
        updateVertexColors();
    }
    
    // Update the vertex buffer with new colors
    private function updateVertexColors():Void {
        // Update the vertices array with new colors (keeping positions the same)
        vertices.data[3] = topColor[0];   vertices.data[4] = topColor[1];   vertices.data[5] = topColor[2];   // Top vertex color
        vertices.data[9] = leftColor[0];  vertices.data[10] = leftColor[1]; vertices.data[11] = leftColor[2]; // Left vertex color
        vertices.data[15] = rightColor[0]; vertices.data[16] = rightColor[1]; vertices.data[17] = rightColor[2]; // Right vertex color
        
        // Mark for buffer update on next render
        if (initialized) {
            needsBufferUpdate = true;
        }
    }
    
    // Set the rotation speed
    public function setRotationSpeed(speed:Float):Void {
        rotationSpeed = speed;
    }
    
    // Enable/disable auto-rotation
    public function setAutoRotate(enabled:Bool):Void {
        autoRotate = enabled;
    }
    
    // Custom render method for triangle
    public override function render(cameraMatrix:Matrix, renderer:Renderer):Void {
        if (!visible || !initialized) {
            return;
        }
        
        // Update transformation matrix based on current properties
        updateTransform();
        
        // Create final matrix by combining object matrix with camera matrix
        var finalMatrix = Matrix.copy(matrix);
        finalMatrix.append(cameraMatrix);
        
        // Set uniforms and delegate rendering to renderer
        uniforms.set("uMatrix", finalMatrix.data);
        renderer.renderObject(this);
    }
}
