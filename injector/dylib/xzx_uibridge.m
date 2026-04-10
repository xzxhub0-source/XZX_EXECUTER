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

- (void)createInGameUI {
    // Smaller UI (300x220) with resize handle
    const char *luaScript =
    "if not game:IsLoaded() then game.Loaded:Wait() end\n"
    "local CoreGui = game:GetService('CoreGui')\n"
    "if not CoreGui then return end\n"
    "local screenGui = Instance.new('ScreenGui')\n"
    "screenGui.Name = 'XZX_ExecutorUI'\n"
    "screenGui.ResetOnSpawn = false\n"
    "screenGui.Parent = CoreGui\n"
    "\n"
    "-- Main frame (smaller: 300x220)\n"
    "local frame = Instance.new('Frame')\n"
    "frame.Size = UDim2.new(0, 300, 0, 220)\n"
    "frame.Position = UDim2.new(0.5, -150, 0.5, -110)\n"
    "frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)\n"
    "frame.BorderSizePixel = 0\n"
    "frame.Parent = screenGui\n"
    "\n"
    "-- Title bar (draggable)\n"
    "local titleBar = Instance.new('Frame')\n"
    "titleBar.Size = UDim2.new(1, 0, 0, 28)\n"
    "titleBar.BackgroundColor3 = Color3.fromRGB(166, 89, 255)\n"
    "titleBar.Parent = frame\n"
    "\n"
    "local title = Instance.new('TextLabel')\n"
    "title.Text = 'XZX Executor'\n"
    "title.Size = UDim2.new(1, -50, 1, 0)\n"
    "title.BackgroundTransparency = 1\n"
    "title.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "title.TextXAlignment = Enum.TextXAlignment.Left\n"
    "title.Parent = titleBar\n"
    "\n"
    "-- Close button\n"
    "local closeBtn = Instance.new('TextButton')\n"
    "closeBtn.Size = UDim2.new(0, 28, 1, 0)\n"
    "closeBtn.Position = UDim2.new(1, -28, 0, 0)\n"
    "closeBtn.Text = 'X'\n"
    "closeBtn.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)\n"
    "closeBtn.Parent = titleBar\n"
    "\n"
    "-- Script input (TextBox) - smaller height\n"
    "local textBox = Instance.new('TextBox')\n"
    "textBox.Size = UDim2.new(1, -16, 1, -70)\n"
    "textBox.Position = UDim2.new(0, 8, 0, 36)\n"
    "textBox.BackgroundColor3 = Color3.fromRGB(15, 15, 25)\n"
    "textBox.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "textBox.TextWrapped = true\n"
    "textBox.TextScaled = false\n"
    "textBox.MultiLine = true\n"
    "textBox.ClearTextOnFocus = false\n"
    "textBox.PlaceholderText = 'Enter Lua script...'\n"
    "textBox.Parent = frame\n"
    "\n"
    "-- Execute button\n"
    "local execBtn = Instance.new('TextButton')\n"
    "execBtn.Size = UDim2.new(0, 80, 0, 28)\n"
    "execBtn.Position = UDim2.new(0.5, -40, 1, -34)\n"
    "execBtn.Text = 'Execute'\n"
    "execBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)\n"
    "execBtn.TextColor3 = Color3.fromRGB(255,255,255)\n"
    "execBtn.Parent = frame\n"
    "\n"
    "-- Resize handle (bottom-right corner)\n"
    "local resizeHandle = Instance.new('Frame')\n"
    "resizeHandle.Size = UDim2.new(0, 12, 0, 12)\n"
    "resizeHandle.Position = UDim2.new(1, -12, 1, -12)\n"
    "resizeHandle.BackgroundColor3 = Color3.fromRGB(100, 100, 120)\n"
    "resizeHandle.Parent = frame\n"
    "\n"
    "-- Dragging logic for title bar\n"
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
    "-- Resizing logic\n"
    "local resizing = false\n"
    "local resizeStartPos\n"
    "local startSize\n"
    "resizeHandle.InputBegan:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 then\n"
    "        resizing = true\n"
    "        resizeStartPos = input.Position\n"
    "        startSize = frame.Size\n"
    "    end\n"
    "end)\n"
    "resizeHandle.InputEnded:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 then\n"
    "        resizing = false\n"
    "    end\n"
    "end)\n"
    "resizeHandle.InputChanged:Connect(function(input)\n"
    "    if resizing and input.UserInputType == Enum.UserInputType.MouseMovement then\n"
    "        local delta = input.Position - resizeStartPos\n"
    "        local newWidth = math.max(200, startSize.X.Offset + delta.X)\n"
    "        local newHeight = math.max(150, startSize.Y.Offset + delta.Y)\n"
    "        frame.Size = UDim2.new(0, newWidth, 0, newHeight)\n"
    "        -- Keep text box size proportional\n"
    "        textBox.Size = UDim2.new(1, -16, 1, -70)\n"
    "        execBtn.Position = UDim2.new(0.5, -40, 1, -34)\n"
    "    end\n"
    "end)\n"
    "\n"
    "-- Close button action\n"
    "closeBtn.MouseButton1Click:Connect(function()\n"
    "    screenGui:Destroy()\n"
    "end)\n"
    "\n"
    "-- Execute button action\n"
    "local remote = Instance.new('RemoteEvent')\n"
    "remote.Name = 'XZX_ExecutorBridge'\n"
    "remote.Parent = screenGui\n"
    "execBtn.MouseButton1Click:Connect(function()\n"
    "    remote:FireServer(textBox.Text)\n"
    "end)\n"
    "\n"
    "screenGui.Parent = CoreGui\n"
    "print('[XZX] In-game UI created (300x220, resizable)')\n";

    [self runLuaScriptInRoblox:luaScript];
}

- (void)runLuaScriptInRoblox:(const char *)script {
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
    ExecuteScript([script UTF8String]);
}

@end
