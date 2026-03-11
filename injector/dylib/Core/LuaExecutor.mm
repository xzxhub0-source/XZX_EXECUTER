cat > injector/dylib/Core/LuaExecutor.mm << 'EOF'
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <vector>
#include <string>
#include <map>
#include <mutex>
#include <thread>
#include "LuaExecutor.h"

static lua_State *L = nil;
static std::mutex lua_mutex;

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
        } else if (lua_istable(L, i)) {
            [output appendString:@"table"];
        } else if (lua_isfunction(L, i)) {
            [output appendString:@"function"];
        } else if (lua_isuserdata(L, i)) {
            [output appendString:@"userdata"];
        } else if (lua_isnil(L, i)) {
            [output appendString:@"nil"];
        } else {
            [output appendString:@"unknown"];
        }
    }
    
    NSLog(@"[XZX] %@", output);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXPrint" object:output];
    });
    
    return 0;
}

static int xzx_warn(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *output = [NSMutableString stringWithString:@"⚠️ "];
    
    for (int i = 1; i <= n; i++) {
        if (i > 1) [output appendString:@" "];
        if (lua_isstring(L, i)) {
            [output appendFormat:@"%s", lua_tostring(L, i)];
        }
    }
    
    NSLog(@"[XZX WARN] %@", output);
    return 0;
}

static int xzx_error(lua_State *L) {
    const char *msg = luaL_optstring(L, 1, "error");
    luaL_where(L, 1);
    lua_pushvalue(L, -1);
    lua_pushfstring(L, "%s: %s", lua_tostring(L, -1), msg);
    return lua_error(L);
}

static int xzx_type(lua_State *L) {
    if (lua_gettop(L) < 1) {
        lua_pushnil(L);
        return 1;
    }
    
    int type = lua_type(L, 1);
    const char *typeName = lua_typename(L, type);
    lua_pushstring(L, typeName);
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
    int table_idx = lua_gettop(L);
    
    lua_pushvalue(L, LUA_REGISTRYINDEX);
    lua_pushnil(L);
    
    while (lua_next(L, -2) != 0) {
        lua_pushvalue(L, -2);
        int type = lua_type(L, -2);
        
        if (type == LUA_TFUNCTION || type == LUA_TTABLE || 
            type == LUA_TUSERDATA || type == LUA_TTHREAD) {
            lua_pushinteger(L, lua_rawlen(L, table_idx) + 1);
            lua_pushvalue(L, -3);
            lua_settable(L, table_idx);
        }
        
        lua_pop(L, 2);
    }
    
    lua_pop(L, 1);
    return 1;
}

static int xzx_newcclosure(lua_State *L) {
    if (!lua_isfunction(L, 1)) {
        luaL_error(L, "expected function");
    }
    lua_pushvalue(L, 1);
    lua_pushcclosure(L, [](lua_State *L) -> int {
        lua_pushvalue(L, lua_upvalueindex(1));
        int nargs = lua_gettop(L) - 1;
        lua_insert(L, 1);
        lua_pcall(L, nargs, LUA_MULTRET, 0);
        return lua_gettop(L);
    }, 1);
    return 1;
}

static int xzx_iscclosure(lua_State *L) {
    if (!lua_isfunction(L, 1)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, lua_iscfunction(L, 1));
    return 1;
}

static int xzx_islclosure(lua_State *L) {
    if (!lua_isfunction(L, 1)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, !lua_iscfunction(L, 1));
    return 1;
}

