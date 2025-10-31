# Framebuffer Class

The `Framebuffer` class provides a clean, object-oriented interface for OpenGL framebuffer objects (FBOs), making render-to-texture operations simple and reusable.

## Features

- **Color texture attachment** - RGBA texture for rendering scene content
- **Depth attachment options** - Choose between depth texture (readable) or depth renderbuffer (depth testing only)
- **Easy binding/unbinding** - Simple `bind()` and `unbind()` methods
- **Texture sampling** - Direct methods to bind color and depth textures
- **Resizable** - Dynamic resizing with automatic resource recreation
- **Cleanup** - Proper OpenGL resource disposal

## Basic Usage

```haxe
// Create a framebuffer (width, height, useDepthTexture, useDepthRenderbuffer)
var fbo = new Framebuffer(1920, 1080, false, true);

// Render to the framebuffer
fbo.bind();
// ... render your scene ...
fbo.unbind();

// Use the framebuffer's color texture in a shader
fbo.bindColorTexture(0); // Bind to texture unit 0
// ... draw something using this texture ...

// Clean up when done
fbo.dispose();
```

## Post-Processing Example

```haxe
// Initialize post-processing in Renderer
renderer.initializePostProcessing();

// In your render loop:
if (renderer.usePostProcessing) {
    // Render scene to framebuffer
    renderer.bindFramebuffer();
    renderer.clearScreen();
    // ... render your scene ...
    
    // Render framebuffer to screen with post-processing
    renderer.unbindFramebuffer();
    renderer.clearScreen();
    renderer.renderToScreen(); // Applies post-processing shader
} else {
    // Render directly to screen
    renderer.clearScreen();
    // ... render your scene ...
}
```

## Advanced Usage

### Shadow Mapping
```haxe
// Create a depth-only framebuffer for shadow mapping
var shadowMap = new Framebuffer(2048, 2048, true, false);
shadowMap.depthFormat = GL.DEPTH_COMPONENT;

// Render from light's perspective
shadowMap.bind();
// ... render scene depth ...
shadowMap.unbind();

// Use depth texture for shadow calculations
shadowMap.bindDepthTexture(1); // Bind to texture unit 1
// ... render scene with shadows ...
```

### Multiple Render Targets
```haxe
// Create framebuffer for deferred rendering
var gBuffer = new Framebuffer(1920, 1080, true, true);
gBuffer.colorFormat = GL.RGBA16F; // High precision color
gBuffer.minFilter = GL.NEAREST;   // No filtering for G-buffer
gBuffer.magFilter = GL.NEAREST;

// Note: Multiple color attachments require extending the Framebuffer class
```

### Dynamic Resolution
```haxe
// Resize framebuffer when window changes
function onWindowResize(newWidth:Int, newHeight:Int) {
    renderer.framebuffer.resize(newWidth, newHeight);
}
```

## Configuration Options

### Constructor Parameters
- `width:Int` - Framebuffer width in pixels
- `height:Int` - Framebuffer height in pixels  
- `useDepthTexture:Bool` - Create readable depth texture (for shadow mapping, SSAO, etc.)
- `useDepthRenderbuffer:Bool` - Create depth renderbuffer for depth testing only

### Texture Parameters
```haxe
var fbo = new Framebuffer(800, 600);

// Set before initialization (in constructor)
fbo.minFilter = GL.LINEAR;       // Minification filter
fbo.magFilter = GL.LINEAR;       // Magnification filter
fbo.wrapS = GL.CLAMP_TO_EDGE;    // S-axis wrapping
fbo.wrapT = GL.CLAMP_TO_EDGE;    // T-axis wrapping
fbo.colorFormat = GL.RGBA;       // Color format
```

## Methods

### Rendering
- `bind()` - Bind framebuffer for rendering
- `unbind()` - Unbind framebuffer (render to screen)
- `clear(r, g, b, a, clearDepth)` - Clear framebuffer with color

### Texture Access
- `bindColorTexture(textureUnit)` - Bind color texture for sampling
- `bindDepthTexture(textureUnit)` - Bind depth texture for sampling (if available)

### Management
- `resize(newWidth, newHeight)` - Resize framebuffer
- `dispose()` - Clean up OpenGL resources
- `isComplete()` - Check if framebuffer is valid
- `getStatusString()` - Get framebuffer status for debugging

## Architecture Benefits

### Before (in Renderer class)
```haxe
// Scattered framebuffer management
public var screenFBO:Int = 0;
public var screenTexture:Int = 0;
private function createFramebuffer(width, height) { ... }
public function bindFramebuffer() { ... }
public function unbindFramebuffer() { ... }
```

### After (Framebuffer class)
```haxe
// Clean, reusable object
public var framebuffer:Framebuffer = null;
framebuffer = new Framebuffer(width, height);
framebuffer.bind();
framebuffer.unbind();
```

### Benefits
1. **Reusability** - Create multiple framebuffers easily
2. **Encapsulation** - All FBO logic in one place
3. **Flexibility** - Different configurations per framebuffer
4. **Maintainability** - Easier to debug and extend
5. **Scalability** - Simple to add features like MRT (Multiple Render Targets)

## Error Handling

The `Framebuffer` class includes automatic validation:

```haxe
if (!fbo.isComplete()) {
    trace("Framebuffer error: " + fbo.getStatusString());
}
```

Common status messages:
- `FRAMEBUFFER_COMPLETE` - Ready to use
- `FRAMEBUFFER_INCOMPLETE_ATTACHMENT` - Invalid attachment
- `FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT` - No attachments
- `FRAMEBUFFER_UNSUPPORTED` - Format not supported

## Future Extensions

The `Framebuffer` class can be easily extended for:
- Multiple color attachments (MRT)
- Multisampling (MSAA)
- Cube map rendering
- Layered rendering (geometry shader)
- Stencil buffer support
