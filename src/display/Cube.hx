package display;

import GL;
import DisplayObject;
import ProgramInfo;
import Renderer;
import math.Matrix;

class Cube extends DisplayObject {
    
    public var autoRotate:Bool = true;
    public var rotationSpeed:Float = 1.0;
    
    public function new(programInfo:ProgramInfo, ?size:Float = 1.0) {
        var halfSize = size / 2.0;
        
        // Create cube vertices (position + color)
        // Each vertex has: x, y, z, r, g, b
        var cubeVertices = new Vertices([
            // Front face (red-ish)
            -halfSize, -halfSize,  halfSize,  0.8, 0.2, 0.2,  // Bottom-left
             halfSize, -halfSize,  halfSize,  1.0, 0.4, 0.4,  // Bottom-right
             halfSize,  halfSize,  halfSize,  1.0, 0.6, 0.6,  // Top-right
            -halfSize,  halfSize,  halfSize,  0.8, 0.4, 0.4,  // Top-left
            
            // Back face (green-ish)
            -halfSize, -halfSize, -halfSize,  0.2, 0.8, 0.2,  // Bottom-left
             halfSize, -halfSize, -halfSize,  0.4, 1.0, 0.4,  // Bottom-right
             halfSize,  halfSize, -halfSize,  0.6, 1.0, 0.6,  // Top-right
            -halfSize,  halfSize, -halfSize,  0.4, 0.8, 0.4,  // Top-left
            
            // Left face (blue-ish)
            -halfSize, -halfSize, -halfSize,  0.2, 0.2, 0.8,  // Bottom-back
            -halfSize, -halfSize,  halfSize,  0.4, 0.4, 1.0,  // Bottom-front
            -halfSize,  halfSize,  halfSize,  0.6, 0.6, 1.0,  // Top-front
            -halfSize,  halfSize, -halfSize,  0.4, 0.4, 0.8,  // Top-back
            
            // Right face (yellow-ish)
             halfSize, -halfSize, -halfSize,  0.8, 0.8, 0.2,  // Bottom-back
             halfSize, -halfSize,  halfSize,  1.0, 1.0, 0.4,  // Bottom-front
             halfSize,  halfSize,  halfSize,  1.0, 1.0, 0.6,  // Top-front
             halfSize,  halfSize, -halfSize,  0.8, 0.8, 0.4,  // Top-back
            
            // Top face (cyan-ish)
            -halfSize,  halfSize, -halfSize,  0.2, 0.8, 0.8,  // Back-left
             halfSize,  halfSize, -halfSize,  0.4, 1.0, 1.0,  // Back-right
             halfSize,  halfSize,  halfSize,  0.6, 1.0, 1.0,  // Front-right
            -halfSize,  halfSize,  halfSize,  0.4, 0.8, 0.8,  // Front-left
            
            // Bottom face (magenta-ish)
            -halfSize, -halfSize, -halfSize,  0.8, 0.2, 0.8,  // Back-left
             halfSize, -halfSize, -halfSize,  1.0, 0.4, 1.0,  // Back-right
             halfSize, -halfSize,  halfSize,  1.0, 0.6, 1.0,  // Front-right
            -halfSize, -halfSize,  halfSize,  0.8, 0.4, 0.8,  // Front-left
        ]);
        
        // Create cube indices with proper counter-clockwise winding
        var cubeIndices = new Indices([
            // Front face (CCW when viewed from front)
            0, 1, 2,  2, 3, 0,
            // Back face (CCW when viewed from back - appears CW from front)
            4, 7, 6,  6, 5, 4,
            // Left face (CCW when viewed from left)
            8, 9, 10,  10, 11, 8,
            // Right face (CCW when viewed from right - appears CW from front)
            12, 15, 14,  14, 13, 12,
            // Top face (CCW when viewed from top)
            16, 17, 18,  18, 19, 16,
            // Bottom face (CCW when viewed from bottom - appears CW from top)
            20, 23, 22,  22, 21, 20
        ]);
        
        super(programInfo, cubeVertices, cubeIndices);
        
        // Set up cube-specific properties
        mode = GL.TRIANGLES;
        __verticesToRender = 24;
        __indicesToRender = 36; // All 6 faces = 36 indices
        
        // Enable 3D rendering features
        depthTest = true;
        depthWrite = true;
        cullFace = false;  // Temporarily disable face culling to debug geometry
        
        trace("Cube created with " + __verticesToRender + " vertices and " + __indicesToRender + " indices");
        trace("Cube size: " + size + ", halfSize: " + halfSize);
        trace("Sample vertices - Front face bottom-left: (" + (-halfSize) + ", " + (-halfSize) + ", " + halfSize + ")");
        trace("Indices length: " + cubeIndices.data.length + ", should be 36 for full cube");
        trace("First few indices: " + cubeIndices.data[0] + ", " + cubeIndices.data[1] + ", " + cubeIndices.data[2]);
        
        // Debug: Print the first few vertices to verify they're correct
        trace("First 6 vertex values (2 vertices): " + cubeVertices.data[0] + ", " + cubeVertices.data[1] + ", " + cubeVertices.data[2] + 
              " | " + cubeVertices.data[6] + ", " + cubeVertices.data[7] + ", " + cubeVertices.data[8]);
        trace("Vertex 0 (front bottom-left): pos(" + cubeVertices.data[0] + ", " + cubeVertices.data[1] + ", " + cubeVertices.data[2] + 
              ") color(" + cubeVertices.data[3] + ", " + cubeVertices.data[4] + ", " + cubeVertices.data[5] + ")");
        trace("Vertex 12 (right face): pos(" + cubeVertices.data[72] + ", " + cubeVertices.data[73] + ", " + cubeVertices.data[74] + 
              ") color(" + cubeVertices.data[75] + ", " + cubeVertices.data[76] + ", " + cubeVertices.data[77] + ")");
    }
    
    // Update animation
    public function update(deltaTime:Float):Void {
        if (autoRotate) {
            rotationX += rotationSpeed * deltaTime;
            rotationY += rotationSpeed * deltaTime * 0.7;
            rotationZ += rotationSpeed * deltaTime * 0.3;
        }
    }
    
    // Custom render method for cube
    public override function render(cameraMatrix:Matrix):Void {
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
    }
}
