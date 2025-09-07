# BEFORE: Manual texture binding in Tilemap
```haxe
override public function render(cameraMatrix:math.Matrix, renderer:Renderer):Void {
    // Manual texture binding
    GL.activeTexture(GL.TEXTURE0);
    GL.bindTexture(GL.TEXTURE_2D, atlasTexture);
    
    // Manual uniform setting with hardcoded name
    GL.useProgram(programInfo.program);
    var location = GL.getUniformLocation(programInfo.program, "ourTexture");
    if (location != -1) {
        GL.uniform1i(location, 0);
    }
    
    // Call parent
    super.render(cameraMatrix, renderer);
}
```

# AFTER: Automatic texture binding
```haxe
override public function render(cameraMatrix:math.Matrix, renderer:Renderer):Void {
    // Just call parent - texture binding happens automatically
    super.render(cameraMatrix, renderer);
}
```

# Usage: Just set the texture once
```haxe
tilemap.setTexture(textureId);  // Now it will bind automatically
```
