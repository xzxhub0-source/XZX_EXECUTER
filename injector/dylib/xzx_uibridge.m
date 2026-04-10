#import "xzx_uibridge.h"
#import "xzx_hooks.h"
#import "Core/LuaExecutor.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation XZXUIBridge

+ (instancetype)shared {
    static XZXUIBridge *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ instance = [[self alloc] init]; });
    return instance;
}

// Inject Lua code that creates a ScreenGui inside game.CoreGui
- (void)createInGameUI {
    // This Lua script will be executed inside Roblox's Lua VM
    const char *luaScript =
    "if not game:IsLoaded() then game.Loaded:Wait() end\n"
    "local CoreGui = game:GetService('CoreGui')\n"
    "if not CoreGui then return end\n"
    "local screenGui = Instance.new('ScreenGui')\n"
    "screenGui.Name = 'XZX_ExecutorUI'\n"
    "screenGui.ResetOnSpawn = false\n"
    "screenGui.Parent = CoreGui\n"
    "\n"
    "-- Main frame\n"
    "local frame = Instance.new('Frame')\n"
    "frame.Size = UDim2.new(0, 400, 0, 300)\n"
    "frame.Position = UDim2.new(0.5, -200, 0.5, -150)\n"
    "frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)\n"
    "frame.BorderSizePixel = 0\n"
    "frame.Parent = screenGui\n"
    "\n"
    "-- Title bar (draggable)\n"
    "local titleBar = Instance.new('Frame')\n"
    "titleBar.Size = UDim2.new(1, 0, 0, 30)\n"
    "titleBar.BackgroundColor3 = Color3.fromRGB(166, 89, 255)\n"
    "titleBar.Parent = frame\n"
    "\n"
    "local title = Instance.new('TextLabel')\n"
    "title.Text = 'XZX Executor'\n"
    "title.Size = UDim2.new(1, -60, 1, 0)\n"
    "title.BackgroundTransparency = 1\n"
    "title.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "title.TextXAlignment = Enum.TextXAlignment.Left\n"
    "title.Parent = titleBar\n"
    "\n"
    "-- Close button\n"
    "local closeBtn = Instance.new('TextButton')\n"
    "closeBtn.Size = UDim2.new(0, 30, 1, 0)\n"
    "closeBtn.Position = UDim2.new(1, -30, 0, 0)\n"
    "closeBtn.Text = 'X'\n"
    "closeBtn.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)\n"
    "closeBtn.Parent = titleBar\n"
    "\n"
    "-- Script input (TextBox)\n"
    "local textBox = Instance.new('TextBox')\n"
    "textBox.Size = UDim2.new(1, -20, 1, -60)\n"
    "textBox.Position = UDim2.new(0, 10, 0, 40)\n"
    "textBox.BackgroundColor3 = Color3.fromRGB(15, 15, 25)\n"
    "textBox.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "textBox.TextWrapped = true\n"
    "textBox.TextScaled = false\n"
    "textBox.MultiLine = true\n"
    "textBox.ClearTextOnFocus = false\n"
    "textBox.PlaceholderText = 'Enter your Lua script here...'\n"
    "textBox.Parent = frame\n"
    "\n"
    "-- Execute button\n"
    "local execBtn = Instance.new('TextButton')\n"
    "execBtn.Size = UDim2.new(0, 100, 0, 30)\n"
    "execBtn.Position = UDim2.new(0.5, -50, 1, -40)\n"
    "execBtn.Text = 'Execute'\n"
    "execBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)\n"
    "execBtn.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "execBtn.Parent = frame\n"
    "\n"
    "-- Make frame draggable\n"
    "local dragging = false\n"
    "local dragStart\n"
    "local startPos\n"
    "titleBar.InputBegan:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 then\n"
    "        dragging = true\n"
    "        dragStart = input.Position\n"
    "        startPos = frame.Position\n"
    "    end\n"
    "end)\n"
    "titleBar.InputEnded:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 then\n"
    "        dragging = false\n"
    "    end\n"
    "end)\n"
    "titleBar.InputChanged:Connect(function(input)\n"
    "    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then\n"
    "        local delta = input.Position - dragStart\n"
    "        frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)\n"
    "    end\n"
    "end)\n"
    "\n"
    "-- Close button action\n"
    "closeBtn.MouseButton1Click:Connect(function()\n"
    "    screenGui:Destroy()\n"
    "end)\n"
    "\n"
    "-- Execute button action: send script to dylib via a custom RemoteEvent\n"
    "-- We'll create a hidden RemoteEvent that the dylib listens to\n"
    "local remote = Instance.new('RemoteEvent')\n"
    "remote.Name = 'XZX_ExecutorBridge'\n"
    "remote.Parent = screenGui\n"
    "execBtn.MouseButton1Click:Connect(function()\n"
    "    remote:FireServer(textBox.Text)\n"
    "end)\n"
    "\n"
    "-- Keep UI visible even when game loads new places\n"
    "screenGui.Parent = CoreGui\n"
    "print('[XZX] In-game UI created')\n";

    // Execute this Lua script inside Roblox's Lua state
    // We need to run it in the context of Roblox's main Lua VM
    // The typical way is to use luaL_dostring on a Lua state that has Roblox globals
    // Since we have a hook into Roblox's Lua state (e.g., through our hooks), we'll use a helper.
    [self runLuaScriptInRoblox:luaScript];
}

- (void)runLuaScriptInRoblox:(const char *)script {
    // Find Roblox's Lua state – this is the tricky part.
    // Many executors hook a function that is called every frame (like `RenderStep`) to get a Lua state.
    // For simplicity, we'll assume we have a function `getRobloxLuaState()` from our hooks.
    // We'll implement that in xzx_hooks.m.
    lua_State *L = getRobloxLuaState();
    if (L) {
        if (luaL_dostring(L, script) != LUA_OK) {
            const char *err = lua_tostring(L, -1);
            NSLog(@"[XZX] Failed to inject UI: %s", err);
            lua_pop(L, 1);
        } else {
            NSLog(@"[XZX] In-game UI injected successfully");
        }
    } else {
        NSLog(@"[XZX] Could not get Roblox Lua state");
    }
}

- (void)destroyInGameUI {
    const char *luaScript = "local gui = game.CoreGui:FindFirstChild('XZX_ExecutorUI'); if gui then gui:Destroy() end";
    [self runLuaScriptInRoblox:luaScript];
}

- (void)showUI {
    const char *luaScript = "local gui = game.CoreGui:FindFirstChild('XZX_ExecutorUI'); if gui then gui.Enabled = true end";
    [self runLuaScriptInRoblox:luaScript];
}

- (void)hideUI {
    const char *luaScript = "local gui = game.CoreGui:FindFirstChild('XZX_ExecutorUI'); if gui then gui.Enabled = false end";
    [self runLuaScriptInRoblox:luaScript];
}

- (void)onScriptSubmitted:(NSString *)script {
    // Called when the UI's RemoteEvent fires.
    // Execute the script in our own Lua state (which can run unsafe code).
    ExecuteScript([script UTF8String]);
}

@end
