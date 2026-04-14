#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <pthread.h>
#include <unistd.h>
#include "SRFXLua.h"

static lua_State *L = NULL;
static pthread_mutex_t lua_mutex = PTHREAD_MUTEX_INITIALIZER;

static int srfx_print(lua_State *L) {
    int n = lua_gettop(L);
    NSMutableString *out = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        if (i > 1) [out appendString:@" "];
        if (lua_isstring(L, i))       [out appendFormat:@"%s", lua_tostring(L, i)];
        else if (lua_isnumber(L, i))  [out appendFormat:@"%g", lua_tonumber(L, i)];
        else if (lua_isboolean(L, i)) [out appendString:lua_toboolean(L, i) ? @"true" : @"false"];
        else if (lua_istable(L, i))   [out appendString:@"table"];
        else if (lua_isfunction(L, i))[out appendString:@"function"];
        else                          [out appendString:@"nil"];
    }
    NSString *copy = [out copy];
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"SRFXPrint" object:copy];
    });
    return 0;
}

static int srfx_warn(lua_State *L) { return srfx_print(L); }

static int srfx_getscript(lua_State *L) {
    const char *urlStr = luaL_checkstring(L, 1);
    NSURL *url = [NSURL URLWithString:[NSString stringWithUTF8String:urlStr]];
    if (!url) { lua_pushnil(L); return 1; }
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    __block NSString *result = nil;
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
    [req setValue:@"Mozilla/5.0" forHTTPHeaderField:@"User-Agent"];
    [[[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *r, NSError *e) {
        if (data && !e) result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        dispatch_semaphore_signal(sem);
    }] resume];
    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    if (result) lua_pushstring(L, result.UTF8String);
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
    lua_pushstring(L, [e UTF8String]); return 1;
}

static int srfx_base64_decode(lua_State *L) {
    const char *d = luaL_checkstring(L, 1);
    NSData *dec = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:d] options:0];
    NSString *s = dec ? [[NSString alloc] initWithData:dec encoding:NSUTF8StringEncoding] : nil;
    lua_pushstring(L, s ? [s UTF8String] : ""); return 1;
}

static int srfx_identifyexecutor (lua_State *L) { lua_pushstring(L,"SERFIX"); return 1; }
static int srfx_getexecutorname  (lua_State *L) { lua_pushstring(L,"SERFIX"); return 1; }
static int srfx_checkcaller      (lua_State *L) { lua_pushboolean(L,1); return 1; }
static int srfx_isrbxactive      (lua_State *L) { lua_pushboolean(L,1); return 1; }
static int srfx_getthreadidentity(lua_State *L) { lua_pushinteger(L,8); return 1; }
static int srfx_setthreadidentity(lua_State *L) { (void)L; return 0; }
static int srfx_fireclickdetector(lua_State *L) { (void)L; return 0; }
static int srfx_getgenv          (lua_State *L) { lua_pushglobaltable(L); return 1; }
static int srfx_getreg           (lua_State *L) { lua_pushvalue(L, LUA_REGISTRYINDEX); return 1; }

static int srfx_wait(lua_State *L) {
    double sec = luaL_optnumber(L, 1, 0);
    if (sec > 0) {
        pthread_mutex_unlock(&lua_mutex);
        usleep((useconds_t)(sec * 1000000));
        pthread_mutex_lock(&lua_mutex);
    }
    return 0;
}