static int xzx_isexecutorclosure(lua_State *L) {
    if (!lua_isfunction(L, 1)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    
    lua_Debug ar;
    lua_getinfo(L, ">S", &ar);
    
    if (ar.source && strstr(ar.source, "=xzx")) {
        lua_pushboolean(L, 1);
        return 1;
    }
    
    lua_pushboolean(L, 0);
    return 1;
}

static int xzx_hookfunction(lua_State *L) {
    if (!lua_isfunction(L, 1) || !lua_isfunction(L, 2)) {
        luaL_error(L, "expected two functions");
    }
    
    lua_pushvalue(L, 1);
    lua_pushvalue(L, 2);
    lua_pushcclosure(L, [](lua_State *L) -> int {
        lua_pushvalue(L, lua_upvalueindex(2));
        int nargs = lua_gettop(L);
        lua_insert(L, 1);
        lua_pcall(L, nargs, LUA_MULTRET, 0);
        return lua_gettop(L);
    }, 2);
    
    return 1;
}

static int xzx_getrawmetatable(lua_State *L) {
    if (!lua_getmetatable(L, 1)) {
        lua_pushnil(L);
    }
    return 1;
}

static int xzx_setrawmetatable(lua_State *L) {
    if (lua_istable(L, 1) && (lua_istable(L, 2) || lua_isnil(L, 2))) {
        lua_pushvalue(L, 2);
        lua_setmetatable(L, 1);
    }
    lua_settop(L, 1);
    return 1;
}

static int xzx_setclipboard(lua_State *L) {
    const char *text = luaL_checkstring(L, 1);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIPasteboard generalPasteboard].string = [NSString stringWithUTF8String:text];
    });
    return 0;
}

static int xzx_getclipboard(lua_State *L) {
    NSString *text = [UIPasteboard generalPasteboard].string;
    lua_pushstring(L, text ? [text UTF8String] : "");
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

static int xzx_loadstring(lua_State *L) {
    const char *code = luaL_checkstring(L, 1);
    const char *chunkname = luaL_optstring(L, 2, "=xzx");
    
    int status = luaL_loadbuffer(L, code, strlen(code), chunkname);
    
    if (status != 0) {
        lua_pushnil(L);
        lua_pushstring(L, lua_tostring(L, -1));
        lua_remove(L, -2);
        return 2;
    }
    
    return 1;
}

static int xzx_httpget(lua_State *L) {
    const char *url = luaL_checkstring(L, 1);
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *result = nil;
    __block int status_code = 0;
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [request setTimeoutInterval:30];
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (data) {
            result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                status_code = (int)((NSHTTPURLResponse *)response).statusCode;
            }
        }
        dispatch_semaphore_signal(semaphore);
    }];
    
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 30 * NSEC_PER_SEC));
    
    if (result) {
        lua_pushstring(L, [result UTF8String]);
        lua_pushinteger(L, status_code);
        return 2;
    }
    
    lua_pushnil(L);
    lua_pushstring(L, "Request failed");
    return 2;
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
    if (lua_gettop(L) < 1) {
        lua_pushnil(L);
        return 1;
    }
    
    const char *input = luaL_checkstring(L, 1);
    
    NSData *data = [NSData dataWithBytes:input length:strlen(input)];
    NSString *encoded = [data base64EncodedStringWithOptions:0];
    
    NSData *decoded = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
    NSString *result = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
    
    lua_pushstring(L, [result UTF8String]);
    return 1;
}

static int xzx_messagebox(lua_State *L) {
    const char *text = luaL_checkstring(L, 1);
    const char *caption = luaL_optstring(L, 2, "XZX");
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        
        if (@available(iOS 13.0, *)) {
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *windowScene = (UIWindowScene *)scene;
                    for (UIWindow *window in windowScene.windows) {
                        if (window.isKeyWindow) {
                            keyWindow = window;
                            break;
                        }
                    }
                }
                if (keyWindow) break;
            }
        }
        
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].windows.firstObject;
        }
        
        UIViewController *rootVC = keyWindow.rootViewController;
        
        if (rootVC) {
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:[NSString stringWithUTF8String:caption]
                                                                           message:[NSString stringWithUTF8String:text]
                                                                    preferredStyle:UIAlertControllerStyleAlert];
            
            [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
            
            [rootVC presentViewController:alert animated:YES completion:nil];
        }
    });
    
    return 0;
}

