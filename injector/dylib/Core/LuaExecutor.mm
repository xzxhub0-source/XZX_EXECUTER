#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include "LuaExecutor.h"

static lua_State *L = nil;

static int xzx_print(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *output = [NSMutableString string];
    
    for (int i = 1; i <= n; i++) {
        if (lua_isstring(L, i)) {
            if (i > 1) [output appendString:@"\t"];
            [output appendFormat:@"%s", lua_tostring(L, i)];
        }
    }
    
    NSLog(@"[XZX] %@", output);
    return 0;
}

static int xzx_getscript(lua_State *L) {
    const char *url = luaL_checkstring(L, 1);
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *result = nil;
    
    NSURL *nsUrl = [NSURL URLWithString:[NSString stringWithUTF8String:url]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithURL:nsUrl completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC));
    
    if (result) {
        lua_pushstring(L, [result UTF8String]);
    } else {
        lua_pushnil(L);
    }
    
    return 1;
}

void InitLua(void) {
    if (!L) {
        L = luaL_newstate();
        luaL_openlibs(L);
        
        lua_register(L, "print", xzx_print);
        lua_register(L, "getscript", xzx_getscript);
        
        luaL_dostring(L, "xzx = { version = '2.0.0' }");
    }
}

void ExecuteScript(const char *script) {
    if (!L) InitLua();
    
    int status = luaL_dostring(L, script);
    
    if (status != LUA_OK) {
        const char *error = lua_tostring(L, -1);
        NSLog(@"[XZX] Lua Error: %s", error);
        lua_pop(L, 1);
    }
}