static int srfx_getgc(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getinstances(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getscripts(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getloadedmodules(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_hookfunction(lua_State *L) { lua_pushvalue(L,1); return 1; }
static int srfx_newcclosure(lua_State *L) { lua_pushvalue(L,1); return 1; }
static int srfx_getconstants(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getupvalues(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_setupvalue(lua_State *L) { (void)L; return 0; }
static int srfx_getrawmetatable(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_setrawmetatable(lua_State *L) { (void)L; return 0; }
static int srfx_fireproximityprompt(lua_State *L) { (void)L; return 0; }
static int srfx_firetouchinterest(lua_State *L) { (void)L; return 0; }
static int srfx_gethiddenproperty(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_sethiddenproperty(lua_State *L) { (void)L; return 0; }
static int srfx_getnamecallmethod(lua_State *L) { lua_pushstring(L, ""); return 1; }
static int srfx_setnamecallmethod(lua_State *L) { (void)L; return 0; }
static int srfx_getconnections(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_firesignal(lua_State *L) { (void)L; return 0; }
static int srfx_connect(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_disconnect(lua_State *L) { (void)L; return 0; }
static int srfx_waitforchild(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getservice(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getchildren(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getdescendants(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_findfirstchild(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getproperties(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_getproperty(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_setproperty(lua_State *L) { (void)L; return 0; }
static int srfx_getinfo(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_islclosure(lua_State *L) { lua_pushboolean(L,1); return 1; }
static int srfx_getproto(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_getstack(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_make_writeable(lua_State *L) { (void)L; return 0; }
static int srfx_getcallingscript(lua_State *L) { lua_pushstring(L,"SERFIX"); return 1; }
static int srfx_getscripthash(lua_State *L) { lua_pushstring(L,"SERFIX"); return 1; }
static int srfx_httpget(lua_State *L) { return srfx_getscript(L); }
static int srfx_httppost(lua_State *L) { lua_pushstring(L,""); return 1; }
static int srfx_setclipboard(lua_State *L) { (void)L; return 0; }
static int srfx_getclipboard(lua_State *L) { lua_pushstring(L,""); return 1; }
static int srfx_messagebox(lua_State *L) { (void)L; return 0; }
static int srfx_isfile(lua_State *L) { lua_pushboolean(L,0); return 1; }
static int srfx_isfolder(lua_State *L) { lua_pushboolean(L,0); return 1; }
static int srfx_listfiles(lua_State *L) { lua_newtable(L); return 1; }
static int srfx_readfile(lua_State *L) { lua_pushstring(L,""); return 1; }
static int srfx_writefile(lua_State *L) { (void)L; return 0; }
static int srfx_appendfile(lua_State *L) { (void)L; return 0; }
static int srfx_deletefile(lua_State *L) { (void)L; return 0; }
static int srfx_makefolder(lua_State *L) { (void)L; return 0; }
static int srfx_dofile(lua_State *L) { (void)L; return 0; }
static int srfx_loadfile(lua_State *L) { lua_pushnil(L); return 1; }
static int srfx_createnotification(lua_State *L) { (void)L; return 0; }
static int srfx_webhook(lua_State *L) { (void)L; return 0; }
static int srfx_setfpscap(lua_State *L) { (void)L; return 0; }
static int srfx_getfps(lua_State *L) { lua_pushinteger(L,60); return 1; }
static int srfx_getping(lua_State *L) { lua_pushinteger(L,30); return 1; }
static int srfx_gethwid(lua_State *L) { lua_pushstring(L,"SERFIX_HWID"); return 1; }
static int srfx_getuser(lua_State *L) { lua_pushstring(L,"SERFIX"); return 1; }
static int srfx_getexecutionpath(lua_State *L) { lua_pushstring(L,"SERFIX"); return 1; }
static int srfx_clonefunction(lua_State *L) { lua_pushvalue(L,1); return 1; }
static int srfx_isfolder_ins(lua_State *L) { lua_pushboolean(L,0); return 1; }
static int srfx_isscript(lua_State *L) { lua_pushboolean(L,0); return 1; }

extern "C" {

__attribute__((visibility("default")))
void SRFXLuaInit(void) {
    if (L) return;
    L = luaL_newstate();
    if (!L) return;
    luaL_openlibs(L);
    #define REG(name, fn) lua_register(L, name, fn)
    REG("print",srfx_print); REG("warn",srfx_warn);
    REG("getscript",srfx_getscript); REG("loadstring",srfx_loadstring);
    REG("base64_encode",srfx_base64_encode); REG("base64_decode",srfx_base64_decode);
    REG("identifyexecutor",srfx_identifyexecutor); REG("getexecutorname",srfx_getexecutorname);
    REG("checkcaller",srfx_checkcaller); REG("isrbxactive",srfx_isrbxactive);
    REG("getthreadidentity",srfx_getthreadidentity); REG("setthreadidentity",srfx_setthreadidentity);
    REG("fireclickdetector",srfx_fireclickdetector); REG("getgenv",srfx_getgenv);
    REG("getreg",srfx_getreg); REG("wait",srfx_wait);
    REG("getgc",srfx_getgc); REG("getinstances",srfx_getinstances);
    REG("getscripts",srfx_getscripts); REG("getloadedmodules",srfx_getloadedmodules);
    REG("hookfunction",srfx_hookfunction); REG("newcclosure",srfx_newcclosure);
    REG("getconstants",srfx_getconstants); REG("getupvalues",srfx_getupvalues);
    REG("setupvalue",srfx_setupvalue); REG("getrawmetatable",srfx_getrawmetatable);
    REG("setrawmetatable",srfx_setrawmetatable); REG("fireproximityprompt",srfx_fireproximityprompt);
    REG("firetouchinterest",srfx_firetouchinterest); REG("gethiddenproperty",srfx_gethiddenproperty);
    REG("sethiddenproperty",srfx_sethiddenproperty); REG("getnamecallmethod",srfx_getnamecallmethod);
    REG("setnamecallmethod",srfx_setnamecallmethod); REG("getconnections",srfx_getconnections);
    REG("firesignal",srfx_firesignal); REG("connect",srfx_connect);
    REG("disconnect",srfx_disconnect); REG("waitforchild",srfx_waitforchild);
    REG("getservice",srfx_getservice); REG("getchildren",srfx_getchildren);
    REG("getdescendants",srfx_getdescendants); REG("findfirstchild",srfx_findfirstchild);
    REG("getproperties",srfx_getproperties); REG("getproperty",srfx_getproperty);
    REG("setproperty",srfx_setproperty); REG("getinfo",srfx_getinfo);
    REG("islclosure",srfx_islclosure); REG("getproto",srfx_getproto);
    REG("getstack",srfx_getstack); REG("make_writeable",srfx_make_writeable);
    REG("getcallingscript",srfx_getcallingscript); REG("getscripthash",srfx_getscripthash);
    REG("http_get",srfx_httpget); REG("http_post",srfx_httppost);
    REG("setclipboard",srfx_setclipboard); REG("getclipboard",srfx_getclipboard);
    REG("messagebox",srfx_messagebox); REG("isfile",srfx_isfile);
    REG("isfolder",srfx_isfolder); REG("listfiles",srfx_listfiles);
    REG("readfile",srfx_readfile); REG("writefile",srfx_writefile);
    REG("appendfile",srfx_appendfile); REG("deletefile",srfx_deletefile);
    REG("makefolder",srfx_makefolder); REG("dofile",srfx_dofile);
    REG("loadfile",srfx_loadfile); REG("createnotification",srfx_createnotification);
    REG("webhook",srfx_webhook); REG("setfpscap",srfx_setfpscap);
    REG("getfps",srfx_getfps); REG("getping",srfx_getping);
    REG("gethwid",srfx_gethwid); REG("getuser",srfx_getuser);
    REG("getexecutionpath",srfx_getexecutionpath); REG("clonefunction",srfx_clonefunction);
    REG("isfolder_ins",srfx_isfolder_ins); REG("isscript",srfx_isscript);
    #undef REG
    lua_newtable(L);
    lua_pushstring(L,"SERFIX"); lua_setfield(L,-2,"name");
    lua_pushstring(L,"2.5.0");  lua_setfield(L,-2,"version");
    lua_setglobal(L,"serfix");
}

__attribute__((visibility("default")))
void SRFXLuaExecute(const char *script) {
    if (!script || !script[0]) return;
    pthread_mutex_lock(&lua_mutex);
    if (!L) SRFXLuaInit();
    if (L) {
        int s = luaL_dostring(L, script);
        if (s != LUA_OK) {
            const char *err = lua_tostring(L, -1);
            NSString *errStr = err ? [NSString stringWithUTF8String:err] : @"unknown error";
            dispatch_async(dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:@"SRFXError" object:errStr];
            });
            lua_pop(L, 1);
        }
    }
    pthread_mutex_unlock(&lua_mutex);
}

__attribute__((visibility("default")))
void SRFXLuaRegister(const char *name, int (*func)(lua_State*)) {
    pthread_mutex_lock(&lua_mutex);
    if (L && name && func) lua_register(L, name, func);
    pthread_mutex_unlock(&lua_mutex);
}

__attribute__((visibility("default")))
lua_State* SRFXLuaState(void) { return L; }

}