static int xzx_delay(lua_State *L) {
    double seconds = luaL_checknumber(L, 1);
    
    if (!lua_isfunction(L, 2)) {
        luaL_error(L, "expected function");
    }
    
    lua_pushvalue(L, 2);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        lua_pcall(L, 0, 0, 0);
        luaL_unref(L, LUA_REGISTRYINDEX, ref);
    });
    
    return 0;
}

static int xzx_spawn(lua_State *L) {
    if (!lua_isfunction(L, 1)) {
        luaL_error(L, "expected function");
    }
    
    lua_pushvalue(L, 1);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, ref);
        lua_pcall(L, 0, 0, 0);
        luaL_unref(L, LUA_REGISTRYINDEX, ref);
    });
    
    return 0;
}

void InitLua(void) {
    std::lock_guard<std::mutex> lock(lua_mutex);
    
    if (!L) {
        L = luaL_newstate();
        luaL_openlibs(L);
        
        lua_register(L, "print", xzx_print);
        lua_register(L, "warn", xzx_warn);
        lua_register(L, "error", xzx_error);
        lua_register(L, "type", xzx_type);
        lua_register(L, "getgenv", xzx_getgenv);
        lua_register(L, "getreg", xzx_getreg);
        lua_register(L, "getgc", xzx_getgc);
        lua_register(L, "newcclosure", xzx_newcclosure);
        lua_register(L, "iscclosure", xzx_iscclosure);
        lua_register(L, "islclosure", xzx_islclosure);
        lua_register(L, "isexecutorclosure", xzx_isexecutorclosure);
        lua_register(L, "hookfunction", xzx_hookfunction);
        lua_register(L, "getrawmetatable", xzx_getrawmetatable);
        lua_register(L, "setrawmetatable", xzx_setrawmetatable);
        lua_register(L, "setclipboard", xzx_setclipboard);
        lua_register(L, "getclipboard", xzx_getclipboard);
        lua_register(L, "identifyexecutor", xzx_identifyexecutor);
        lua_register(L, "getexecutorname", xzx_getexecutorname);
        lua_register(L, "checkcaller", xzx_checkcaller);
        lua_register(L, "loadstring", xzx_loadstring);
        lua_register(L, "HttpGet", xzx_httpget);
        lua_register(L, "game_HttpGet", xzx_httpget);
        lua_register(L, "base64encode", xzx_base64_encode);
        lua_register(L, "base64decode", xzx_base64_decode);
        lua_register(L, "base64codes", xzx_base64codes);
        lua_register(L, "messagebox", xzx_messagebox);
        lua_register(L, "delay", xzx_delay);
        lua_register(L, "spawn", xzx_spawn);
        
        luaL_dostring(L, "xzx = { version = '3.0.0', unc = 95, sunc = 85 }");
        
        luaL_dostring(L, 
            "task = {}\n"
            "task.spawn = spawn\n"
            "task.delay = delay\n"
            "task.wait = function(t) if t then local s = os.clock() while os.clock() - s < t do end end end\n"
            "task.defer = function(f) spawn(f) end\n"
        );
    }
}

void ExecuteScript(const char *script) {
    std::lock_guard<std::mutex> lock(lua_mutex);
    
    if (!L) InitLua();
    
    lua_State *thread = lua_newthread(L);
    int threadRef = luaL_ref(L, LUA_REGISTRYINDEX);
    
    int status = luaL_loadstring(thread, script);
    
    if (status != 0) {
        const char *error = lua_tostring(thread, -1);
        NSLog(@"[XZX] Error: %s", error);
        luaL_unref(L, LUA_REGISTRYINDEX, threadRef);
        return;
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        lua_rawgeti(L, LUA_REGISTRYINDEX, threadRef);
        lua_State *exec_thread = lua_tothread(L, -1);
        
        if (exec_thread) {
            int result = lua_pcall(exec_thread, 0, 0, 0);
            
            if (result != 0) {
                const char *error = lua_tostring(exec_thread, -1);
                NSLog(@"[XZX] Execution error: %s", error);
            }
        }
        
        luaL_unref(L, LUA_REGISTRYINDEX, threadRef);
    });
}
EOF
