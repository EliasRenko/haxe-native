package;

import cpp.RawPointer;
import cpp.UInt8;
import cpp.UInt16;
import cpp.Star;
import cpp.UInt32;
import cpp.UInt64;
import cpp.ConstCharStar;
import cpp.Pointer;
import cpp.Struct;

typedef SDL_PropertiesID = UInt64;
typedef SDL_JoystickID = UInt32;

// Context
@:include("SDL3/SDL.h")
@:native("::cpp::Reference<SDL_GLContext>")
extern class GLContext {}

// Window
@:include("SDL3/SDL.h")
@:native("SDL_Window")
extern class SDL_Window {}
typedef WindowPtr = Pointer<SDL_Window>;

@:native("SDL_Gamepad")
extern class SDL_Gamepad {}

@:keep
@:buildXml(
'<target id="haxe" if="windows">
   <lib name="lib/x64/SDL3.lib"/>
   <lib name="user32.lib"/>
   <lib name="gdi32.lib"/>
   <lib name="winmm.lib"/>
   <lib name="imm32.lib"/>
   <lib name="ole32.lib"/>
   <lib name="oleaut32.lib"/>
   <lib name="shell32.lib"/>
   <lib name="setupapi.lib"/>
   <lib name="version.lib"/>
   <lib name="uuid.lib"/>
</target>
<files id="haxe">
    <compilerflag value="-Iinclude"/>
    <compilerflag value="-DHXCPP_NO_PCH"/>
    <compilerflag value="-DHXCPP_NO_PRECOMPILED_HEADERS"/>
</files>')
@:include("SDL3/SDL.h")
extern class SDL {
    
    // ** Init

    @:native("SDL_Init")
    static function init(flags:InitFlag):Bool;

    @:native("SDL_InitSubSystem")
    static function initSubSystem(flags:InitFlag):Bool;

    @:native("SDL_QuitSubSystem")
    static function quitSubSystem(flags:InitFlag):Void;

    @:native("SDL_WasInit")
    static function wasInit(flags:InitFlag):Int;

    @:native("SDL_Quit")
    static function quit():Void;

    @:native("SDL_IsMainThread")
    static function isMainThread():Bool;

    //@:native("SDL_RunOnMainThread")
    //static function runOnMainThread(callback:SDL_MainThreadCallback, userdata:cpp.Star<Dynamic>, wait_complete:Bool):Bool;

    @:native("SDL_SetAppMetadata")
    static function setAppMetadata(appname:cpp.ConstCharStar, appversion:cpp.ConstCharStar, appidentifier:cpp.ConstCharStar):Bool;

    @:native("SDL_SetAppMetadataProperty")
    static function setAppMetadataProperty(name:cpp.ConstCharStar, value:cpp.ConstCharStar):Bool;

    @:native("SDL_GetAppMetadataProperty")
    static function getAppMetadataProperty(name:cpp.ConstCharStar):cpp.ConstCharStar;

    // ** Video

    @:native("SDL_GetVideoDriver")
    static function getVideoDriver(index:Int):String;

    @:native("SDL_GetNumVideoDrivers")
    static function getNumVideoDrivers():Int;

    @:native("SDL_GetWindowSize")
    static function getWindowSize(window:WindowPtr, w:Pointer<Int>, h:Pointer<Int>):Bool;

    @:native("SDL_GetWindowSizeInPixels")
    static function getWindowSizeInPixels(window:WindowPtr, w:Pointer<Int>, h:Pointer<Int>):Bool;

    @:native("SDL_GL_SetSwapInterval")
    public static function setSwapInterval(interval:Int):Bool;

    @:native("SDL_GL_GetSwapInterval")
    public static function getSwapInterval(interval:Pointer<Int>):Bool;

    // ** 
    
    @:native("SDL_CreateWindow")
    static function createWindow(title:String, w:Int, h:Int, flags:CreateWindowFlag):WindowPtr;

    @:native("SDL_SetWindowFullscreen")
    static function setWindowFullscreen(window:WindowPtr, fullscreen:Bool):Int;

    @:native("SDL_GetPointerProperty")
    static function getPointerProperty(props:SDL_PropertiesID, name:cpp.ConstCharStar, defaultValue:cpp.RawPointer<Void>):cpp.RawPointer<Void>;

    @:native("SDL_GetWindowProperties")
    static function getWindowProperties(window:WindowPtr):SDL_PropertiesID;

    @:native("SDL_GL_CreateContext")
    static function createContext(window:WindowPtr):GLContext;

    @:native("SDL_GL_MakeCurrent")
    static function makeCurrent(window:WindowPtr, context:GLContext):Void;

    @:native("SDL_GL_GetProcAddress")
    static function getProcAddress(name:ConstCharStar):cpp.RawPointer<Void>;

    @:native("SDL_GL_GetProcAddress")
    static var getProcAddressPtr:(name:ConstCharStar) -> cpp.RawPointer<Void>;

    @:native("SDL_GL_SetAttribute")
    static function setAttribute(attr:SDL_GLAttr, value:Int):Int;

    @:native("SDL_GL_SwapWindow")
    static function swapWindow(window:WindowPtr):Void;

    @:native("SDL_PollEvent")
    static function pollEvent(event:Pointer<Event>):Bool;

    @:native("SDL_GetTicks")
    public static function getTicks():UInt;

    @:native("SDL_GetDesktopDisplayMode")
    public static function getDesktopDisplayMode(displayID:UInt64):Pointer<SDL_DisplayMode>;

    @:native("SDL_GetCurrentDisplayMode")
    public static function getCurrentDisplayMode(displayID:UInt64):Pointer<SDL_DisplayMode>;

    @:native("SDL_GetWindowDisplayScale")
    public static function getWindowDisplayScale(window:WindowPtr):Float;

    @:native("SDL_GetWindowFromID")
    public static function getWindowFromID(id:UInt):WindowPtr;

    @:native("SDL_GetWindowSafeArea")
    public static function getWindowSafeArea(windowID:UInt, rectPtr:Pointer<SDL_Rect>):Bool;

    @:native("SDL_GetDisplayContentScale")
    public static function getDisplayContentScale(displayID:UInt64):Float;

    static inline function getEvent():Pointer<Event> {
        var event:Pointer<Event> = null;
        untyped __cpp__("SDL_Event __sdl_ev__; {0} = &__sdl_ev__", event);
        return event;
    }

    // ** Erros
    @:native("SDL_GetError")
    static function getError():String;

    // ** Log
    @:native("SDL_SetLogPriorities")
    static function setLogPriorities(priority:SDL_LogPriority):Void;

    @:native("SDL_SetLogPriority")
    static function setLogPriority(category:Int, priority:SDL_LogPriority):Void;

    @:native("SDL_GetLogPriority")
    static function getLogPriority(category:Int):Int;

    @:native("SDL_ResetLogPriorities")
    static function resetLogPriorities():Void;

    @:native("SDL_SetLogPriorityPrefix")
    static function setLogPriorityPrefix(priority:Int, prefix:cpp.ConstCharStar):Bool;

    @:native("SDL_Log")
    static function log(text:String):Void;

    @:native("SDL_LogTrace")
    static function logTrace(category:Int, text:String):Void;

    @:native("SDL_LogVerbose")
    static function logVerbose(category:Int, text:String):Void;

    @:native("SDL_LogDebug")
    static function logDebug(category:Int, text:String):Void;

    @:native("SDL_LogInfo")
    static function logInfo(category:Int, text:String):Void;

    @:native("SDL_LogWarn")
    static function logWarn(category:Int, text:String):Void;

    @:native("SDL_LogError")
    static function logError(category:Int, text:String):Void;

    @:native("SDL_LogCritical")
    static function logCritical(category:Int, text:String):Void;

    @:native("SDL_LogMessage")
    static function logMessage(category:Int, priority:SDL_LogPriority, text:String):Void;

    @:native("SDL_SetLogOutputFunction")
    static function setLogOutputFunction(callback:cpp.RawPointer<Void>, userdata:cpp.RawPointer<Void>):Void;

    //@:native("SDL_LogMessageV")
    //static function logMessageV(category:Int, priority:SDL_LogPriority, text:String, ?):Void;

    // ** Gamepad

    @:native("SDL_GetGamepads")
    static function getGamepads(count:Pointer<Int>):Pointer<SDL_JoystickID>;

    @:native("SDL_OpenGamepad")
    static function openGamepad(instanceId:SDL_JoystickID):Pointer<SDL_Gamepad>;

    @:native("SDL_CloseGamepad")
    static function closeGamepad(gamepad:Pointer<SDL_Gamepad>):Void;

    @:native("SDL_GamepadConnected")
    static function gamepadConnected(gamepad:Pointer<SDL_Gamepad>):Bool;

    @:native("SDL_GetGamepadName")
    static function getGamepadName(gamepad:Pointer<SDL_Gamepad>):ConstCharStar;

    @:native("SDL_GetGamepadInstanceID")
    static function getGamepadInstanceID(gamepad:Pointer<SDL_Gamepad>):SDL_JoystickID;

    // ** Platform

    @:native("SDL_GetPlatform")
    public static function getPlatform():String;

    // ** Filesystem
    @:native("SDL_GetBasePath")
    static function getBasePath():String;
    @:native("SDL_GetPrefPath")
    static function getPrefPath(org:String, app:String):String;
    @:native("SDL_GetUserFolder")
    static function getUserFolder(folder:SDL_Folder):String;

    @:native("SDL_CreateDirectory")
    static function createDirectory(path:String):Bool;

    // @:native("SDL_EnumerateDirectory")
    // static function enumerateDirectory(
    //     path:cpp.ConstCharStar,
    //     callback:cpp.Star<cpp.Void>, // You may want to typedef SDL_EnumerateDirectoryCallback
    //     userdata:cpp.Star<cpp.Void>
    // ):Bool;

    @:native("SDL_RemovePath")
    static function removePath(path:String):Bool;

    @:native("SDL_RenamePath")
    static function renamePath(oldpath:String, newpath:String):Bool;

    @:native("SDL_CopyFile")
    static function copyFile(oldpath:String, newpath:String):Bool;

    @:native("SDL_GetPathInfo")
    static function getPathInfo(path:String, info:cpp.Star<cpp.Void>):Bool; // You may want to typedef SDL_PathInfo

    @:native("SDL_GlobDirectory")
    static function globDirectory(
        path:cpp.ConstCharStar,
        pattern:cpp.ConstCharStar,
        flags:Int, // SDL_GlobFlags
        count:cpp.Star<Int>
    ):cpp.Pointer<cpp.Pointer<cpp.Char>>;

    @:native("SDL_GetCurrentDirectory")
    static function getCurrentDirectory():cpp.Pointer<cpp.Char>;

    // ** IO stream
    @:native("SDL_LoadFile")
    static function loadFile(path:String, datasize:Star<UInt64>):cpp.Pointer<cpp.Char>;

    @:native("SDL_free")
    static function free(ptr:cpp.Pointer<cpp.Char>):Void;

    // ** Window flags
    @:native("SDL_WINDOW_FULLSCREEN")
    static var WINDOW_FULLSCREEN(default, null):CreateWindowFlag;

    // @:native("SDL_WINDOW_FULLSCREEN_DESKTOP")
    // static var WINDOW_FULLSCREEN_DESKTOP(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_OPENGL")
    static var WINDOW_OPENGL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_OCCLUDED")
    static var WINDOW_OCCLUDED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_HIDDEN")
    static var WINDOW_HIDDEN(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_BORDERLESS")
    static var WINDOW_BORDERLESS(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_RESIZABLE")
    static var WINDOW_RESIZABLE(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MINIMIZED")
    static var WINDOW_MINIMIZED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MAXIMIZED")
    static var WINDOW_MAXIMIZED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_GRABBED")
    static var WINDOW_MOUSE_GRABBED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_INPUT_FOCUS")
    static var WINDOW_INPUT_FOCUS(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_FOCUS")
    static var WINDOW_MOUSE_FOCUS(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_EXTERNAL")
    static var WINDOW_EXTERNAL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MODAL")
    static var WINDOW_MODAL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_HIGH_PIXEL_DENSITY")
    static var WINDOW_HIGH_PIXEL_DENSITY(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_CAPTURE")
    static var WINDOW_MOUSE_CAPTURE(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_MOUSE_RELATIVE_MODE")
    static var WINDOW_MOUSE_RELATIVE_MODE(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_ALWAYS_ON_TOP")
    static var WINDOW_ALWAYS_ON_TOP(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_UTILITY")
    static var WINDOW_UTILITY(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_TOOLTIP")
    static var WINDOW_TOOLTIP(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_POPUP_MENU")
    static var WINDOW_POPUP_MENU(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_KEYBOARD_GRABBED")
    static var WINDOW_KEYBOARD_GRABBED(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_VULKAN")
    static var WINDOW_VULKAN(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_METAL")
    static var WINDOW_METAL(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_TRANSPARENT")
    static var WINDOW_TRANSPARENT(default, null):CreateWindowFlag;

    @:native("SDL_WINDOW_NOT_FOCUSABLE")
    static var WINDOW_NOT_FOCUSABLE(default, null):CreateWindowFlag;

    @:native("SDL_StartTextInput")
    public static function startTextInput(window:WindowPtr):Bool;

    @:native("SDL_StopTextInput")
    public static function stopTextInput(window:WindowPtr):Bool;

    //@:native("SDL_GetClipboardText")
    //public static function getClipboardText():ConstCharStar;

    public static inline function getClipboardText():String {
        var ptr:cpp.ConstCharStar = untyped __cpp__("SDL_GetClipboardText()");
        var str:String = ptr;
        untyped __cpp__("SDL_free((void*){0})", ptr);
    return str;
}

    // ** Folders

    @:native("SDL_FOLDER_HOME")
    static var FOLDER_HOME(default, null):SDL_Folder;
    @:native("SDL_FOLDER_DESKTOP")
    static var FOLDER_DESKTOP(default, null):SDL_Folder;
    @:native("SDL_FOLDER_DOCUMENTS")
    static var FOLDER_DOCUMENTS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_DOWNLOADS")
    static var FOLDER_DOWNLOADS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_MUSIC")
    static var FOLDER_MUSIC(default, null):SDL_Folder;
    @:native("SDL_FOLDER_PICTURES")
    static var FOLDER_PICTURES(default, null):SDL_Folder;
    @:native("SDL_FOLDER_PUBLICSHARE")
    static var FOLDER_PUBLICSHARE(default, null):SDL_Folder;
    @:native("SDL_FOLDER_SAVEDGAMES")
    static var FOLDER_SAVEDGAMES(default, null):SDL_Folder;
    @:native("SDL_FOLDER_SCREENSHOTS")
    static var FOLDER_SCREENSHOTS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_TEMPLATES")
    static var FOLDER_TEMPLATES(default, null):SDL_Folder;
    @:native("SDL_FOLDER_VIDEOS")
    static var FOLDER_VIDEOS(default, null):SDL_Folder;
    @:native("SDL_FOLDER_COUNT")
    static var FOLDER_COUNT(default, null):SDL_Folder;
    
    // ** GL Attrs

    @:native("SDL_GL_RED_SIZE")
    static var GL_RED_SIZE(default, null):SDL_GLAttr;
    @:native("SDL_GL_CONTEXT_MAJOR_VERSION")
    static var GL_CONTEXT_MAJOR_VERSION(default, null):SDL_GLAttr;
    @:native("SDL_GL_CONTEXT_MINOR_VERSION")
    static var GL_CONTEXT_MINOR_VERSION(default, null):SDL_GLAttr;

    @:native("SDL_GL_CONTEXT_PROFILE_MASK")
    static var GL_CONTEXT_PROFILE_MASK(default, null):SDL_GLAttr;
    @:native("SDL_GL_CONTEXT_PROFILE_CORE")
    static var GL_CONTEXT_PROFILE_CORE(default, null):Int;

    // ** Log priorities

    @:native("SDL_LOG_PRIORITY_INVALID")
    static var LOG_PRIORITY_INVALID(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_TRACE")
    static var LOG_PRIORITY_TRACE(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_VERBOSE")
    static var LOG_PRIORITY_VERBOSE(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_DEBUG")
    static var LOG_PRIORITY_DEBUG(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_INFO")
    static var LOG_PRIORITY_INFO(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_WARN")
    static var LOG_PRIORITY_WARN(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_ERROR")
    static var LOG_PRIORITY_ERROR(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_CRITICAL")
    static var LOG_PRIORITY_CRITICAL(default, null):SDL_LogPriority;
    @:native("SDL_LOG_PRIORITY_COUNT")
    static var LOG_PRIORITY_COUNT(default, null):SDL_LogPriority;


    // ** Event types

    // Unused events
    @:native("SDL_EVENT_FIRST")
    static var EVENT_FIRST(default, null):SDL_EventType;

    // Application events
    @:native("SDL_EVENT_QUIT")
    static var EVENT_QUIT(default, null):SDL_EventType;
    @:native("SDL_EVENT_TERMINATING")
    static var EVENT_TERMINATING(default, null):SDL_EventType;
    @:native("SDL_EVENT_LOW_MEMORY")
    static var EVENT_LOW_MEMORY(default, null):SDL_EventType;
    @:native("SDL_EVENT_WILL_ENTER_BACKGROUND")
    static var EVENT_WILL_ENTER_BACKGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_DID_ENTER_BACKGROUND")
    static var EVENT_DID_ENTER_BACKGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_WILL_ENTER_FOREGROUND")
    static var EVENT_WILL_ENTER_FOREGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_DID_ENTER_FOREGROUND")
    static var EVENT_DID_ENTER_FOREGROUND(default, null):SDL_EventType;
    @:native("SDL_EVENT_LOCALE_CHANGED")
    static var EVENT_LOCALE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_SYSTEM_THEME_CHANGED")
    static var EVENT_SYSTEM_THEME_CHANGED(default, null):SDL_EventType;

    // Display events
    @:native("SDL_EVENT_DISPLAY_ORIENTATION")
    static var EVENT_DISPLAY_ORIENTATION(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_ADDED")
    static var EVENT_DISPLAY_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_REMOVED")
    static var EVENT_DISPLAY_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_MOVED")
    static var EVENT_DISPLAY_MOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_DESKTOP_MODE_CHANGED")
    static var EVENT_DISPLAY_DESKTOP_MODE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_CURRENT_MODE_CHANGED")
    static var EVENT_DISPLAY_CURRENT_MODE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_CONTENT_SCALE_CHANGED")
    static var EVENT_DISPLAY_CONTENT_SCALE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_FIRST")
    static var EVENT_DISPLAY_FIRST(default, null):SDL_EventType;
    @:native("SDL_EVENT_DISPLAY_LAST")
    static var EVENT_DISPLAY_LAST(default, null):SDL_EventType;

    // Window events
    @:native("SDL_EVENT_WINDOW_SHOWN")
    static var EVENT_WINDOW_SHOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_HIDDEN")
    static var EVENT_WINDOW_HIDDEN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_EXPOSED")
    static var EVENT_WINDOW_EXPOSED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MOVED")
    static var EVENT_WINDOW_MOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_RESIZED")
    static var EVENT_WINDOW_RESIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED")
    static var EVENT_WINDOW_PIXEL_SIZE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_METAL_VIEW_RESIZED")
    static var EVENT_WINDOW_METAL_VIEW_RESIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MINIMIZED")
    static var EVENT_WINDOW_MINIMIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MAXIMIZED")
    static var EVENT_WINDOW_MAXIMIZED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_RESTORED")
    static var EVENT_WINDOW_RESTORED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MOUSE_ENTER")
    static var EVENT_WINDOW_MOUSE_ENTER(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_MOUSE_LEAVE")
    static var EVENT_WINDOW_MOUSE_LEAVE(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_FOCUS_GAINED")
    static var EVENT_WINDOW_FOCUS_GAINED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_FOCUS_LOST")
    static var EVENT_WINDOW_FOCUS_LOST(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_CLOSE_REQUESTED")
    static var EVENT_WINDOW_CLOSE_REQUESTED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_HIT_TEST")
    static var EVENT_WINDOW_HIT_TEST(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_ICCPROF_CHANGED")
    static var EVENT_WINDOW_ICCPROF_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_DISPLAY_CHANGED")
    static var EVENT_WINDOW_DISPLAY_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED")
    static var EVENT_WINDOW_DISPLAY_SCALE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_SAFE_AREA_CHANGED")
    static var EVENT_WINDOW_SAFE_AREA_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_OCCLUDED")
    static var EVENT_WINDOW_OCCLUDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_ENTER_FULLSCREEN")
    static var EVENT_WINDOW_ENTER_FULLSCREEN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_LEAVE_FULLSCREEN")
    static var EVENT_WINDOW_LEAVE_FULLSCREEN(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_DESTROYED")
    static var EVENT_WINDOW_DESTROYED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_HDR_STATE_CHANGED")
    static var EVENT_WINDOW_HDR_STATE_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_FIRST")
    static var EVENT_WINDOW_FIRST(default, null):SDL_EventType;
    @:native("SDL_EVENT_WINDOW_LAST")
    static var EVENT_WINDOW_LAST(default, null):SDL_EventType;

    // Keyboard events
    @:native("SDL_EVENT_KEY_DOWN")
    static var EVENT_KEY_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEY_UP")
    static var EVENT_KEY_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_TEXT_EDITING")
    static var EVENT_TEXT_EDITING(default, null):SDL_EventType;
    @:native("SDL_EVENT_TEXT_INPUT")
    static var EVENT_TEXT_INPUT(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEYMAP_CHANGED")
    static var EVENT_KEYMAP_CHANGED(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEYBOARD_ADDED")
    static var EVENT_KEYBOARD_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_KEYBOARD_REMOVED")
    static var EVENT_KEYBOARD_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_TEXT_EDITING_CANDIDATES")
    static var EVENT_TEXT_EDITING_CANDIDATES(default, null):SDL_EventType;
    
    // Mouse events
    @:native("SDL_EVENT_MOUSE_MOTION")
    static var EVENT_MOUSE_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_BUTTON_DOWN")
    static var EVENT_MOUSE_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_BUTTON_UP")
    static var EVENT_MOUSE_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_WHEEL")
    static var EVENT_MOUSE_WHEEL(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_ADDED")
    static var EVENT_MOUSE_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_MOUSE_REMOVED")
    static var EVENT_MOUSE_REMOVED(default, null):SDL_EventType;

    // Joystick events
    @:native("SDL_EVENT_JOYSTICK_AXIS_MOTION")
    static var EVENT_JOYSTICK_AXIS_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BALL_MOTION")
    static var EVENT_JOYSTICK_BALL_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_HAT_MOTION")
    static var EVENT_JOYSTICK_HAT_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BUTTON_DOWN")
    static var EVENT_JOYSTICK_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BUTTON_UP")
    static var EVENT_JOYSTICK_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_ADDED")
    static var EVENT_JOYSTICK_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_REMOVED")
    static var EVENT_JOYSTICK_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_BATTERY_UPDATED")
    static var EVENT_JOYSTICK_BATTERY_UPDATED(default, null):SDL_EventType;
    @:native("SDL_EVENT_JOYSTICK_UPDATE_COMPLETE")
    static var EVENT_JOYSTICK_UPDATE_COMPLETE(default, null):SDL_EventType;

    // Gamepad events
    @:native("SDL_EVENT_GAMEPAD_AXIS_MOTION")
    static var EVENT_GAMEPAD_AXIS_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_BUTTON_DOWN")
    static var EVENT_GAMEPAD_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_BUTTON_UP")
    static var EVENT_GAMEPAD_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_ADDED")
    static var EVENT_GAMEPAD_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_REMOVED")
    static var EVENT_GAMEPAD_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_REMAPPED")
    static var EVENT_GAMEPAD_REMAPPED(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_TOUCHPAD_DOWN")
    static var EVENT_GAMEPAD_TOUCHPAD_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_TOUCHPAD_MOTION")
    static var EVENT_GAMEPAD_TOUCHPAD_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_TOUCHPAD_UP")
    static var EVENT_GAMEPAD_TOUCHPAD_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_SENSOR_UPDATE")
    static var EVENT_GAMEPAD_SENSOR_UPDATE(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_UPDATE_COMPLETE")
    static var EVENT_GAMEPAD_UPDATE_COMPLETE(default, null):SDL_EventType;
    @:native("SDL_EVENT_GAMEPAD_STEAM_HANDLE_UPDATED")
    static var EVENT_GAMEPAD_STEAM_HANDLE_UPDATED(default, null):SDL_EventType;

    // Touch events
    @:native("SDL_EVENT_FINGER_DOWN")
    static var EVENT_FINGER_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_FINGER_UP")
    static var EVENT_FINGER_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_FINGER_MOTION")
    static var EVENT_FINGER_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_FINGER_CANCELED")
    static var EVENT_FINGER_CANCELED(default, null):SDL_EventType;

    // Clipboard events
    @:native("SDL_EVENT_CLIPBOARD_UPDATE")
    static var EVENT_CLIPBOARD_UPDATE(default, null):SDL_EventType;

    // Drag and drop events
    @:native("SDL_EVENT_DROP_FILE")
    static var EVENT_DROP_FILE(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_TEXT")
    static var EVENT_DROP_TEXT(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_BEGIN")
    static var EVENT_DROP_BEGIN(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_COMPLETE")
    static var EVENT_DROP_COMPLETE(default, null):SDL_EventType;
    @:native("SDL_EVENT_DROP_POSITION")
    static var EVENT_DROP_POSITION(default, null):SDL_EventType;

    // Audio hotplug events
    @:native("SDL_EVENT_AUDIO_DEVICE_ADDED")
    static var EVENT_AUDIO_DEVICE_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_AUDIO_DEVICE_REMOVED")
    static var EVENT_AUDIO_DEVICE_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_AUDIO_DEVICE_FORMAT_CHANGED")
    static var EVENT_AUDIO_DEVICE_FORMAT_CHANGED(default, null):SDL_EventType;

    // Sensor events
    @:native("SDL_EVENT_SENSOR_UPDATE")
    static var EVENT_SENSOR_UPDATE(default, null):SDL_EventType;

    // Pen events
    @:native("SDL_EVENT_PEN_PROXIMITY_IN")
    static var EVENT_PEN_PROXIMITY_IN(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_PROXIMITY_OUT")
    static var EVENT_PEN_PROXIMITY_OUT(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_DOWN")
    static var EVENT_PEN_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_UP")
    static var EVENT_PEN_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_BUTTON_DOWN")
    static var EVENT_PEN_BUTTON_DOWN(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_BUTTON_UP")
    static var EVENT_PEN_BUTTON_UP(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_MOTION")
    static var EVENT_PEN_MOTION(default, null):SDL_EventType;
    @:native("SDL_EVENT_PEN_AXIS")
    static var EVENT_PEN_AXIS(default, null):SDL_EventType;

    // Camera hotplug events
    @:native("SDL_EVENT_CAMERA_DEVICE_ADDED")
    static var EVENT_CAMERA_DEVICE_ADDED(default, null):SDL_EventType;
    @:native("SDL_EVENT_CAMERA_DEVICE_REMOVED")
    static var EVENT_CAMERA_DEVICE_REMOVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_CAMERA_DEVICE_APPROVED")
    static var EVENT_CAMERA_DEVICE_APPROVED(default, null):SDL_EventType;
    @:native("SDL_EVENT_CAMERA_DEVICE_DENIED")
    static var EVENT_CAMERA_DEVICE_DENIED(default, null):SDL_EventType;

    // Render events
    @:native("SDL_EVENT_RENDER_TARGETS_RESET")
    static var EVENT_RENDER_TARGETS_RESET(default, null):SDL_EventType;
    @:native("SDL_EVENT_RENDER_DEVICE_RESET")
    static var EVENT_RENDER_DEVICE_RESET(default, null):SDL_EventType;
    @:native("SDL_EVENT_RENDER_DEVICE_LOST")
    static var EVENT_RENDER_DEVICE_LOST(default, null):SDL_EventType;

    // Private events
    @:native("SDL_EVENT_PRIVATE0")
    static var EVENT_PRIVATE0(default, null):SDL_EventType;
    @:native("SDL_EVENT_PRIVATE1")
    static var EVENT_PRIVATE1(default, null):SDL_EventType;
    @:native("SDL_EVENT_PRIVATE2")
    static var EVENT_PRIVATE2(default, null):SDL_EventType;
    @:native("SDL_EVENT_PRIVATE3")
    static var EVENT_PRIVATE3(default, null):SDL_EventType;

    // Internal events
    @:native("SDL_EVENT_POLL_SENTINEL")
    static var EVENT_POLL_SENTINEL(default, null):SDL_EventType;

    // User events
    @:native("SDL_EVENT_USER")
    static var EVENT_USER(default, null):SDL_EventType;
    @:native("SDL_EVENT_LAST")
    static var EVENT_LAST(default, null):SDL_EventType;


    // ** Init flags

    @:native("SDL_INIT_VIDEO")
    static var INIT_VIDEO(default,null):InitFlag;
    
    @:native("SDL_INIT_AUDIO")
    static var INIT_AUDIO(default,null):InitFlag;
    
    @:native("SDL_INIT_JOYSTICK")
    static var INIT_JOYSTICK(default,null):InitFlag;
    
    @:native("SDL_INIT_GAMEPAD")
    static var INIT_GAMEPAD(default,null):InitFlag;
    
    @:native("SDL_INIT_HAPTIC")
    static var INIT_HAPTIC(default,null):InitFlag;
    
    @:native("SDL_INIT_SENSOR")
    static var INIT_SENSOR(default,null):InitFlag;
}

// @:native("SDL_Event")
// extern class Event {}

@:structAccess
@:native("::cpp::Struct<SDL_Rect>")
extern class SDL_Rect {
    var x:Int;
    var y:Int;
    var w:Int;
    var h:Int;
}

@:native("SDL_GamepadButtonEvent")
@:structAccess
extern class GamepadButtonEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:SDL_JoystickID;
    var button:Int;
    var down:Bool;
}

@:native("SDL_GamepadAxisEvent")
@:structAccess
extern class GamepadAxisEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:SDL_JoystickID;
    var axis:Int;
    var value:Int;
}

@:native("SDL_GamepadDeviceEvent")
@:structAccess
extern class GamepadDeviceEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:SDL_JoystickID;
}

@:native("SDL_Event")
@:structAccess
extern class Event {

    var type:SDL_EventType;
    var display:SDL_DisplayEvent;
    var window:WindowEvent;
    var key:KeyboardEvent;
    // var edit:TextEditingEvent;
    var text:TextInputEvent;
    var mdevice:MouseDeviceEvent;
    var motion:MouseMotionEvent;
    var button:MouseButtonEvent;
    var wheel:MouseWheelEvent;
    var jdevice:JoyDeviceEvent;
    var jaxis:JoyAxisEvent;
    var jball:JoyBallEvent;
    var jhat:JoyHatEvent;
    var jbutton:JoyButtonEvent;
    var jbattery:JoyBatteryEvent;
    var gdevice:GamepadDeviceEvent;
    var gaxis:GamepadAxisEvent;
    var gbutton:GamepadButtonEvent;
    var gtouchpad:GamepadTouchpadEvent;
    var gsensor:GamepadSensorEvent;
    var clipboard:ClipboardEvent;
    var tfinger:TouchFingerEvent;
    // var caxis:ControllerAxisEvent;
    // var cbutton:ControllerButtonEvent;
    // var cdevice:ControllerDeviceEvent;
    // var adevice:AudioDeviceEvent;
    // var quit:QuitEvent;
    // // var user:UserEvent;
    // // var syswm:SysWMEvent;
    // var tfinger:TouchFingerEvent;
    // var mgesture:MultiGestureEvent;
    // var dgesture:DollarGestureEvent;
    // var drop:DropEvent;
}

@:structAccess
@:native("::cpp::Struct<SDL_DisplayEvent>")
extern class SDL_DisplayEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var displayID:UInt64; // SDL_DisplayID
    var data1:Int;
    var data2:Int;
}

@:structAccess
@:native("::cpp::Struct<SDL_DisplayMode>")
extern class SDL_DisplayMode {
    var displayID:UInt64; // SDL_DisplayID
    var format:UInt32;    // SDL_PixelFormat
    var w:Int;
    var h:Int;
    var pixel_density:Float;
    var refresh_rate:Float;
    var refresh_rate_numerator:Int;
    var refresh_rate_denominator:Int;
    var internal:cpp.Pointer<Void>; // SDL_DisplayModeData*
}

@:structAccess
@:native("::cpp::Struct<SDL_WindowEvent>")
extern class WindowEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var windowID:UInt; // SDL_WindowID
    var data1:Int;
    var data2:Int;
}

@:structAccess
@:native("::cpp::Struct<SDL_KeyboardEvent>")
extern class KeyboardEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var windowID:UInt;
    var which:UInt; // SDL_KeyboardID
    var scancode:Int;
    var key:Int;
    var mod:SDL_Keymod;
    var raw:UInt16;
    var down:Bool;
    var repeat:Bool;
}

@:structAccess
@:native("::cpp::Struct<SDL_TextInputEvent>")
extern class TextInputEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var windowID:UInt;
    var text:ConstCharStar;
}

@:structAccess
@:native("::cpp::Struct<SDL_MouseButtonEvent>")
extern class MouseButtonEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var windowID:UInt;
    var which:UInt; // SDL_MouseID
    var button:UInt8;
    var down:Bool;
    var clicks:UInt8;
    var x:Float;
    var y:Float;
}

@:structAccess
@:native("::cpp::Struct<SDL_MouseMotionEvent>")
extern class MouseMotionEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var windowID:UInt;
    var which:UInt; // SDL_MouseID
    var state:UInt32; // SDL_MouseButtonFlags
    var x:Float;
    var y:Float;
    var xrel:Float;
    var yrel:Float;
}

@:structAccess
@:native("::cpp::Struct<SDL_MouseWheelEvent>")
extern class MouseWheelEvent {
    var type:SDL_EventType;
    var reserved:UInt32;
    var timestamp:UInt64;
    var windowID:UInt;
    var which:UInt; // SDL_MouseID
    var x:Float;
    var y:Float;
    var direction:UInt32; // SDL_MouseWheelDirection
    var mouse_x:Float;
    var mouse_y:Float;
    var integer_x:Int;
    var integer_y:Int;
}

@:structAccess
@:native("::cpp::Struct<SDL_MouseDeviceEvent>")
extern class MouseDeviceEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt; // SDL_MouseID
}

@:structAccess
@:native("::cpp::Struct<SDL_JoyDeviceEvent>")
extern class JoyDeviceEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
}

@:structAccess
@:native("::cpp::Struct<SDL_JoyAxisEvent>")
extern class JoyAxisEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var axis:UInt8;
    var value:Int; // Sint16
}

@:structAccess
@:native("::cpp::Struct<SDL_JoyBallEvent>")
extern class JoyBallEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var ball:UInt8;
    var xrel:Int; // Sint16
    var yrel:Int; // Sint16
}

@:structAccess
@:native("::cpp::Struct<SDL_JoyHatEvent>")
extern class JoyHatEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var hat:UInt8;
    var value:UInt8;
}

@:structAccess
@:native("::cpp::Struct<SDL_JoyButtonEvent>")
extern class JoyButtonEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var button:UInt8;
    var down:Bool;
}

@:structAccess
@:native("::cpp::Struct<SDL_JoyBatteryEvent>")
extern class JoyBatteryEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var state:Int;    // SDL_PowerState
    var percent:Int;
}

@:structAccess
@:native("::cpp::Struct<SDL_GamepadTouchpadEvent>")
extern class GamepadTouchpadEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var touchpad:Int;
    var finger:Int;
    var x:Float;
    var y:Float;
    var pressure:Float;
}

@:structAccess
@:native("::cpp::Struct<SDL_GamepadSensorEvent>")
extern class GamepadSensorEvent {
    var type:SDL_EventType;
    var reserved:UInt32;
    var timestamp:UInt64;
    var which:UInt32; // SDL_JoystickID
    var sensor:Int; // SDL_SensorType
    var data:RawPointer<Float>; // float[3]
    var sensor_timestamp:UInt64;
}

@:structAccess
@:native("::cpp::Struct<SDL_ClipboardEvent>")
extern class ClipboardEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var owner:Bool;
    var num_mime_types:Int;
    var mime_types:cpp.Pointer<cpp.ConstCharStar>;
}

@:structAccess
@:native("::cpp::Struct<SDL_TouchFingerEvent>")
extern class TouchFingerEvent {
    var type:SDL_EventType;
    var timestamp:UInt64;
    var touchID:UInt64; // SDL_TouchID
    var fingerID:UInt64; // SDL_FingerID
    var x:Float;
    var y:Float;
    var dx:Float;
    var dy:Float;
    var pressure:Float;
    var windowID:UInt; // SDL_WindowID
}

@:enum
abstract SDL_SystemEventType(UInt) from UInt to UInt {
    var QUIT = 0x100;
    var TERMINATING = 0x101;
    var LOW_MEMORY = 0x102;
    var WILL_ENTER_BACKGROUND = 0x103;
    var DID_ENTER_BACKGROUND = 0x104;
    var WILL_ENTER_FOREGROUND = 0x105;
    var DID_ENTER_FOREGROUND = 0x106;
    var LOCALE_CHANGED = 0x107;
    var SYSTEM_THEME_CHANGED = 0x108;
}

@:enum
abstract SDL_DisplayEventType(UInt) from UInt to UInt {
    var DISPLAY_ORIENTATION = 0x150;
    var DISPLAY_ADDED = 0x151;
    var DISPLAY_REMOVED = 0x152;
    var DISPLAY_MOVED = 0x153;
    var DISPLAY_DESKTOP_MODE_CHANGED = 0x154;
    var DISPLAY_CURRENT_MODE_CHANGED = 0x155;
    var DISPLAY_CONTENT_SCALE_CHANGED  = 0x156;
}

@:enum
abstract SDL_WindowEventType(UInt) from UInt to UInt {
    var WINDOW_SHOWN = 0x202;
    var WINDOW_HIDDEN = 0x203;
    var WINDOW_EXPOSED = 0x204;
    var WINDOW_MOVED = 0x205;
    var WINDOW_RESIZED = 0x206;
    var WINDOW_PIXEL_SIZE_CHANGED = 0x207;
    var WINDOW_METAL_VIEW_RESIZED = 0x208;
    var WINDOW_MINIMIZED = 0x209;
    var WINDOW_MAXIMIZED = 0x20A;
    var WINDOW_RESTORED = 0x20B;
    var WINDOW_MOUSE_ENTER = 0x20C;
    var WINDOW_MOUSE_LEAVE = 0x20D;
    var WINDOW_FOCUS_GAINED = 0x20E;
    var WINDOW_FOCUS_LOST = 0x20F;
    var WINDOW_CLOSE_REQUESTED = 0x210;
    var WINDOW_HIT_TEST = 0x211;
    var WINDOW_ICCPROF_CHANGED = 0x212;
    var WINDOW_DISPLAY_CHANGED = 0x213;
    var WINDOW_DISPLAY_SCALE_CHANGED = 0x214;
    var WINDOW_SAFE_AREA_CHANGED = 0x215;
    var WINDOW_OCCLUDED = 0x216;
    var WINDOW_ENTER_FULLSCREEN = 0x217;
    var WINDOW_LEAVE_FULLSCREEN = 0x218;
    var WINDOW_DESTROYED = 0x219;
    var WINDOW_HDR_STATE_CHANGED = 0x21A;
}

@:enum
abstract SDL_DisplayOrientation(Int) from Int to Int {
    var UNKNOWN = 0;
    var LANDSCAPE = 1;
    var LANDSCAPE_FLIPPED = 2;
    var PORTRAIT = 3;
    var PORTRAIT_FLIPPED = 4;
}

@:enum
abstract SDL_KeyboardEventType(UInt) from UInt to UInt {
    var KEY_DOWN = 0x300; 
    var KEY_UP = 0x301; 
    var TEXT_EDITING = 0x302; 
    var TEXT_INPUT = 0x303; 
    var KEYMAP_CHANGED = 0x304; 
    var KEYBOARD_ADDED = 0x305; 
    var KEYBOARD_REMOVED = 0x306; 
    var TEXT_EDITING_CANDIDATES = 0x307;
}

@:enum
abstract SDL_Keymod(UInt16) from UInt16 to UInt16 {
    var NONE = 0x0000;
    var LSHIFT = 0x0001;
    var RSHIFT = 0x0002;
    var LEVEL5 = 0x0004;
    var LCTRL = 0x0040;
    var RCTRL = 0x0080;
    var LALT = 0x0100;
    var RALT = 0x0200;
    var LGUI = 0x0400;
    var RGUI = 0x0800;
    var NUM = 0x1000;
    var CAPS = 0x2000;
    var MODE = 0x4000;
    var SCROLL = 0x8000;

    var CTRL = LCTRL | RCTRL;
    var SHIFT = LSHIFT | RSHIFT;
    var ALT = LALT | RALT;
    var GUI = LGUI | RGUI;
}

@:enum
abstract SDL_MouseEventType(UInt) from UInt to UInt {
    var MOUSE_MOTION = 0x400;
    var MOUSE_BUTTON_DOWN = 0x401;
    var MOUSE_BUTTON_UP = 0x402;
    var MOUSE_WHEEL = 0x403;
    var MOUSE_ADDED = 0x404;
    var MOUSE_REMOVED = 0x405;
}

@:enum
abstract SDL_JoystickEventType(UInt) from UInt to UInt {
    var JOYSTICK_AXIS_MOTION = 0x600;
    var JOYSTICK_BALL_MOTION = 0x601;
    var JOYSTICK_HAT_MOTION = 0x602;
    var JOYSTICK_BUTTON_DOWN = 0x603;
    var JOYSTICK_BUTTON_UP = 0x604;
    var JOYSTICK_ADDED = 0x605;
    var JOYSTICK_REMOVED = 0x606;
    var JOYSTICK_BATTERY_UPDATED = 0x607;
    var JOYSTICK_UPDATE_COMPLETE = 0x608;
}

@:enum
abstract SDL_PowerState(Int) from Int to Int {
    var ERROR = -1;
    var UNKNOWN = 0;
    var ON_BATTERY = 1;
    var NO_BATTERY = 2;
    var CHARGING = 3;
    var CHARGED = 4;
}

@:enum
abstract SDL_GamepadEventType(UInt) from UInt to UInt {
    var GAMEPAD_AXIS_MOTION = 0x650;
    var GAMEPAD_BUTTON_DOWN = 0x651;
    var GAMEPAD_BUTTON_UP = 0x652;
    var GAMEPAD_ADDED = 0x653;
    var GAMEPAD_REMOVED = 0x654;
    var GAMEPAD_REMAPPED = 0x655;
    var GAMEPAD_TOUCHPAD_DOWN = 0x656;
    var GAMEPAD_TOUCHPAD_MOTION = 0x657;
    var GAMEPAD_TOUCHPAD_UP = 0x658;
    var GAMEPAD_SENSOR_UPDATE = 0x659;
    var GAMEPAD_UPDATE_COMPLETE = 0x65A;
    var GAMEPAD_STEAM_HANDLE_UPDATED = 0x65B;
}

@:enum
abstract SDL_FingerEventType(UInt) from UInt to UInt {
    var FINGER_DOWN = 0x700;
    var FINGER_UP = 0x701;
    var FINGER_MOTION = 0x702;
    var FINGER_CANCELED = 0x703;
}

@:enum
abstract SDL_ClipboardEventType(UInt) from UInt to UInt {
    var CLIPBOARD_UPDATE = 0x900;
}

@:enum
abstract SDL_DropEventType(UInt) from UInt to UInt {
    var DROP_FILE = 0x1000;
    var DROP_TEXT = 0x1001;
    var DROP_BEGIN = 0x1002;
    var DROP_COMPLETE = 0x1003;
    var DROP_POSITION = 0x1004;
}

@:enum
abstract SDL_AudioEventType(UInt) from UInt to UInt {
    var AUDIO_DEVICE_ADDED = 0x1100;
    var AUDIO_DEVICE_REMOVED = 0x1101;
    var AUDIO_DEVICE_FORMAT_CHANGED = 0x1102;
}

@:enum
abstract SDL_SensorEventType(UInt) from UInt to UInt {
    var SENSOR_UPDATE = 0x1200;
}

@:enum
abstract SDL_PenEventType(UInt) from UInt to UInt {
    var PEN_PROXIMITY_IN = 0x1300;
    var PEN_PROXIMITY_OUT = 0x1301;
    var PEN_DOWN = 0x1302;
    var PEN_UP = 0x1303;
    var PEN_BUTTON_DOWN = 0x1304;
    var PEN_BUTTON_UP = 0x1305;
    var PEN_MOTION = 0x1306;
    var PEN_AXIS = 0x1307;
}

@:enum
abstract SDL_CameraEventType(UInt) from UInt to UInt {
    var CAMERA_DEVICE_ADDED = 0x1400;
    var CAMERA_DEVICE_REMOVED = 0x1401;
    var CAMERA_DEVICE_APPROVED = 0x1402;
    var CAMERA_DEVICE_DENIED = 0x1403;
}

@:enum
abstract SDL_RenderEventType(UInt) from UInt to UInt {
    var RENDER_TARGETS_RESET = 0x2000;
    var RENDER_DEVICE_RESET = 0x2001;
    var RENDER_DEVICE_LOST = 0x2002;
}

@:enum
abstract SDL_InternalEventType(UInt) from UInt to UInt {
    var POLL_SENTINEL = 0x7F00;
}

@:enum
abstract SDL_UserEventType(UInt) from UInt to UInt {
    var USER = 0x8000;
}

typedef PtrEvent = Pointer<Event>;
typedef CreateWindowFlag = Int;
typedef SDL_EventType = UInt;
typedef SDL_KeyMod = UInt16;
typedef SDL_TouchID = UInt64;
typedef SDL_FingerID = UInt64;

abstract InitFlag(UInt64) {
    @:op(A|B) static function _(a:InitFlag, b:InitFlag):InitFlag;
}

// abstract CreateWindowFlag(Int) {
//     @:op(A|B) static function _(a:CreateWindowFlag, b:CreateWindowFlag):CreateWindowFlag;
// }

abstract SDL_GLAttr(UInt32) {
    @:op(A|B) static function _(a:SDL_GLAttr, b:SDL_GLAttr):SDL_GLAttr;
}

abstract SDL_LogPriority(UInt32) {
    @:op(A|B) static function _(a:SDL_LogPriority, b:SDL_LogPriority):SDL_LogPriority;
}

// abstract SDL_EventType(UInt32) {
//     @:op(A|B) static function _(a:SDL_EventType, b:SDL_EventType):SDL_EventType;
// }

abstract SDL_Folder(UInt32) {
    @:op(A|B) static function _(a:SDL_Folder, b:SDL_Folder):SDL_Folder;
}

