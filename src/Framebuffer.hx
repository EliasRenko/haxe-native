package;

import GL;

/**
 * Framebuffer Object (FBO) for render-to-texture operations
 * Used for post-processing effects, shadow mapping, reflections, etc.
 */
class Framebuffer {
    
    // OpenGL handles
    public var fbo:UInt = 0;
    public var colorTexture:Texture;
    public var depthTexture:Texture;
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
    }
    
    /**
     * Initialize the framebuffer and attachments
     */
    public function initialize(renderer:Renderer):Void {
        // Create framebuffer
        fbo = GL.createFramebuffer();
        GL.bindFramebuffer(GL.FRAMEBUFFER, fbo);
        
        // Create color texture
        colorTexture = renderer.createRenderTargetTexture(width, height, GL.RGBA, GL.RGBA, GL.UNSIGNED_BYTE);
        GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.COLOR_ATTACHMENT0, GL.TEXTURE_2D, colorTexture.id, 0);
        

        // Create depth attachment if needed
        if (hasDepthTexture) {
            depthTexture = renderer.createRenderTargetTexture(width, height, GL.DEPTH_COMPONENT, GL.DEPTH_COMPONENT, GL.UNSIGNED_INT);
            GL.framebufferTexture2D(GL.FRAMEBUFFER, GL.DEPTH_ATTACHMENT, GL.TEXTURE_2D, depthTexture.id, 0);
        } else if (hasDepthRenderbuffer) {
            createDepthRenderbuffer();
        }

		// Check framebuffer completeness
		var status = GL.checkFramebufferStatus(GL.FRAMEBUFFER);
		if (status != GL.FRAMEBUFFER_COMPLETE) {
			trace("ERROR: Framebuffer incomplete: " + getStatusString());
		} else {
			trace("Framebuffer created successfully: " + width + "x" + height);
		}
        
        
        // Unbind framebuffer
        GL.bindFramebuffer(GL.FRAMEBUFFER, 0);
    }
    
    /**
     * Create a depth renderbuffer attachment (for depth testing only, not readable)
     */
    private function createDepthRenderbuffer():Void {
        #if !js
        var rboArray:Array<UInt> = [0];
        GL.genRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", rboArray));
        depthRenderbuffer = rboArray[0];
        #else
        depthRenderbuffer = GL.createRenderbuffer();
        #end

        GL.bindRenderbuffer(GL.RENDERBUFFER, depthRenderbuffer);
        GL.renderbufferStorage(GL.RENDERBUFFER, GL.DEPTH_COMPONENT24, width, height);
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
        GL.bindTexture(GL.TEXTURE_2D, colorTexture.id);
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
        GL.bindTexture(GL.TEXTURE_2D, depthTexture.id);
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
    public function resize(renderer:Renderer, newWidth:Int, newHeight:Int):Void {
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
        initialize(renderer);
    }
    
    /**
     * Clean up OpenGL resources
     */
    public function dispose():Void {
        if (colorTexture != null) {
            #if !js
            var texArray = [colorTexture.id];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", texArray));
            #else
            GL.deleteTexture(colorTexture.id);
            #end
            colorTexture = null;
        }
        
        if (depthTexture != null) {
            #if !js
            var texArray = [depthTexture.id];
            GL.deleteTextures(1, untyped __cpp__("(unsigned int*)&{0}[0]", texArray));
            #else
            GL.deleteTexture(depthTexture.id);
            #end
            depthTexture = null;
        }
        
        if (depthRenderbuffer != 0) {
            #if !js
            var rboArray = [depthRenderbuffer];
            GL.deleteRenderbuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", rboArray));
            #else
            GL.deleteRenderbuffers(1, depthRenderbuffer);
            #end
            depthRenderbuffer = 0;
        }
        
        if (fbo != 0) {
            #if !js
            var fboArray = [fbo];
            GL.deleteFramebuffers(1, untyped __cpp__("(unsigned int*)&{0}[0]", fboArray));
            #else
            GL.deleteFramebuffers(1, fbo);
            #end
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
