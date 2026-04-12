#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <pthread.h>
#include "SRFXLua.h"

static lua_State *L = nil;
static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;

static int srfx_print(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *s = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        if (i > 1) [s appendString:@" "];
        if (lua_isstring(L, i)) [s appendFormat:@"%s", lua_tostring(L, i)];
        else if (lua_isnumber(L, i)) [s appendFormat:@"%g", lua_tonumber(L, i)];
        else if (lua_isboolean(L, i)) [s appendString:lua_toboolean(L, i) ? @"true" : @"false"];
        else if (lua_istable(L, i)) [s appendString:@"table"];
        else if (lua_isfunction(L, i)) [s appendString:@"function"];
        else [s appendString:@"nil"];
    }
    NSLog(@"[SERFIX] %@", s);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SRFXPrint" object:s];
    });
    return 0;
}

static int srfx_warn(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *s = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        if (i > 1) [s appendString:@" "];
        if (lua_isstring(L, i)) [s appendFormat:@"%s", lua_tostring(L, i)];
    }
    NSLog(@"[SERFIX WARN] %@", s);
    return 0;
}

static int srfx_getscript(lua_State *L) {
    const char *url = luaL_checkstring(L, 1);
    __block NSString *res = nil;
    __block BOOL done = NO;
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]];
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        if (d && !e) res = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        done = YES;
    }];
    [task resume];
    NSDate *timeout = [NSDate dateWithTimeIntervalSinceNow:10.0];
    while (!done && [timeout timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    }
    if (res) lua_pushstring(L, [res UTF8String]);
    else lua_pushnil(L);
    return 1;
}

static int srfx_loadstring(lua_State *L) {
    const char *code = luaL_checkstring(L, 1);
    int s = luaL_loadstring(L, code);
    if (s != LUA_OK) { lua_pushnil(L); lua_insert(L, -2); return 2; }
    return 1;
}

static int srfx_base64_encode(lua_State *L) {
    const char *d = luaL_checkstring(L, 1);
    NSString *e = [[NSData dataWithBytes:d length:strlen(d)] base64EncodedStringWithOptions:0];
    lua_pushstring(L, [e UTF8String]);
    return 1;
}

static int srfx_base64_decode(lua_State *L) {
    const char *d = luaL_checkstring(L, 1);
    NSData *dec = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:d] options:0];
    NSString *s = [[NSString alloc] initWithData:dec encoding:NSUTF8StringEncoding];
    lua_pushstring(L, s ? [s UTF8String] : "");
    return 1;
}

