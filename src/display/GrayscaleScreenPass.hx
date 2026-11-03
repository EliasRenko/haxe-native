package display;

import GL;
import Renderer;
import shaders.GrayscaleScreenPassShader;

class GrayscaleScreenPass extends ScreenPass {
    public function new(renderer:Renderer, width:Int, height:Int) {
        super(
            renderer,
            width,
            height,
            new GrayscaleScreenPassShader(),
            [{
                attachment: GL.COLOR_ATTACHMENT0,
                internalFormat: GL.RGBA8,
                format: GL.RGBA,
                type: GL.UNSIGNED_BYTE
            }],
            true,
            "Grayscale + depth renderbuffer"
        );
    }

}
