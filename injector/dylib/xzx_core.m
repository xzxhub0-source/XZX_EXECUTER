#import "xzx_core.h"
#import "xzx_editor.h"
#import "xzx_hooks.h"
#import "xzx_security.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

static XZXCore *sharedCoreInstance = nil;
static uintptr_t roblox_base = 0;
static uintptr_t script_context_ptr = 0;
static lua_State* roblox_lua_state = NULL;
static BOOL is_initialized = NO;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCoreInstance = [[self alloc] init];
    });
    return sharedCoreInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInGame = NO;
        _editorWindow = nil;
    }
    return self;
}

+ (void)load {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 
                   dispatch_get_main_queue(), ^{
        [[XZXCore shared] initialize];
    });
}

- (void)initialize {
    [[XZXSecurity shared] applyBypasses];
    [self scanRobloxMemory];
    [self hookRobloxFunctions];
    [self startGameStateMonitoring];
    [self injectBootstrapScript];
}

- (void)scanRobloxMemory {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
}

- (void)hookRobloxFunctions {
    hook_roblox_functions();
}

- (lua_State*)getRobloxLuaState {
    if (roblox_lua_state) return roblox_lua_state;
    
    uintptr_t datamodel_ptr = 0;
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (dataModelClass && [dataModelClass respondsToSelector:@selector(sharedDataModel)]) {
        datamodel_ptr = (uintptr_t)[dataModelClass sharedDataModel];
    }
    
    if (!datamodel_ptr) return NULL;
    
    uintptr_t script_context = datamodel_ptr + 0x70;
    script_context_ptr = *(uintptr_t*)script_context;
    
    if (!script_context_ptr) return NULL;
    
    uintptr_t lua_state_addr = script_context_ptr + 0x48;
    roblox_lua_state = (lua_State*)*(uintptr_t*)lua_state_addr;
    
    return roblox_lua_state;
}

- (void)injectBootstrapScript {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        for (int i = 0; i < 50; i++) {
            lua_State* L = [self getRobloxLuaState];
            if (L) {
                [self executeInRobloxState:L];
                return;
            }
            usleep(100000);
        }
    });
}