static int srfx_identifyexecutor(lua_State *L) { lua_pushstring(L, "SERFIX"); return 1; }
static int srfx_getexecutorname(lua_State *L) { lua_pushstring(L, "SERFIX"); return 1; }
static int srfx_checkcaller(lua_State *L) { lua_pushboolean(L, 1); return 1; }
static int srfx_isrbxactive(lua_State *L) { lua_pushboolean(L, 1); return 1; }
static int srfx_getthreadidentity(lua_State *L) { lua_pushinteger(L, 8); return 1; }
static int srfx_setthreadidentity(lua_State *L) { return 0; }
static int srfx_fireclickdetector(lua_State *L) { return 0; }
static int srfx_getgenv(lua_State *L) { lua_pushglobaltable(L); return 1; }
static int srfx_getreg(lua_State *L) { lua_pushvalue(L, LUA_REGISTRYINDEX); return 1; }
static int srfx_wait(lua_State *L) { double sec = luaL_optnumber(L, 1, 0); usleep(sec * 1000000); return 0; }
static int srfx_getgc(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getconnections(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_firetouchinterest(lua_State *L) { return 0; }
static int srfx_getrawmetatable(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_setrawmetatable(lua_State *L) { return 0; }
static int srfx_make_writeable(lua_State *L) { return 0; }
static int srfx_islclosure(lua_State *L) { lua_pushboolean(L, 1); return 1; }
static int srfx_newcclosure(lua_State *L) { lua_pushcfunction(L, srfx_wait); return 1; }
static int srfx_hookfunction(lua_State *L) { lua_pushvalue(L, 1); return 1; }
static int srfx_clonefunction(lua_State *L) { lua_pushvalue(L, 1); return 1; }
static int srfx_getinfo(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getconstants(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getupvalues(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_setupvalue(lua_State *L) { return 0; }
static int srfx_getupvalue(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getproto(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getstack(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_setstack(lua_State *L) { return 0; }
static int srfx_getcallingscript(lua_State *L) { lua_pushstring(L, "SERFIX"); return 1; }
static int srfx_getscripthash(lua_State *L) { lua_pushstring(L, "SERFIX"); return 1; }
static int srfx_httpget(lua_State *L) { return srfx_getscript(L); }
static int srfx_httppost(lua_State *L) { lua_pushstring(L, ""); return 1; }
static int srfx_setclipboard(lua_State *L) { return 0; }
static int srfx_getclipboard(lua_State *L) { lua_pushstring(L, ""); return 1; }
static int srfx_messagebox(lua_State *L) { return 0; }
static int srfx_request(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_isfile(lua_State *L) { lua_pushboolean(L, 0); return 1; }
static int srfx_isfolder(lua_State *L) { lua_pushboolean(L, 0); return 1; }
static int srfx_listfiles(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_readfile(lua_State *L) { lua_pushstring(L, ""); return 1; }
static int srfx_writefile(lua_State *L) { return 0; }
static int srfx_appendfile(lua_State *L) { return 0; }
static int srfx_deletefile(lua_State *L) { return 0; }
static int srfx_makefolder(lua_State *L) { return 0; }
static int srfx_dofile(lua_State *L) { return 0; }
static int srfx_loadfile(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getrunningscripts(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getloadedmodules(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getinstances(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getnilinstances(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getscripts(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getchildren(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getdescendants(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_findfirstchild(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_isfolder_ins(lua_State *L) { lua_pushboolean(L, 0); return 1; }
static int srfx_isscript(lua_State *L) { lua_pushboolean(L, 0); return 1; }
static int srfx_getproperties(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getproperty(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_setproperty(lua_State *L) { return 0; }
static int srfx_gethiddenproperty(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_sethiddenproperty(lua_State *L) { return 0; }
static int srfx_firesignal(lua_State *L) { return 0; }
static int srfx_connect(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_disconnect(lua_State *L) { return 0; }
static int srfx_waitforchild(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getservice(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_createnotification(lua_State *L) { return 0; }
static int srfx_webhook(lua_State *L) { return 0; }
static int srfx_setfpscap(lua_State *L) { return 0; }
static int srfx_getfps(lua_State *L) { lua_pushinteger(L, 60); return 1; }
static int srfx_getping(lua_State *L) { lua_pushinteger(L, 30); return 1; }
static int srfx_gethwid(lua_State *L) { lua_pushstring(L, "SERFIX_HWID"); return 1; }
static int srfx_getuser(lua_State *L) { lua_pushstring(L, "SERFIX"); return 1; }
static int srfx_getexecutionpath(lua_State *L) { lua_pushstring(L, "SERFIX"); return 1; }

void SRFXLuaInit(void) {
    if (L) return;
    L = luaL_newstate();
    if (!L) return;
    luaL_openlibs(L);
    lua_register(L, "print", srfx_print);
    lua_register(L, "warn", srfx_warn);
    lua_register(L, "getscript", srfx_getscript);
    lua_register(L, "loadstring", srfx_loadstring);
    lua_register(L, "base64_encode", srfx_base64_encode);
    lua_register(L, "base64_decode", srfx_base64_decode);
    lua_register(L, "identifyexecutor", srfx_identifyexecutor);
    lua_register(L, "getexecutorname", srfx_getexecutorname);
    lua_register(L, "checkcaller", srfx_checkcaller);
    lua_register(L, "isrbxactive", srfx_isrbxactive);
    lua_register(L, "getthreadidentity", srfx_getthreadidentity);
    lua_register(L, "setthreadidentity", srfx_setthreadidentity);
    lua_register(L, "fireclickdetector", srfx_fireclickdetector);
    lua_register(L, "getgenv", srfx_getgenv);
    lua_register(L, "getreg", srfx_getreg);
    lua_register(L, "wait", srfx_wait);
    lua_register(L, "getgc", srfx_getgc);
    lua_register(L, "getconnections", srfx_getconnections);
    lua_register(L, "firetouchinterest", srfx_firetouchinterest);
    lua_register(L, "getrawmetatable", srfx_getrawmetatable);
    lua_register(L, "setrawmetatable", srfx_setrawmetatable);
    lua_register(L, "make_writeable", srfx_make_writeable);
    lua_register(L, "islclosure", srfx_islclosure);
    lua_register(L, "newcclosure", srfx_newcclosure);
    lua_register(L, "hookfunction", srfx_hookfunction);
    lua_register(L, "clonefunction", srfx_clonefunction);
    lua_register(L, "getinfo", srfx_getinfo);
    lua_register(L, "getconstants", srfx_getconstants);
    lua_register(L, "getupvalues", srfx_getupvalues);
    lua_register(L, "setupvalue", srfx_setupvalue);
    lua_register(L, "getupvalue", srfx_getupvalue);
    lua_register(L, "getproto", srfx_getproto);
    lua_register(L, "getstack", srfx_getstack);
    lua_register(L, "setstack", srfx_setstack);
    lua_register(L, "getcallingscript", srfx_getcallingscript);
    lua_register(L, "getscripthash", srfx_getscripthash);
    lua_register(L, "http_get", srfx_httpget);
    lua_register(L, "http_post", srfx_httppost);
    lua_register(L, "setclipboard", srfx_setclipboard);
    lua_register(L, "getclipboard", srfx_getclipboard);
    lua_register(L, "messagebox", srfx_messagebox);
    lua_register(L, "request", srfx_request);
    lua_register(L, "isfile", srfx_isfile);
    lua_register(L, "isfolder", srfx_isfolder);
    lua_register(L, "listfiles", srfx_listfiles);
    lua_register(L, "readfile", srfx_readfile);
    lua_register(L, "writefile", srfx_writefile);
    lua_register(L, "appendfile", srfx_appendfile);
    lua_register(L, "deletefile", srfx_deletefile);
    lua_register(L, "makefolder", srfx_makefolder);
    lua_register(L, "dofile", srfx_dofile);
    lua_register(L, "loadfile", srfx_loadfile);
    lua_register(L, "getrunningscripts", srfx_getrunningscripts);
    lua_register(L, "getloadedmodules", srfx_getloadedmodules);
    lua_register(L, "getinstances", srfx_getinstances);
    lua_register(L, "getnilinstances", srfx_getnilinstances);
    lua_register(L, "getscripts", srfx_getscripts);
    lua_register(L, "getchildren", srfx_getchildren);
    lua_register(L, "getdescendants", srfx_getdescendants);
    lua_register(L, "findfirstchild", srfx_findfirstchild);
    lua_register(L, "isfolder_ins", srfx_isfolder_ins);
    lua_register(L, "isscript", srfx_isscript);
    lua_register(L, "getproperties", srfx_getproperties);
    lua_register(L, "getproperty", srfx_getproperty);
    lua_register(L, "setproperty", srfx_setproperty);
    lua_register(L, "gethiddenproperty", srfx_gethiddenproperty);
    lua_register(L, "sethiddenproperty", srfx_sethiddenproperty);
    lua_register(L, "firesignal", srfx_firesignal);
    lua_register(L, "connect", srfx_connect);
    lua_register(L, "disconnect", srfx_disconnect);
    lua_register(L, "waitforchild", srfx_waitforchild);
    lua_register(L, "getservice", srfx_getservice);
    lua_register(L, "createnotification", srfx_createnotification);
    lua_register(L, "webhook", srfx_webhook);
    lua_register(L, "setfpscap", srfx_setfpscap);
    lua_register(L, "getfps", srfx_getfps);
    lua_register(L, "getping", srfx_getping);
    lua_register(L, "gethwid", srfx_gethwid);
    lua_register(L, "getuser", srfx_getuser);
    lua_register(L, "getexecutionpath", srfx_getexecutionpath);
    lua_newtable(L);
    lua_pushstring(L, "SERFIX");
    lua_setfield(L, -2, "name");
    lua_pushstring(L, "2.0.0");
    lua_setfield(L, -2, "version");
    lua_setglobal(L, "serfix");
    NSLog(@"[SERFIX] Lua ready");
}

void SRFXLuaExecute(const char *script) {
    pthread_mutex_lock(&mutex);
    if (!L) SRFXLuaInit();
    if (script && strlen(script) > 0) {
        int s = luaL_dostring(L, script);
        if (s != LUA_OK) {
            const char *err = lua_tostring(L, -1);
            NSLog(@"[SERFIX] Lua error: %s", err);
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"SRFXError" object:[NSString stringWithUTF8String:err]];
            });
            lua_pop(L, 1);
        }
    }
    pthread_mutex_unlock(&mutex);
}

void SRFXLuaRegister(const char *name, int (*func)(lua_State*)) {
    pthread_mutex_lock(&mutex);
    if (L) lua_register(L, name, func);
    pthread_mutex_unlock(&mutex);
}

lua_State* SRFXLuaState(void) {
    return L;
}
