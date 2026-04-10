// At the top, add static storage for Roblox Lua state
static lua_State *robloxLuaState = NULL;

// Find Roblox's main Lua state. 
// One reliable method: hook a function that is called with the Lua state as an argument,
// such as the function that executes scripts. For demonstration, we'll assume we have a known address.
lua_State* getRobloxLuaState(void) {
    // This is a placeholder. In a real executor, you would find the Lua state by:
    // - Hooking lua_newstate or luaL_newstate and capturing the returned state
    // - Or scanning memory for known patterns
    // For now, we'll try to retrieve it from the shared instance of the script context.
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
        NSLog(@"[XZX] Failed to get Roblox Lua state: %@", e);
    }
    return robloxLuaState;
}

// Hook the RemoteEvent's OnServerEvent to receive script submissions from our UI
void setupRemoteEventBridge(void) {
    const char *luaScript =
    "local remote = game.CoreGui:FindFirstChild('XZX_ExecutorUI'):FindFirstChild('XZX_ExecutorBridge')\n"
    "if remote then\n"
    "    remote.OnServerEvent:Connect(function(player, scriptText)\n"
    "        -- Call back into our dylib – we can use a custom C function registered in Lua\n"
    "        if _G.xzx_execute_script then\n"
    "            _G.xzx_execute_script(scriptText)\n"
    "        end\n"
    "    end)\n"
    "end\n";
    
    lua_State *L = getRobloxLuaState();
    if (L) {
        // Register a C function that our Lua can call to execute scripts
        lua_register(L, "xzx_execute_script_c", [](lua_State *L) -> int {
            const char *script = luaL_checkstring(L, 1);
            [[XZXUIBridge shared] onScriptSubmitted:[NSString stringWithUTF8String:script]];
            return 0;
        });
        // Make it available globally as _G.xzx_execute_script
        lua_getglobal(L, "xzx_execute_script_c");
        lua_setglobal(L, "xzx_execute_script");
        
        // Now run the setup script
        if (luaL_dostring(L, luaScript) != LUA_OK) {
            NSLog(@"[XZX] RemoteEvent bridge setup failed: %s", lua_tostring(L, -1));
            lua_pop(L, 1);
        } else {
            NSLog(@"[XZX] RemoteEvent bridge established");
        }
    }
}
