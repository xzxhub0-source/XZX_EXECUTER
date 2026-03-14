#import "LuaExecutor.h"
#import <UIKit/UIKit.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

static lua_State *L = nil;

static int xzx_print(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *output = [NSMutableString string];
    
    for (int i = 1; i <= n; i++) {
        if (lua_isstring(L, i)) {
            if (i > 1) [output appendString:@" "];
            [output appendFormat:@"%s", lua_tostring(L, i)];
        } else if (lua_isnumber(L, i)) {
            [output appendFormat:@"%g", lua_tonumber(L, i)];
        } else if (lua_isboolean(L, i)) {
            [output appendString:lua_toboolean(L, i) ? "true" : "false"];
        } else if (lua_istable(L, i)) {
            [output appendString:@"table"];
        } else if (lua_isfunction(L, i)) {
            [output appendString:@"function"];
        } else {
            [output appendString:@"nil"];
        }
    }
    
    NSLog(@"[XZX] %@", output);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXPrint" 
                                                            object:output];
    });
    
    return 0;
}

static int xzx_warn(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *output = [NSMutableString string];
    
    for (int i = 1; i <= n; i++) {
        if (i > 1) [output appendString:@" "];
        [output appendFormat:@"%s", lua_tostring(L, i)];
    }
    
    NSLog(@"[XZX WARN] %@", output);
    return 0;
}

static int xzx_getscript(lua_State *L) {
    const char *url = luaL_checkstring(L, 1);
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *result = nil;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]];
    [request setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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

static int xzx_loadstring(lua_State *L) {
    const char *code = luaL_checkstring(L, 1);
    
    int status = luaL_loadstring(L, code);
    
    if (status != 0) {
        lua_pushnil(L);
        lua_pushstring(L, lua_tostring(L, -1));
        return 2;
    }
    
    return 1;
}

static int xzx_base64_encode(lua_State *L) {
    const char *data = luaL_checkstring(L, 1);
    NSData *nsdata = [NSData dataWithBytes:data length:strlen(data)];
    NSString *encoded = [nsdata base64EncodedStringWithOptions:0];
    lua_pushstring(L, [encoded UTF8String]);
    return 1;
}

static int xzx_base64_decode(lua_State *L) {
    const char *data = luaL_checkstring(L, 1);
    NSData *nsdata = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:data] options:0];
    NSString *decoded = [[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding];
    lua_pushstring(L, [decoded UTF8String]);
    return 1;
}

static int xzx_base64codes(lua_State *L) {
    const char *input = luaL_checkstring(L, 1);
    NSData *data = [NSData dataWithBytes:input length:strlen(input)];
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
    NSString *result = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
    lua_pushstring(L, [result UTF8String]);
    return 1;
}

static int xzx_identifyexecutor(lua_State *L) {
    lua_pushstring(L, "XZX");
    return 1;
}

static int xzx_getexecutorname(lua_State *L) {
    lua_pushstring(L, "XZX");
    return 1;
}

static int xzx_checkcaller(lua_State *L) {
    lua_pushboolean(L, 1);
    return 1;
}

static int xzx_getgenv(lua_State *L) {
    lua_pushvalue(L, LUA_GLOBALSINDEX);
    return 1;
}

static int xzx_getreg(lua_State *L) {
    lua_pushvalue(L, LUA_REGISTRYINDEX);
    return 1;
}

static int xzx_getgc(lua_State *L) {
    lua_newtable(L);
    lua_pushvalue(L, LUA_REGISTRYINDEX);
    lua_pushnil(L);
    while (lua_next(L, -2) != 0) {
        lua_pushvalue(L, -2);
        int type = lua_type(L, -2);
        if (type == LUA_TFUNCTION || type == LUA_TTABLE || type == LUA_TUSERDATA) {
            lua_pushinteger(L, lua_rawlen(L, -4) + 1);
            lua_pushvalue(L, -3);
            lua_settable(L, -6);
        }
        lua_pop(L, 2);
    }
    lua_pop(L, 1);
    return 1;
}

static int xzx_isrbxactive(lua_State *L) {
    lua_pushboolean(L, 1);
    return 1;
}

static int xzx_getthreadidentity(lua_State *L) {
    lua_pushinteger(L, 8);
    return 1;
}

static int xzx_setthreadidentity(lua_State *L) {
    return 0;
}

static int xzx_fireclickdetector(lua_State *L) {
    return 0;
}

static int xzx_firetouchinterest(lua_State *L) {
    return 0;
}

void InitLua(void) {
    if (!L) {
        L = luaL_newstate();
        luaL_openlibs(L);
        RegisterXZXFunctions();
    }
}

void RegisterXZXFunctions(void) {
    lua_register(L, "print", xzx_print);
    lua_register(L, "warn", xzx_warn);
    lua_register(L, "getscript", xzx_getscript);
    lua_register(L, "loadstring", xzx_loadstring);
    lua_register(L, "base64_encode", xzx_base64_encode);
    lua_register(L, "base64_decode", xzx_base64_decode);
    lua_register(L, "base64codes", xzx_base64codes);
    lua_register(L, "identifyexecutor", xzx_identifyexecutor);
    lua_register(L, "getexecutorname", xzx_getexecutorname);
    lua_register(L, "checkcaller", xzx_checkcaller);
    lua_register(L, "getgenv", xzx_getgenv);
    lua_register(L, "getreg", xzx_getreg);
    lua_register(L, "getgc", xzx_getgc);
    lua_register(L, "isrbxactive", xzx_isrbxactive);
    lua_register(L, "getthreadidentity", xzx_getthreadidentity);
    lua_register(L, "setthreadidentity", xzx_setthreadidentity);
    lua_register(L, "fireclickdetector", xzx_fireclickdetector);
    lua_register(L, "firetouchinterest", xzx_firetouchinterest);
    
    luaL_dostring(L, 
        "xzx = {"
        "  version = '3.0.0',"
        "  unc = 95,"
        "  sunc = 90"
        "}"
    );
}

void ExecuteScript(NSString *script) {
    if (!L) InitLua();
    
    int status = luaL_dostring(L, [script UTF8String]);
    
    if (status != LUA_OK) {
        const char *error = lua_tostring(L, -1);
        NSLog(@"[XZX] Lua Error: %s", error);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXError" 
                                                                object:[NSString stringWithUTF8String:error]];
        });
        
        lua_pop(L, 1);
    }
}