- (void)executeInRobloxState:(lua_State*)L {
    if (!L) return;
    
    int old_identity = [self getThreadIdentity:L];
    [self setThreadIdentity:L identity:8];
    
    NSString* bootstrapCode = [NSString stringWithFormat:
        @"task.spawn(function()\n"
        @"    local success, result = pcall(function()\n"
        @"        local gui = Instance.new('ScreenGui')\n"
        @"        gui.Name = 'XZX_Executor'\n"
        @"        gui.Parent = game:GetService('CoreGui')\n"
        @"        gui.ResetOnSpawn = false\n"
        @"        gui.Enabled = true\n"
        @"        \n"
        @"        local frame = Instance.new('Frame')\n"
        @"        frame.Size = UDim2.new(0, 400, 0, 500)\n"
        @"        frame.Position = UDim2.new(0.5, -200, 0.5, -250)\n"
        @"        frame.BackgroundColor3 = Color3.fromRGB(20, 20, 30)\n"
        @"        frame.BorderSizePixel = 0\n"
        @"        frame.Parent = gui\n"
        @"        \n"
        @"        local title = Instance.new('TextLabel')\n"
        @"        title.Size = UDim2.new(1, 0, 0, 40)\n"
        @"        title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)\n"
        @"        title.Text = 'XZX Executor'\n"
        @"        title.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
        @"        title.Font = Enum.Font.GothamBold\n"
        @"        title.TextSize = 20\n"
        @"        title.Parent = frame\n"
        @"        \n"
        @"        local scriptBox = Instance.new('TextBox')\n"
        @"        scriptBox.Size = UDim2.new(1, -20, 1, -90)\n"
        @"        scriptBox.Position = UDim2.new(0, 10, 0, 50)\n"
        @"        scriptBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)\n"
        @"        scriptBox.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
        @"        scriptBox.PlaceholderText = '-- Enter your script here'\n"
        @"        scriptBox.TextXAlignment = Enum.TextXAlignment.Left\n"
        @"        scriptBox.TextYAlignment = Enum.TextYAlignment.Top\n"
        @"        scriptBox.MultiLine = true\n"
        @"        scriptBox.ClearTextOnFocus = false\n"
        @"        scriptBox.Font = Enum.Font.Code\n"
        @"        scriptBox.TextSize = 14\n"
        @"        scriptBox.Parent = frame\n"
        @"        \n"
        @"        local execute = Instance.new('TextButton')\n"
        @"        execute.Size = UDim2.new(0.5, -5, 0, 30)\n"
        @"        execute.Position = UDim2.new(0, 10, 1, -40)\n"
        @"        execute.BackgroundColor3 = Color3.fromRGB(0, 255, 0)\n"
        @"        execute.Text = 'Execute'\n"
        @"        execute.TextColor3 = Color3.fromRGB(0, 0, 0)\n"
        @"        execute.Font = Enum.Font.GothamBold\n"
        @"        execute.TextSize = 16\n"
        @"        execute.Parent = frame\n"
        @"        \n"
        @"        local clear = Instance.new('TextButton')\n"
        @"        clear.Size = UDim2.new(0.5, -5, 0, 30)\n"
        @"        clear.Position = UDim2.new(0.5, 5, 1, -40)\n"
        @"        clear.BackgroundColor3 = Color3.fromRGB(255, 0, 0)\n"
        @"        clear.Text = 'Clear'\n"
        @"        clear.TextColor3 = Color3.fromRGB(255, 255, 255)\n"
        @"        clear.Font = Enum.Font.GothamBold\n"
        @"        clear.TextSize = 16\n"
        @"        clear.Parent = frame\n"
        @"        \n"
        @"        local drag = Instance.new('ImageButton')\n"
        @"        drag.Size = UDim2.new(1, 0, 0, 40)\n"
        @"        drag.BackgroundTransparency = 1\n"
        @"        drag.Parent = gui\n"
        @"        \n"
        @"        local dragging = false\n"
        @"        local dragStart = nil\n"
        @"        local framePos = nil\n"
        @"        \n"
        @"        drag.MouseButton1Down:Connect(function()\n"
        @"            dragging = true\n"
        @"            dragStart = game:GetService('UserInputService'):GetMouseLocation()\n"
        @"            framePos = frame.Position\n"
        @"        end)\n"
        @"        \n"
        @"        game:GetService('UserInputService').InputChanged:Connect(function(input)\n"
        @"            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then\n"
        @"                local delta = game:GetService('UserInputService'):GetMouseLocation() - dragStart\n"
        @"                frame.Position = UDim2.new(\n"
        @"                    framePos.X.Scale,\n"
        @"                    framePos.X.Offset + delta.X,\n"
        @"                    framePos.Y.Scale,\n"
        @"                    framePos.Y.Offset + delta.Y\n"
        @"                )\n"
        @"            end\n"
        @"        end)\n"
        @"        \n"
        @"        game:GetService('UserInputService').InputEnded:Connect(function(input)\n"
        @"            if input.UserInputType == Enum.UserInputType.MouseButton1 then\n"
        @"                dragging = false\n"
        @"            end\n"
        @"        end)\n"
        @"        \n"
        @"        execute.MouseButton1Click:Connect(function()\n"
        @"            local script = scriptBox.Text\n"
        @"            if script and #script > 0 then\n"
        @"                local f, err = loadstring(script)\n"
        @"                if f then\n"
        @"                    pcall(f)\n"
        @"                else\n"
        @"                    warn('XZX Error: ' .. tostring(err))\n"
        @"                end\n"
        @"            end\n"
        @"        end)\n"
        @"        \n"
        @"        clear.MouseButton1Click:Connect(function()\n"
        @"            scriptBox.Text = ''\n"
        @"        end)\n"
        @"        \n"
        @"        frame.Visible = true\n"
        @"    end)\n"
        @"    if not success then\n"
        @"        warn('XZX GUI Error: ' .. tostring(result))\n"
        @"    end\n"
        @"end)"];
    
    luaL_loadstring(L, [bootstrapCode UTF8String]);
    lua_pcall(L, 0, 0, 0);
    
    [self setThreadIdentity:L identity:old_identity];
}

- (int)getThreadIdentity:(lua_State*)L {
    lua_getfield(L, LUA_REGISTRYINDEX, "thread_identity");
    int identity = lua_tointeger(L, -1);
    lua_pop(L, 1);
    return identity ? identity : 0;
}

- (void)setThreadIdentity:(lua_State*)L identity:(int)identity {
    lua_pushinteger(L, identity);
    lua_setfield(L, LUA_REGISTRYINDEX, "thread_identity");
}

- (void)startGameStateMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        BOOL lastInGame = NO;
        
        while (YES) {
            BOOL currentlyInGame = [self checkIfInGame];
            
            if (currentlyInGame && !lastInGame) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGameJoined];
                });
            } else if (!currentlyInGame && lastInGame) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onGameLeft];
                });
            }
            
            lastInGame = currentlyInGame;
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)checkIfInGame {
    lua_State* L = [self getRobloxLuaState];
    if (!L) return NO;
    
    lua_getglobal(L, "game");
    if (lua_isnil(L, -1)) {
        lua_pop(L, 1);
        return NO;
    }
    
    lua_getfield(L, -1, "PlaceId");
    BOOL hasPlaceId = !lua_isnil(L, -1);
    lua_pop(L, 2);
    
    return hasPlaceId;
}

- (void)onGameJoined {
    if (self.isInGame) return;
    self.isInGame = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        lua_State* L = [self getRobloxLuaState];
        if (L) {
            [self executeInRobloxState:L];
        }
    });
}

- (void)onGameLeft {
    self.isInGame = NO;
}

void notify_game_joined(void) {
    [[XZXCore shared] onGameJoined];
}

void notify_game_left(void) {
    [[XZXCore shared] onGameLeft];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super dealloc];
}

@end
