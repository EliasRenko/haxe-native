class AudioSmoke {
    static function check(ok:Bool, message:String):Void {
        if (!ok) throw message;
    }

    static function expectError(action:Void->Void, message:String):Void {
        var failed = false;
        try {
            action();
        } catch (_:Dynamic) {
            failed = true;
        }
        check(failed, message);
    }

    static function main():Void {
        var args = Sys.args();
        if (args.length != 1) throw "Provide a path to an audio file";
        check(SDLMixer.init(), "Failed to initialize SDL_mixer");

        var audio = new Audio();
        expectError(function() audio.load(""), "Empty path should fail");
        expectError(function() audio.load(args[0] + ".missing"), "Missing file should fail");
        var first = audio.load(args[0]);
        var second = audio.load(args[0], false);
        first.volume = 0.5;
        check(Math.abs(first.volume - 0.5) < 0.001, "Incorrect volume");
        expectError(function() first.volume = -1, "Negative volume should fail");
        expectError(function() first.volume = 1.1, "Volume above one should fail");

        first.play();
        second.play();
        check(first.playing && second.playing, "Sounds should play independently");
        first.pause();
        check(first.paused && second.playing, "Pause should affect only one sound");
        first.resume();
        check(first.playing && !first.paused, "Sound should resume");
        first.play();
        first.stop();
        check(!first.playing && second.playing, "Stop should affect only one sound");
        first.release();
        first.release();
        expectError(function() first.play(), "Released sound should not play");
        audio.release();
        audio.release();
        expectError(function() second.play(), "Mixer release should release its sounds");
        expectError(function() audio.load(args[0]), "Released mixer should not load");
        SDLMixer.quit();
        trace("Audio smoke test passed");
    }
}
