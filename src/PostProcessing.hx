package;

import Renderer;
import display.ScreenPass;

class PostProcessing {
    // Publics
    public var enabled:Bool = true;
    public var activePass(get, null):ScreenPass;
    public var passCount(get, null):Int;

    // Privates
    private var __renderer:Renderer;
    private var __passes:Array<ScreenPass> = [];
    private var __activePassIndex:Int = 0;
    private var __released:Bool = false;

    public function new(renderer:Renderer) {
        __renderer = renderer;
    }

    public function addPass(screenPass:ScreenPass):ScreenPass {
        ensureUsable();
        if (screenPass == null) throw "Cannot add a null post-processing pass";
        if (__passes.indexOf(screenPass) >= 0) return screenPass;

        __passes.push(screenPass);
        if (__activePassIndex < 0) __activePassIndex = 0;
        return screenPass;
    }

    public function removePass(screenPass:ScreenPass):Bool {
        ensureUsable();
        if (screenPass == null) return false;

        var index = __passes.indexOf(screenPass);
        if (index < 0) return false;

        __passes.splice(index, 1);
        screenPass.release(__renderer);

        if (__passes.length == 0) {
            __activePassIndex = -1;
        } else if (__activePassIndex >= __passes.length) {
            __activePassIndex = __passes.length - 1;
        } else if (index < __activePassIndex) {
            __activePassIndex--;
        }
        return true;
    }

    public function setActivePass(screenPass:ScreenPass):Bool {
        ensureUsable();
        if (screenPass == null) return false;
        var index = __passes.indexOf(screenPass);
        if (index < 0) return false;
        __activePassIndex = index;
        return true;
    }

    public function setActivePassIndex(index:Int):Bool {
        ensureUsable();
        if (__passes.length == 0) return false;
        if (index < 0 || index >= __passes.length) return false;
        __activePassIndex = index;
        return true;
    }

    public function cycle(delta:Int):Void {
        ensureUsable();
        if (__passes.length == 0) {
            __activePassIndex = -1;
            return;
        }

        __activePassIndex = (__activePassIndex + delta) % __passes.length;
        if (__activePassIndex < 0) {
            __activePassIndex += __passes.length;
        }

        if (activePass != null) {
            __renderer.app.log.info(
                Log.LogCategory.RENDERER,
                "Selected screen pass " + (__activePassIndex + 1) + "/" + __passes.length
                    + ": " + activePass.label
            );
        }
    }

    public function resize(width:Int, height:Int):Void {
        if (__released) return;
        for (screenPass in __passes) {
            screenPass.resize(__renderer, width, height);
        }
    }

    public function render(renderer:Renderer, renderScene:Void->Void):Void {
        ensureUsable();

        if (!enabled || __passes.length == 0) {
            renderer.clearScreen();
            renderScene();
            return;
        }

        var pass = activePass;
        if (pass == null) {
            renderer.clearScreen();
            renderScene();
            return;
        }

        var framebufferBound = false;
        try {
            renderer.bindFramebuffer(pass.framebufferId);
            framebufferBound = true;
            renderer.clearScreen();
            renderScene();
        } catch (error:Dynamic) {
            if (framebufferBound) {
                renderer.unbindFramebuffer(pass.framebufferId);
            }
            throw error;
        }
        if (framebufferBound) {
            renderer.unbindFramebuffer(pass.framebufferId);
        }

        renderer.clearScreen();
        pass.render(renderer);
    }

    public function release():Void {
        if (__released) return;
        releasePasses();
        __released = true;
    }

    private function releasePasses():Void {
        for (screenPass in __passes) {
            screenPass.release(__renderer);
        }
        __passes = [];
        __activePassIndex = -1;
    }

    private function ensureUsable():Void {
        if (__released) throw "Post-processing is released";
    }

    private function get_activePass():ScreenPass {
        return __passes.length > 0 ? __passes[__activePassIndex] : null;
    }

    private function get_passCount():Int {
        return __passes.length;
    }
}
