#import "xzx_hooks.h"
#import "xzx_uibridge.h"
#import "Core/LuaExecutor.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>

static lua_State *robloxLuaState = NULL;
static void *original_methods[128];
static int method_count = 0;
static uintptr_t roblox_base = 0;
static BOOL hooks_active = NO;

// THIS IS THE ROOT CAUSE — function was declared in the header but had
// zero implementation in xzx_hooks.m. Calling an undefined function
// returns garbage that the monitor treats as truthy, so the UI fires
// immediately on every launch regardless of whether you're in a game.
bool isPlayerInGame(void) {
    @try {
        NSArray *classNames = @[
            @"RBXDataModel",
            @"RobloxDataModel",
            @"DataModel",
            @"RBXGame",
            @"RobloxGame"
        ];

        Class dmClass = nil;
        for (NSString *name in classNames) {
            dmClass = NSClassFromString(name);
            if (dmClass) break;
        }
        if (!dmClass) return false;

        NSArray *sharedSels = @[
            @"sharedDataModel",
            @"shared",
            @"singleton",
            @"instance"
        ];
        id dataModel = nil;
        for (NSString *selName in sharedSels) {
            SEL sel = NSSelectorFromString(selName);
            if ([dmClass respondsToSelector:sel]) {
                dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dmClass, sel);
                if (dataModel) break;
            }
        }
        if (!dataModel) return false;

        NSArray *placeIdSels = @[
            @"placeId",
            @"PlaceId",
            @"currentPlaceId",
            @"gameId"
        ];
        for (NSString *selName in placeIdSels) {
            SEL sel = NSSelectorFromString(selName);
            if ([dataModel respondsToSelector:sel]) {
                id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, sel);
                if (placeId && [placeId intValue] != 0) return true;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] isPlayerInGame error: %@", e);
    }
    return false;
}

void notify_game_joined(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[XZXUIBridge shared] createInGameUI];
        [[XZXUIBridge shared] showUI];
    });
}

void install_hook(void *target, void *replacement, void **original) {
    if (!target || !replacement) return;
    if (original) *original = target;
    original_methods[method_count++] = target;

    vm_address_t address = (vm_address_t)target;
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    uint32_t branch = 0x14000000 |
        (((uint32_t)((uintptr_t)replacement - (uintptr_t)target) >> 2) & 0x03FFFFFF);
    memcpy(target, &branch, 4);
    __builtin___clear_cache((char *)target, (char *)target + 4);

    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
               VM_PROT_READ | VM_PROT_EXECUTE);
}

void hook_roblox_functions(void) {
    if (hooks_active) return;
    hooks_active = YES;
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
}

void unhook_roblox_functions(void) { hooks_active = NO; }

lua_State *getRobloxLuaState(void) {
    @try {
        Class scriptContextClass = NSClassFromString(@"RBXScriptContext");
        if (scriptContextClass) {
            SEL sharedSel = NSSelectorFromString(@"sharedContext");
            if ([scriptContextClass respondsToSelector:sharedSel]) {
                id context = ((id(*)(id, SEL))objc_msgSend)((id)scriptContextClass, sharedSel);
                if (context) {
                    SEL luaStateSel = NSSelectorFromString(@"luaState");
                    if ([context respondsToSelector:luaStateSel]) {
                        void *state = ((void*(*)(id, SEL))objc_msgSend)(context, luaStateSel);
                        if (state) {
                            robloxLuaState = (lua_State *)state;
                            return robloxLuaState;
                        }
                    }
                }
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] getRobloxLuaState error: %@", e);
    }
    return robloxLuaState;
}

void setupRemoteEventBridge(void) {
    const char *luaScript =
        "local remote = game.CoreGui:FindFirstChild('XZX_ExecutorUI')"
        "               :FindFirstChild('XZX_ExecutorBridge')\n"
        "if remote then\n"
        "    remote.OnServerEvent:Connect(function(player, scriptText)\n"
        "        if _G.xzx_execute_script then\n"
        "            _G.xzx_execute_script(scriptText)\n"
        "        end\n"
        "    end)\n"
        "end\n";

    lua_State *L = getRobloxLuaState();
    if (!L) return;

    lua_register(L, "xzx_execute_script_c", [](lua_State *L) -> int {
        const char *script = luaL_checkstring(L, 1);
        [[XZXUIBridge shared] onScriptSubmitted:[NSString stringWithUTF8String:script]];
        return 0;
    });
    lua_getglobal(L, "xzx_execute_script_c");
    lua_setglobal(L, "xzx_execute_script");

    if (luaL_dostring(L, luaScript) != LUA_OK) {
        NSLog(@"[XZX] Bridge setup failed: %s", lua_tostring(L, -1));
        lua_pop(L, 1);
    } else {
        NSLog(@"[XZX] RemoteEvent bridge established");
    }
}
