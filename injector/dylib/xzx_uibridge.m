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
    const char *luaScript =
    "if not game:IsLoaded() then game.Loaded:Wait() end\n"
    "local Players = game:GetService('Players')\n"
    "local player = Players.LocalPlayer\n"
    "if not player then Players.PlayerAdded:Wait() end\n"
    "if not player.Character then player.CharacterAdded:Wait() end\n"
    "task.wait(1)\n"
    "local CoreGui = game:GetService('CoreGui')\n"
    "if not CoreGui then return end\n"
    "\n"
    "-- Destroy any existing instance first\n"
    "local existing = CoreGui:FindFirstChild('XZX_ExecutorUI')\n"
    "if existing then existing:Destroy() end\n"
    "\n"
    "local screenGui = Instance.new('ScreenGui')\n"
    "screenGui.Name = 'XZX_ExecutorUI'\n"
    "screenGui.ResetOnSpawn = false\n"
    "screenGui.DisplayOrder = 1000\n"
    "screenGui.Parent = CoreGui\n"
    "\n"
    "-- Main frame\n"
    "local frame = Instance.new('Frame')\n"
    "frame.Size = UDim2.new(0, 300, 0, 220)\n"
    "frame.Position = UDim2.new(0.5, -150, 0.5, -110)\n"
    "frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)\n"
    "frame.BorderSizePixel = 0\n"
    "frame.Parent = screenGui\n"
    "\n"
    "local corner = Instance.new('UICorner')\n"
    "corner.CornerRadius = UDim.new(0, 10)\n"
    "corner.Parent = frame\n"
    "\n"
    "-- Title bar\n"
    "local titleBar = Instance.new('Frame')\n"
    "titleBar.Size = UDim2.new(1, 0, 0, 28)\n"
    "titleBar.BackgroundColor3 = Color3.fromRGB(166, 89, 255)\n"
    "titleBar.BorderSizePixel = 0\n"
    "titleBar.Parent = frame\n"
    "\n"
    "local titleCorner = Instance.new('UICorner')\n"
    "titleCorner.CornerRadius = UDim.new(0, 10)\n"
    "titleCorner.Parent = titleBar\n"
    "\n"
    "local title = Instance.new('TextLabel')\n"
    "title.Text = 'XZX Executor'\n"
    "title.Size = UDim2.new(1, -50, 1, 0)\n"
    "title.Position = UDim2.new(0, 10, 0, 0)\n"
    "title.BackgroundTransparency = 1\n"
    "title.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
    "title.TextXAlignment = Enum.TextXAlignment.Left\n"
    "title.Font = Enum.Font.GothamBold\n"
    "title.TextSize = 13\n"
    "title.Parent = titleBar\n"
    "\n"
    "-- Close button\n"
    "local closeBtn = Instance.new('TextButton')\n"
    "closeBtn.Size = UDim2.new(0, 28, 1, 0)\n"
    "closeBtn.Position = UDim2.new(1, -28, 0, 0)\n"
    "closeBtn.Text = 'X'\n"
    "closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
    "closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)\n"
    "closeBtn.BorderSizePixel = 0\n"
    "closeBtn.Font = Enum.Font.GothamBold\n"
    "closeBtn.TextSize = 12\n"
    "closeBtn.Parent = titleBar\n"
    "\n"
    "-- Script TextBox\n"
    "local textBox = Instance.new('TextBox')\n"
    "textBox.Size = UDim2.new(1, -16, 1, -70)\n"
    "textBox.Position = UDim2.new(0, 8, 0, 36)\n"
    "textBox.BackgroundColor3 = Color3.fromRGB(15, 15, 25)\n"
    "textBox.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
    "textBox.TextWrapped = true\n"
    "textBox.TextScaled = false\n"
    "textBox.MultiLine = true\n"
    "textBox.ClearTextOnFocus = false\n"
    "textBox.PlaceholderText = 'Enter Lua script...'\n"
    "textBox.Font = Enum.Font.Code\n"
    "textBox.TextSize = 12\n"
    "textBox.TextXAlignment = Enum.TextXAlignment.Left\n"
    "textBox.TextYAlignment = Enum.TextYAlignment.Top\n"
    "textBox.BorderSizePixel = 0\n"
    "textBox.Parent = frame\n"
    "\n"
    "local tbCorner = Instance.new('UICorner')\n"
    "tbCorner.CornerRadius = UDim.new(0, 6)\n"
    "tbCorner.Parent = textBox\n"
    "\n"
    "-- Execute button\n"
    "local execBtn = Instance.new('TextButton')\n"
    "execBtn.Size = UDim2.new(0, 90, 0, 28)\n"
    "execBtn.Position = UDim2.new(0.5, -45, 1, -34)\n"
    "execBtn.Text = 'Execute'\n"
    "execBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)\n"
    "execBtn.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
    "execBtn.Font = Enum.Font.GothamBold\n"
    "execBtn.TextSize = 12\n"
    "execBtn.BorderSizePixel = 0\n"
    "execBtn.Parent = frame\n"
    "\n"
    "local exCorner = Instance.new('UICorner')\n"
    "exCorner.CornerRadius = UDim.new(0, 8)\n"
    "exCorner.Parent = execBtn\n"
    "\n"
    "-- Resize handle\n"
    "local resizeHandle = Instance.new('Frame')\n"
    "resizeHandle.Size = UDim2.new(0, 14, 0, 14)\n"
    "resizeHandle.Position = UDim2.new(1, -14, 1, -14)\n"
    "resizeHandle.BackgroundColor3 = Color3.fromRGB(120, 80, 200)\n"
    "resizeHandle.BorderSizePixel = 0\n"
    "resizeHandle.Parent = frame\n"
    "\n"
    "-- Drag logic\n"
    "local dragging, dragStart, startPos = false, nil, nil\n"
    "titleBar.InputBegan:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 or\n"
    "       input.UserInputType == Enum.UserInputType.Touch then\n"
    "        dragging = true\n"
    "        dragStart = input.Position\n"
    "        startPos  = frame.Position\n"
    "    end\n"
    "end)\n"
    "titleBar.InputEnded:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 or\n"
    "       input.UserInputType == Enum.UserInputType.Touch then\n"
    "        dragging = false\n"
    "    end\n"
    "end)\n"
    "game:GetService('UserInputService').InputChanged:Connect(function(input)\n"
    "    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or\n"
    "       input.UserInputType == Enum.UserInputType.Touch) then\n"
    "        local delta = input.Position - dragStart\n"
    "        frame.Position = UDim2.new(\n"
    "            startPos.X.Scale, startPos.X.Offset + delta.X,\n"
    "            startPos.Y.Scale, startPos.Y.Offset + delta.Y)\n"
    "    end\n"
    "end)\n"
    "\n"
    "-- Resize logic\n"
    "local resizing, resizeStart, startSize = false, nil, nil\n"
    "resizeHandle.InputBegan:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 or\n"
    "       input.UserInputType == Enum.UserInputType.Touch then\n"
    "        resizing    = true\n"
    "        resizeStart = input.Position\n"
    "        startSize   = frame.Size\n"
    "    end\n"
    "end)\n"
    "resizeHandle.InputEnded:Connect(function(input)\n"
    "    if input.UserInputType == Enum.UserInputType.MouseButton1 or\n"
    "       input.UserInputType == Enum.UserInputType.Touch then\n"
    "        resizing = false\n"
    "    end\n"
    "end)\n"
    "game:GetService('UserInputService').InputChanged:Connect(function(input)\n"
    "    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or\n"
    "       input.UserInputType == Enum.UserInputType.Touch) then\n"
    "        local delta = input.Position - resizeStart\n"
    "        local w = math.max(220, startSize.X.Offset + delta.X)\n"
    "        local h = math.max(160, startSize.Y.Offset + delta.Y)\n"
    "        frame.Size = UDim2.new(0, w, 0, h)\n"
    "    end\n"
    "end)\n"
    "\n"
    "-- Close\n"
    "closeBtn.MouseButton1Click:Connect(function()\n"
    "    screenGui:Destroy()\n"
    "end)\n"
    "\n"
    "-- Execute\n"
    "local remote = Instance.new('RemoteEvent')\n"
    "remote.Name = 'XZX_ExecutorBridge'\n"
    "remote.Parent = screenGui\n"
    "execBtn.MouseButton1Click:Connect(function()\n"
    "    remote:FireServer(textBox.Text)\n"
    "end)\n"
    "\n"
    "-- Persistence: re-parent if game strips the GUI\n"
    "local RS = game:GetService('RunService')\n"
    "RS.Heartbeat:Connect(function()\n"
    "    if screenGui and not screenGui.Parent then\n"
    "        pcall(function() screenGui.Parent = CoreGui end)\n"
    "    end\n"
    "end)\n"
    "\n"
    "print('[XZX] In-game UI created')\n";

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
    const char *lua = "local g = game.CoreGui:FindFirstChild('XZX_ExecutorUI'); if g then g:Destroy() end";
    [self runLuaScriptInRoblox:lua];
}

- (void)showUI {
    const char *lua = "local g = game.CoreGui:FindFirstChild('XZX_ExecutorUI'); if g then g.Enabled = true end";
    [self runLuaScriptInRoblox:lua];
}

- (void)hideUI {
    const char *lua = "local g = game.CoreGui:FindFirstChild('XZX_ExecutorUI'); if g then g.Enabled = false end";
    [self runLuaScriptInRoblox:lua];
}

- (void)onScriptSubmitted:(NSString *)script {
    ExecuteScript([script UTF8String]);
}

@end
