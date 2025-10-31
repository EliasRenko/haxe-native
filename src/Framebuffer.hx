package;

import GL;

/**
 * Framebuffer Object (FBO) for render-to-texture operations
 * Used for post-processing effects, shadow mapping, reflections, etc.
 */
class Framebuffer {
    
    // OpenGL handles
    public var fbo:UInt = 0;
    public var colorTexture:UInt = 0;
    public var depthTexture:UInt = 0;
    public var depthRenderbuffer:UInt = 0;
    
    // Dimensions
    public var width:Int;
    public var height:Int;
    
    // Configuration
    public var hasDepthTexture:Bool;
    public var hasDepthRenderbuffer:Bool;
    public var colorFormat:Int = GL.RGBA;
    public var depthFormat:Int = GL.DEPTH_COMPONENT;
    
    // Texture filtering
    public var minFilter:Int = GL.LINEAR;
    public var magFilter:Int = GL.LINEAR;
    public var wrapS:Int = GL.CLAMP_TO_EDGE;
    public var wrapT:Int = GL.CLAMP_TO_EDGE;
    
    /**
     * Create a new framebuffer
     * @param width Framebuffer width
     * @param height Framebuffer height
     * @param useDepthTexture Use depth texture (for depth-based effects) instead of renderbuffer
     * @param useDepthRenderbuffer Use depth renderbuffer (for depth testing only)
     */
    public function new(width:Int, height:Int, useDepthTexture:Bool = false, useDepthRenderbuffer:Bool = true) {
        this.width = width;
        this.height = height;
        this.hasDepthTexture = useDepthTexture;
        this.hasDepthRenderbuffer = useDepthRenderbuffer && !useDepthTexture;
        
        initialize();
    }
    
    /**
     * Initialize the framebuffer and attachments
     */
    private function initialize():Void {
        // Create framebuffer
        fbo = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
        
        // Create color texture
        createColorTexture();
        
        // Create depth attachment if needed
        if (hasDepthTexture) {
            createDepthTexture();
        } else if (hasDepthRenderbuffer) {
            createDepthRenderbuffer();
        }
        
        // Check framebuffer completeness
        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        if (status != GL.FRAMEBUFFER_COMPLETE) {
            trace("ERROR: Framebuffer is not complete! Status: " + status);
            trace("  FBO: " + fbo);
            trace("  Color texture: " + colorTexture);
            trace("  Depth texture: " + depthTexture);
            trace("  Depth renderbuffer: " + depthRenderbuffer);
        } else {
            trace("Framebuffer created successfully: " + width + "x" + height);
        }
        
        // Unbind framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
    }
    
    /**
     * Create the color texture attachment
     */
    private function createColorTexture():Void {
        colorTexture = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, colorTexture);
        
