#import <Foundation/Foundation.h>
#include <lua.h>
#include <lauxlib.h>
#include "LuaExecutor.h"

static lua_State *L = nil;

static int xzx_print(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *output = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        if (i > 1) [output appendString:@" "];
        if (lua_isstring(L, i)) {
            [output appendFormat:@"%s", lua_tostring(L, i)];
        } else if (lua_isnumber(L, i)) {
            [output appendFormat:@"%g", lua_tonumber(L, i)];
        } else if (lua_isboolean(L, i)) {
            [output appendString:(lua_toboolean(L, i) ? @"true" : @"false")];
        } else {
            [output appendString:@"nil"];
        }
    }
    NSLog(@"[XZX] %@", output);
    return 0;
}

void InitLua(void) {
    if (!L) {
        L = luaL_newstate();
        if (L) {
            lua_register(L, "print", xzx_print);
            NSLog(@"[XZX] Lua initialized");
        } else {
            NSLog(@"[XZX] Failed to create Lua state");
        }
    }
}

void ExecuteScript(const char *script) {
    if (!L) {
        InitLua();
    }
    if (L && script && strlen(script) > 0) {
        int status = luaL_dostring(L, script);
        if (status != 0) {
            const char *error = lua_tostring(L, -1);
            NSLog(@"[XZX] Error: %s", error);
            lua_pop(L, 1);
        }
    }
}