        // Allocate texture storage
        GL.texImage2D(GL.TEXTURE_2D, 0, colorFormat, width, height, 0, GL.RGBA, GL.UNSIGNED_BYTE, null);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, minFilter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, magFilter);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, wrapS);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, wrapT);
        
        // Attach to framebuffer
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, colorTexture, 0);
        
        GL.bindTexture(GL.TEXTURE_2D, 0);
    }
    
    /**
     * Create a depth texture attachment (for shadow mapping, depth-based effects)
     */
    private function createDepthTexture():Void {
        depthTexture = GL.createTexture();
        GL.bindTexture(GL.TEXTURE_2D, depthTexture);
        
        // Allocate depth texture storage
        GL.texImage2D(GL.TEXTURE_2D, 0, GL.DEPTH_COMPONENT, width, height, 0, GL.DEPTH_COMPONENT, GL.FLOAT, null);
        
        // Set texture parameters
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MIN_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_MAG_FILTER, GL.NEAREST);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_S, GL.CLAMP_TO_EDGE);
        GL.texParameteri(GL.TEXTURE_2D, GL.TEXTURE_WRAP_T, GL.CLAMP_TO_EDGE);
        
        // Attach to framebuffer
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.TEXTURE_2D, depthTexture, 0);
        
        GL.bindTexture(GL.TEXTURE_2D, 0);
    }
    
    /**
     * Create a depth renderbuffer attachment (for depth testing only, not readable)
     */
    private function createDepthRenderbuffer():Void {
        var rboArray = [0];
        GL.genRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", rboArray));
        depthRenderbuffer = rboArray[0];
        
        GL.bindRenderbuffer(GL.RENDERBUFFER, depthRenderbuffer);
        GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT, width, height);
        GL.framebufferRenderbuffer(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.RENDERBUFFER, depthRenderbuffer);
        
        GL.bindRenderbuffer(GL.RENDERBUFFER, 0);
    }
    
    /**
     * Bind this framebuffer for rendering
     */
    public function bind():Void {
        GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
        GL.viewport(0, 0, width, height);
    }
    
    /**
     * Unbind this framebuffer (render to screen)
     */
    public function unbind():Void {
        GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
    }
    
    /**
     * Bind the color texture for sampling in shaders
     * @param textureUnit Texture unit to bind to (0-31)
     */
    public function bindColorTexture(textureUnit:Int = 0):Void {
        GL.activeTexture(GL.TEXTURE0 + textureUnit);
        GL.bindTexture(GL.TEXTURE_2D, colorTexture);
    }
    
    /**
     * Bind the depth texture for sampling in shaders
     * @param textureUnit Texture unit to bind to (0-31)
     */
    public function bindDepthTexture(textureUnit:Int = 0):Void {
        if (!hasDepthTexture) {
            trace("Warning: Framebuffer does not have a depth texture");
            return;
        }
        GL.activeTexture(GL.TEXTURE0 + textureUnit);
        GL.bindTexture(GL.TEXTURE_2D, depthTexture);
    }
    
    /**
     * Clear the framebuffer
     * @param r Red component (0-1)
     * @param g Green component (0-1)
     * @param b Blue component (0-1)
     * @param a Alpha component (0-1)
     * @param clearDepth Whether to clear depth buffer
     */
    public function clear(r:Float = 0.0, g:Float = 0.0, b:Float = 0.0, a:Float = 1.0, clearDepth:Bool = true):Void {
        bind();
        GL.glClearColor(r, g, b, a);
        var clearBits = GL.COLOR_BUFFER_BIT;
        if (clearDepth && (hasDepthTexture || hasDepthRenderbuffer)) {
            clearBits |= GL.DEPTH_BUFFER_BIT;
        }
        GL.glClear(clearBits);
        unbind();
    }
    
    /**
     * Resize the framebuffer
     * @param newWidth New width
     * @param newHeight New height
     */
    public function resize(newWidth:Int, newHeight:Int):Void {
        if (newWidth == width && newHeight == height) {
            return; // No change
        }
        
        trace("Resizing framebuffer from " + width + "x" + height + " to " + newWidth + "x" + newHeight);
        
        // Clean up old resources
        dispose();
        
        // Update dimensions
        width = newWidth;
        height = newHeight;
        
        // Recreate framebuffer
        initialize();
    }
    
    /**
     * Clean up OpenGL resources
     */
    public function dispose():Void {
        if (colorTexture != 0) {
            var texArray = [colorTexture];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", texArray));
            colorTexture = 0;
        }
        
        if (depthTexture != 0) {
            var texArray = [depthTexture];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", texArray));
            depthTexture = 0;
        }
        
        if (depthRenderbuffer != 0) {
            var rboArray = [depthRenderbuffer];
            GL.deleteRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", rboArray));
            depthRenderbuffer = 0;
        }
        
        if (fbo != 0) {
            var fboArray = [fbo];
            GL.deleteFramebuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", fboArray));
            fbo = 0;
        }
        
        trace("Framebuffer disposed");
    }
    
    /**
     * Check if the framebuffer is complete and valid
     */
    public function isComplete():Bool {
        GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
        return status == GL.FRAMEBUFFER_COMPLETE;
    }
    
    /**
     * Get framebuffer status as a string for debugging
     */
    public function getStatusString():String {
        GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
        var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
        GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
        
        return switch (status) {
            case 0x8CD5: "FRAMEBUFFER_COMPLETE";
            case 0x8CD6: "FRAMEBUFFER_INCOMPLETE_ATTACHMENT";
            case 0x8CD7: "FRAMEBUFFER_INCOMPLETE_MISSING_ATTACHMENT";
            case 0x8CDB: "FRAMEBUFFER_INCOMPLETE_DRAW_BUFFER";
            case 0x8CDC: "FRAMEBUFFER_INCOMPLETE_READ_BUFFER";
            case 0x8CDD: "FRAMEBUFFER_UNSUPPORTED";
            case 0x8D56: "FRAMEBUFFER_INCOMPLETE_MULTISAMPLE";
            default: "UNKNOWN_STATUS_" + status;
        }
    }
}
