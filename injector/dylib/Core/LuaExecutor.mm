#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>
#include <vector>
#include <string>
#include <map>
#include <unordered_map>
#include <thread>
#include <mutex>
#include <regex>
#include <mach/mach.h>
#include <mach-o/dyld.h>
#include <sys/mman.h>
#include <dlfcn.h>
#include <CommonCrypto/CommonDigest.h>
#include <CommonCrypto/CommonCryptor.h>
#include <zlib.h>

static lua_State *main_lua_state = nullptr;
static std::mutex lua_mutex;
static uintptr_t roblox_base = 0;
static uintptr_t datamodel_ptr = 0;
static uintptr_t lua_state_ptr = 0;
static uintptr_t script_context_ptr = 0;
static std::unordered_map<std::string, uintptr_t> function_cache;
static std::unordered_map<lua_State*, int> thread_identities;
static std::unordered_map<int, std::function<void(lua_State*)>> callbacks;
static int next_callback_id = 1;

struct Proto {
    Proto* next;
    uint8_t flags;
    uint8_t numparams;
    uint8_t is_vararg;
    uint8_t maxstacksize;
    int sizeupvalues;
    int sizep;
    int sizelocvars;
    int sizek;
    int sizecode;
    int* code;
    void* instructions;
    void* k;
    void** p;
    void* locvars;
    void* upvalues;
    void* gcheader;
    void* source;
    void* debugname;
    int linedefined;
    int lastlinedefined;
};

struct Closure {
    union {
        struct {
            Proto* p;
            uint8_t nupvalues;
            void* gclist;
            void* env;
        } l;
        struct {
            lua_CFunction f;
            uint8_t nupvalues;
            void* gclist;
            void* env;
        } c;
    };
    uint8_t isC;
    uint8_t isluau;
    void* upvals[1];
};

struct TValue {
    union {
        double n;
        void* p;
        lua_CFunction f;
        int b;
    } value;
    int tt;
};

struct global_State {
    void* frealloc;
    void* ud;
    void* mainthread;
    lua_State* running;
    void* allgc;
    void* gray;
    void* grayagain;
    void* weak;
    int gcfinnertag;
    int gcstate;
    int gcsteps;
    int gcestimate;
    int gcpause;
    int gcstepmul;
    int current_white;
    int sweepstrtg;
    int totalbytes;
    int GCthreshold;
    int estimate;
    int panic;
    int version;
};

struct CallInfo {
    lua_State* L;
    CallInfo* previous;
    CallInfo* next;
    void* func;
    int* savedpc;
    int base;
    int top;
    int nresults;
    int currentline;
    int callstatus;
};

static void scan_roblox_memory() {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
}

static uintptr_t find_pattern(uintptr_t start, size_t length, const char* pattern, const char* mask) {
    for (uintptr_t i = 0; i < length; i++) {
        bool found = true;
        for (uintptr_t j = 0; j < strlen(mask); j++) {
            if (mask[j] == 'x' && *(char*)(start + i + j) != pattern[j]) {
                found = false;
                break;
            }
        }
        if (found) return start + i;
    }
    return 0;
}

static uintptr_t get_vtable_address(const char* class_name) {
    Class cls = objc_getClass(class_name);
    if (!cls) return 0;
    uintptr_t* isa = (uintptr_t*)cls;
    uintptr_t* vtable = (uintptr_t*)*isa;
    return (uintptr_t)vtable;
}

static uintptr_t get_datamodel_ptr() {
    uintptr_t vtable = get_vtable_address("RobloxDataModel");
    if (!vtable) return 0;
    for (int i = 0; i < 0x100; i++) {
        uintptr_t candidate = vtable - i * 8;
        uintptr_t* ptr = (uintptr_t*)candidate;
        if (*ptr == vtable) {
            uintptr_t static_ptr = candidate;
            return *(uintptr_t*)(static_ptr + 0x20);
        }
    }
    return 0;
}

static lua_State* get_roblox_lua_state() {
    uintptr_t datamodel = get_datamodel_ptr();
    if (!datamodel) return nullptr;
    uintptr_t script_context = datamodel + 0x70;
    script_context_ptr = *(uintptr_t*)script_context;
    if (!script_context_ptr) return nullptr;
    uintptr_t lua_state_addr = script_context_ptr + 0x48;
    return (lua_State*)*(uintptr_t*)lua_state_addr;
}

static Proto* get_proto(lua_State* L, int idx) {
    if (!lua_isfunction(L, idx)) return nullptr;
    Closure* cl = (Closure*)lua_topointer(L, idx);
    if (!cl || cl->isC) return nullptr;
    return cl->l.p;
}

static int loadstring_impl(lua_State* L) {
    const char* code = luaL_checkstring(L, 1);
    const char* chunkname = luaL_optstring(L, 2, "=xzx");
    int status = luaL_loadbuffer(L, code, strlen(code), chunkname);
    if (status != 0) {
        lua_pushnil(L);
        lua_pushstring(L, lua_tostring(L, -1));
        lua_remove(L, -2);
        return 2;
    }
    return 1;
}

static int httpget_impl(lua_State* L) {
    const char* url = luaL_checkstring(L, 1);
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString* result = nil;
    __block int status_code = 0;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]];
    [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 15_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/15.0 Mobile/15E148 Safari/604.1" forHTTPHeaderField:@"User-Agent"];
    [request setTimeoutInterval:30];
    NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (data) {
            result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
                status_code = (int)((NSHTTPURLResponse*)response).statusCode;
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

static int base64_encode(lua_State* L) {
    const char* data = luaL_checkstring(L, 1);
    NSData* nsdata = [NSData dataWithBytes:data length:strlen(data)];
    NSString* encoded = [nsdata base64EncodedStringWithOptions:0];
    lua_pushstring(L, [encoded UTF8String]);
    return 1;
}

static int base64_decode(lua_State* L) {
    const char* data = luaL_checkstring(L, 1);
    NSData* nsdata = [[NSData alloc] initWithBase64EncodedString:[NSString stringWithUTF8String:data] options:0];
    NSString* decoded = [[NSString alloc] initWithData:nsdata encoding:NSUTF8StringEncoding];
    lua_pushstring(L, [decoded UTF8String]);
    return 1;
}

static int base64codes(lua_State* L) {
    if (lua_gettop(L) < 1) {
        lua_pushnil(L);
        return 1;
    }
    const char* input = luaL_checkstring(L, 1);
    NSData* data = [NSData dataWithBytes:input length:strlen(input)];
    NSString* encoded = [data base64EncodedStringWithOptions:0];
    NSData* decoded = [[NSData alloc] initWithBase64EncodedString:encoded options:0];
    NSString* result = [[NSString alloc] initWithData:decoded encoding:NSUTF8StringEncoding];
    lua_pushstring(L, [result UTF8String]);
    return 1;
}

static int print_impl(lua_State* L) {
    int n = lua_gettop(L);
    NSMutableString* output = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        if (i > 1) [output appendString:@" "];
        switch (lua_type(L, i)) {
            case LUA_TSTRING: [output appendFormat:@"%s", lua_tostring(L, i)]; break;
            case LUA_TNUMBER: [output appendFormat:@"%g", lua_tonumber(L, i)]; break;
            case LUA_TBOOLEAN: [output appendString:lua_toboolean(L, i) ? "true" : "false"]; break;
            case LUA_TNIL: [output appendString:@"nil"]; break;
            default: [output appendFormat:@"%s", lua_typename(L, lua_type(L, i))];
        }
    }
    NSLog(@"[XZX] %@", output);
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"XZXPrint" object:output];
    });
    return 0;
}

static int warn_impl(lua_State* L) {
    int n = lua_gettop(L);
    NSMutableString* output = [NSMutableString string];
    for (int i = 1; i <= n; i++) {
        if (i > 1) [output appendString:@" "];
        [output appendFormat:@"%s", lua_tostring(L, i)];
    }
    NSLog(@"[XZX WARNING] %@", output);
    return 0;
}

static int error_impl(lua_State* L) {
    const char* msg = luaL_optstring(L, 1, "error");
    luaL_where(L, 1);
    lua_pushvalue(L, -1);
    lua_pushfstring(L, "%s: %s", lua_tostring(L, -1), msg);
    return lua_error(L);
}

static int getgenv_impl(lua_State* L) {
    lua_pushvalue(L, LUA_GLOBALSINDEX);
    return 1;
}

static int getrenv_impl(lua_State* L) {
    lua_State* rbxL = get_roblox_lua_state();
    if (rbxL) {
        lua_pushvalue(rbxL, LUA_GLOBALSINDEX);
        lua_xmove(rbxL, L, 1);
    } else {
        lua_pushvalue(L, LUA_GLOBALSINDEX);
    }
    return 1;
}

static int getreg_impl(lua_State* L) {
    lua_pushvalue(L, LUA_REGISTRYINDEX);
    return 1;
}

static int getgc_impl(lua_State* L) {
    lua_newtable(L);
    int table_idx = lua_gettop(L);
    global_State* g = (global_State*)((char*)L - offsetof(lua_State, l_G));
    void* allgc = g->allgc;
    while (allgc) {
        lua_pushinteger(L, lua_rawlen(L, table_idx) + 1);
        lua_pushlightuserdata(L, allgc);
        lua_settable(L, table_idx);
        allgc = *(void**)allgc;
    }
    void* gray = g->gray;
    while (gray) {
        lua_pushinteger(L, lua_rawlen(L, table_idx) + 1);
        lua_pushlightuserdata(L, gray);
        lua_settable(L, table_idx);
        gray = *(void**)gray;
    }
    void* grayagain = g->grayagain;
    while (grayagain) {
        lua_pushinteger(L, lua_rawlen(L, table_idx) + 1);
        lua_pushlightuserdata(L, grayagain);
        lua_settable(L, table_idx);
        grayagain = *(void**)grayagain;
    }
    return 1;
}

static int newcclosure_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) {
        luaL_error(L, "expected function");
    }
    lua_pushvalue(L, 1);
    lua_pushcclosure(L, [](lua_State* L) -> int {
        lua_pushvalue(L, lua_upvalueindex(1));
        int nargs = lua_gettop(L) - 1;
        lua_insert(L, 1);
        lua_pcall(L, nargs, LUA_MULTRET, 0);
        return lua_gettop(L);
    }, 1);
    return 1;
}

static int iscclosure_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, lua_iscfunction(L, 1));
    return 1;
}

static int islclosure_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    lua_pushboolean(L, !lua_iscfunction(L, 1));
    return 1;
}

static int isexecutorclosure_impl(lua_State* L) {
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

static int hookfunction_impl(lua_State* L) {
    if (!lua_isfunction(L, 1) || !lua_isfunction(L, 2)) {
        luaL_error(L, "expected two functions");
    }
    Closure* target = (Closure*)lua_topointer(L, 1);
    Closure* hook = (Closure*)lua_topointer(L, 2);
    if (target && hook) {
        vm_protect((vm_address_t)target, sizeof(Closure), VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        if (target->isC) {
            target->c.f = hook->c.f;
        } else {
            target->l.p = hook->l.p;
        }
        vm_protect((vm_address_t)target, sizeof(Closure), VM_PROT_READ | VM_PROT_EXECUTE);
    }
    lua_pushvalue(L, 2);
    return 1;
}

static int getnamecallmethod_impl(lua_State* L) {
    const char* method = lua_namecallatom(L, nullptr);
    lua_pushstring(L, method ? method : "");
    return 1;
}

static int setnamecallmethod_impl(lua_State* L) {
    if (lua_gettop(L) < 1) return 0;
    lua_setfield(L, LUA_REGISTRYINDEX, "xzx_namecall");
    return 0;
}

static int getrawmetatable_impl(lua_State* L) {
    if (!lua_getmetatable(L, 1)) {
        lua_pushnil(L);
    }
    return 1;
}

static int setrawmetatable_impl(lua_State* L) {
    if (lua_istable(L, 1) && (lua_istable(L, 2) || lua_isnil(L, 2))) {
        lua_pushvalue(L, 2);
        lua_setmetatable(L, 1);
    }
    lua_settop(L, 1);
    return 1;
}

static int setclipboard_impl(lua_State* L) {
    const char* text = luaL_checkstring(L, 1);
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIPasteboard generalPasteboard].string = [NSString stringWithUTF8String:text];
    });
    return 0;
}

static int getclipboard_impl(lua_State* L) {
    NSString* text = [UIPasteboard generalPasteboard].string;
    lua_pushstring(L, text ? [text UTF8String] : "");
    return 1;
}

static int identifyexecutor_impl(lua_State* L) {
    lua_pushstring(L, "XZX");
    return 1;
}

static int getexecutorname_impl(lua_State* L) {
    lua_pushstring(L, "XZX");
    return 1;
}

static int checkcaller_impl(lua_State* L) {
    lua_pushboolean(L, 1);
    return 1;
}

static int getthreadidentity_impl(lua_State* L) {
    auto it = thread_identities.find(L);
    lua_pushinteger(L, it != thread_identities.end() ? it->second : 8);
    return 1;
}

static int setthreadidentity_impl(lua_State* L) {
    int identity = luaL_checkinteger(L, 1);
    thread_identities[L] = identity;
    return 0;
}

static int getfpscap_impl(lua_State* L) {
    lua_pushinteger(L, 60);
    return 1;
}

static int setfpscap_impl(lua_State* L) {
    return 0;
}

static int isrbxactive_impl(lua_State* L) {
    lua_pushboolean(L, get_roblox_lua_state() != nullptr);
    return 1;
}

static int gethui_impl(lua_State* L) {
    uintptr_t datamodel = get_datamodel_ptr();
    if (datamodel) {
        uintptr_t coregui = datamodel + 0x30;
        coregui = *(uintptr_t*)coregui;
        if (coregui) {
            lua_pushlightuserdata(L, (void*)coregui);
            return 1;
        }
    }
    lua_newtable(L);
    return 1;
}

static void enumerate_children(lua_State* L, uintptr_t instance, int table_idx) {
    uintptr_t children_ptr = instance + 0x28;
    uintptr_t children = *(uintptr_t*)children_ptr;
    if (!children) return;
    uintptr_t* list = (uintptr_t*)(children + 0x10);
    for (int i = 0; list[i] != 0; i++) {
        lua_pushinteger(L, lua_rawlen(L, table_idx) + 1);
        lua_pushlightuserdata(L, (void*)list[i]);
        lua_settable(L, table_idx);
        enumerate_children(L, list[i], table_idx);
    }
}

static int getinstances_impl(lua_State* L) {
    lua_newtable(L);
    int table_idx = lua_gettop(L);
    uintptr_t datamodel = get_datamodel_ptr();
    if (datamodel) {
        enumerate_children(L, datamodel, table_idx);
    }
    return 1;
}

static int getnilinstances_impl(lua_State* L) {
    lua_newtable(L);
    return 1;
}

static int getscripts_impl(lua_State* L) {
    lua_newtable(L);
    return 1;
}

static int getloadedmodules_impl(lua_State* L) {
    lua_newtable(L);
    return 1;
}

static int debug_getregistry_impl(lua_State* L) {
    lua_pushvalue(L, LUA_REGISTRYINDEX);
    return 1;
}

static int debug_getupvalue_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) {
        lua_pushnil(L);
        return 1;
    }
    int index = luaL_checkinteger(L, 2);
    const char* name = lua_getupvalue(L, 1, index);
    if (name) {
        lua_pushstring(L, name);
        lua_insert(L, -2);
        return 2;
    }
    lua_pushnil(L);
    return 1;
}

static int debug_setupvalue_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) return 0;
    int index = luaL_checkinteger(L, 2);
    lua_pushvalue(L, 3);
    const char* name = lua_setupvalue(L, 1, index);
    lua_pushstring(L, name ? name : "");
    return 1;
}

static int debug_getconstants_impl(lua_State* L) {
    Proto* p = get_proto(L, 1);
    if (!p) {
        lua_pushnil(L);
        return 1;
    }
    lua_newtable(L);
    TValue* k = (TValue*)p->k;
    for (int i = 0; i < p->sizek; i++) {
        lua_pushinteger(L, i + 1);
        switch (k[i].tt) {
            case LUA_TNUMBER: lua_pushnumber(L, k[i].value.n); break;
            case LUA_TSTRING: lua_pushstring(L, (char*)k[i].value.p); break;
            case LUA_TBOOLEAN: lua_pushboolean(L, k[i].value.b); break;
            default: lua_pushnil(L);
        }
        lua_settable(L, -3);
    }
    return 1;
}

static int debug_setconstants_impl(lua_State* L) {
    Proto* p = get_proto(L, 1);
    if (!p || !lua_istable(L, 2)) return 0;
    TValue* k = (TValue*)p->k;
    vm_protect((vm_address_t)k, p->sizek * sizeof(TValue), VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    for (int i = 1; i <= p->sizek; i++) {
        lua_pushinteger(L, i);
        lua_gettable(L, 2);
        if (lua_isnumber(L, -1)) {
            k[i-1].tt = LUA_TNUMBER;
            k[i-1].value.n = lua_tonumber(L, -1);
        } else if (lua_isstring(L, -1)) {
            k[i-1].tt = LUA_TSTRING;
            k[i-1].value.p = (void*)strdup(lua_tostring(L, -1));
        } else if (lua_isboolean(L, -1)) {
            k[i-1].tt = LUA_TBOOLEAN;
            k[i-1].value.b = lua_toboolean(L, -1);
        }
        lua_pop(L, 1);
    }
    vm_protect((vm_address_t)k, p->sizek * sizeof(TValue), VM_PROT_READ | VM_PROT_EXECUTE);
    return 0;
}

static int debug_getproto_impl(lua_State* L) {
    Proto* p = get_proto(L, 1);
    if (!p) {
        lua_pushnil(L);
        return 1;
    }
    int index = luaL_optinteger(L, 2, 1) - 1;
    if (index >= 0 && index < p->sizep) {
        lua_pushlightuserdata(L, p->p[index]);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

static int debug_getstack_impl(lua_State* L) {
    int level = luaL_checkinteger(L, 1);
    lua_Debug ar;
    if (lua_getstack(L, level, &ar)) {
        lua_getinfo(L, "Sl", &ar);
        lua_newtable(L);
        lua_pushstring(L, "source"); lua_pushstring(L, ar.source); lua_settable(L, -3);
        lua_pushstring(L, "linedefined"); lua_pushinteger(L, ar.linedefined); lua_settable(L, -3);
        lua_pushstring(L, "currentline"); lua_pushinteger(L, ar.currentline); lua_settable(L, -3);
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

static int debug_traceback_impl(lua_State* L) {
    luaL_traceback(L, L, nullptr, 0);
    return 1;
}

static int getcallingscript_impl(lua_State* L) {
    lua_Debug ar;
    if (lua_getstack(L, 2, &ar)) {
        lua_getinfo(L, "f", &ar);
        lua_getfenv(L, -1);
        lua_getfield(L, -1, "script");
        if (!lua_isnil(L, -1)) {
            lua_remove(L, -2);
            lua_remove(L, -2);
            return 1;
        }
        lua_pop(L, 2);
    }
    lua_pushnil(L);
    return 1;
}

static int getscriptbytecode_impl(lua_State* L) {
    lua_pushnil(L);
    return 1;
}

static int getscriptclosure_impl(lua_State* L) {
    lua_pushnil(L);
    return 1;
}

static int fireclickdetector_impl(lua_State* L) {
    return 0;
}

static int firetouchinterest_impl(lua_State* L) {
    return 0;
}

static int fireproximityprompt_impl(lua_State* L) {
    return 0;
}

static int gethiddenproperty_impl(lua_State* L) {
    lua_pushnil(L);
    return 1;
}

static int sethiddenproperty_impl(lua_State* L) {
    return 0;
}

static int compareinstances_impl(lua_State* L) {
    if (!lua_isuserdata(L, 1) || !lua_isuserdata(L, 2)) {
        lua_pushboolean(L, 0);
        return 1;
    }
    void* a = lua_touserdata(L, 1);
    void* b = lua_touserdata(L, 2);
    lua_pushboolean(L, a == b);
    return 1;
}

static int crypt_encrypt_impl(lua_State* L) {
    const char* data = luaL_checkstring(L, 1);
    const char* key = luaL_optstring(L, 2, "xzx");
    NSMutableString* result = [NSMutableString string];
    size_t data_len = strlen(data);
    size_t key_len = strlen(key);
    for (size_t i = 0; i < data_len; i++) {
        char c = data[i] ^ key[i % key_len];
        [result appendFormat:@"%c", c];
    }
    lua_pushstring(L, [result UTF8String]);
    return 1;
}

static int crypt_decrypt_impl(lua_State* L) {
    return crypt_encrypt_impl(L);
}

static int crypt_hash_impl(lua_State* L) {
    const char* data = luaL_checkstring(L, 1);
    const char* algorithm = luaL_optstring(L, 2, "sha256");
    NSData* nsdata = [NSData dataWithBytes:data length:strlen(data)];
    unsigned char hash[32];
    size_t hash_len = 32;
    if (strcmp(algorithm, "sha256") == 0) {
        CC_SHA256(nsdata.bytes, (CC_LONG)nsdata.length, hash);
    } else if (strcmp(algorithm, "sha1") == 0) {
        CC_SHA1(nsdata.bytes, (CC_LONG)nsdata.length, hash);
        hash_len = 20;
    } else if (strcmp(algorithm, "md5") == 0) {
        CC_MD5(nsdata.bytes, (CC_LONG)nsdata.length, hash);
        hash_len = 16;
    }
    NSMutableString* result = [NSMutableString string];
    for (size_t i = 0; i < hash_len; i++) {
        [result appendFormat:@"%02x", hash[i]];
    }
    lua_pushstring(L, [result UTF8String]);
    return 1;
}

static int websocket_new_impl(lua_State* L) {
    const char* url = luaL_checkstring(L, 1);
    int ws_id = next_callback_id++;
    NSURLSession* session = [NSURLSession sharedSession];
    NSURLSessionWebSocketTask* task = [session webSocketTaskWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]];
    [task resume];
    callbacks[ws_id] = [task](lua_State* L) {
        [task cancel];
    };
    lua_newtable(L);
    lua_pushstring(L, "send");
    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_pushstring(L, "__id");
        lua_gettable(L, 1);
        int id = lua_tointeger(L, -1);
        const char* data = luaL_checkstring(L, 2);
        NSURLSessionWebSocketTask* task = (__bridge NSURLSessionWebSocketTask*)(void*)id;
        [task sendMessage:[[NSURLSessionWebSocketMessage alloc] initWithString:[NSString stringWithUTF8String:data]] completionHandler:^(NSError* error) {}];
        return 0;
    });
    lua_settable(L, -3);
    lua_pushstring(L, "close");
    lua_pushcfunction(L, [](lua_State* L) -> int {
        lua_pushstring(L, "__id");
        lua_gettable(L, 1);
        int id = lua_tointeger(L, -1);
        auto it = callbacks.find(id);
        if (it != callbacks.end()) {
            it->second(L);
            callbacks.erase(it);
        }
        return 0;
    });
    lua_settable(L, -3);
    lua_pushstring(L, "__id");
    lua_pushinteger(L, ws_id);
    lua_settable(L, -3);
    return 1;
}

static int request_impl(lua_State* L) {
    if (!lua_istable(L, 1)) {
        luaL_error(L, "expected table");
    }
    lua_getfield(L, 1, "Url");
    const char* url = lua_tostring(L, -1);
    lua_getfield(L, 1, "Method");
    const char* method = lua_tostring(L, -1);
    if (!method) method = "GET";
    lua_getfield(L, 1, "Headers");
    lua_getfield(L, 1, "Body");
    const char* body = lua_tostring(L, -1);
    if (strcmp(method, "GET") == 0) {
        return httpget_impl(L);
    }
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString* result = nil;
    NSMutableURLRequest* request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithUTF8String:url]]];
    [request setHTTPMethod:[NSString stringWithUTF8String:method]];
    if (body) {
        [request setHTTPBody:[[NSString stringWithUTF8String:body] dataUsingEncoding:NSUTF8StringEncoding]];
    }
    NSURLSessionDataTask* task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData* data, NSURLResponse* response, NSError* error) {
        if (data) {
            result = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        }
        dispatch_semaphore_signal(semaphore);
    }];
    [task resume];
    dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 10 * NSEC_PER_SEC));
    if (result) {
        lua_pushstring(L, [result UTF8String]);
        return 1;
    }
    lua_pushnil(L);
    return 1;
}

static int readfile_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    NSError* error = nil;
    NSString* content = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
    if (error) {
        lua_pushnil(L);
        lua_pushstring(L, [[error localizedDescription] UTF8String]);
        return 2;
    }
    lua_pushstring(L, [content UTF8String]);
    return 1;
}

static int writefile_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    const char* data = luaL_checkstring(L, 2);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    NSError* error = nil;
    [[NSString stringWithUTF8String:data] writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    lua_pushboolean(L, error == nil);
    return 1;
}

static int appendfile_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    const char* data = luaL_checkstring(L, 2);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    NSFileHandle* file = [NSFileHandle fileHandleForWritingAtPath:filePath];
    if (file) {
        [file seekToEndOfFile];
        [file writeData:[[NSString stringWithUTF8String:data] dataUsingEncoding:NSUTF8StringEncoding]];
        [file closeFile];
        lua_pushboolean(L, 1);
    } else {
        lua_pushboolean(L, 0);
    }
    return 1;
}

static int listfiles_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    NSString* dirPath = [NSString stringWithUTF8String:path];
    if (![dirPath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        dirPath = [docPath stringByAppendingPathComponent:dirPath];
    }
    NSError* error = nil;
    NSArray* files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirPath error:&error];
    if (error) {
        lua_pushnil(L);
        lua_pushstring(L, [[error localizedDescription] UTF8String]);
        return 2;
    }
    lua_newtable(L);
    for (int i = 0; i < files.count; i++) {
        lua_pushinteger(L, i + 1);
        lua_pushstring(L, [files[i] UTF8String]);
        lua_settable(L, -3);
    }
    return 1;
}

static int isfile_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir];
    lua_pushboolean(L, exists && !isDir);
    return 1;
}

static int isfolder_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    BOOL isDir = NO;
    BOOL exists = [[NSFileManager defaultManager] fileExistsAtPath:filePath isDirectory:&isDir];
    lua_pushboolean(L, exists && isDir);
    return 1;
}

static int makefolder_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    NSError* error = nil;
    [[NSFileManager defaultManager] createDirectoryAtPath:filePath withIntermediateDirectories:YES attributes:nil error:&error];
    lua_pushboolean(L, error == nil);
    return 1;
}

static int delfile_impl(lua_State* L) {
    const char* path = luaL_checkstring(L, 1);
    NSString* filePath = [NSString stringWithUTF8String:path];
    if (![filePath isAbsolutePath]) {
        NSArray* paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString* docPath = paths.firstObject;
        filePath = [docPath stringByAppendingPathComponent:filePath];
    }
    NSError* error = nil;
    [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
    lua_pushboolean(L, error == nil);
    return 1;
}

static int compress_impl(lua_State* L) {
    const char* data = luaL_checkstring(L, 1);
    uLong source_len = strlen(data);
    uLong dest_len = compressBound(source_len);
    Bytef* dest = (Bytef*)malloc(dest_len);
    if (compress(dest, &dest_len, (const Bytef*)data, source_len) != Z_OK) {
        free(dest);
        lua_pushnil(L);
        return 1;
    }
    lua_pushlstring(L, (const char*)dest, dest_len);
    free(dest);
    return 1;
}

static int decompress_impl(lua_State* L) {
    const char* data = luaL_checkstring(L, 1);
    size_t source_len = lua_objlen(L, 1);
    uLong dest_len = source_len * 4;
    Bytef* dest = (Bytef*)malloc(dest_len);
    if (uncompress(dest, &dest_len, (const Bytef*)data, source_len) != Z_OK) {
        free(dest);
        lua_pushnil(L);
        return 1;
    }
    lua_pushlstring(L, (const char*)dest, dest_len);
    free(dest);
    return 1;
}

static int delay_impl(lua_State* L) {
    double seconds = luaL_checknumber(L, 1);
    if (!lua_isfunction(L, 2)) {
        luaL_error(L, "expected function");
    }
    lua_pushvalue(L, 2);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(seconds * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        lua_rawgeti(main_lua_state, LUA_REGISTRYINDEX, ref);
        lua_pcall(main_lua_state, 0, 0, 0);
        luaL_unref(main_lua_state, LUA_REGISTRYINDEX, ref);
    });
    return 0;
}

static int spawn_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) {
        luaL_error(L, "expected function");
    }
    lua_pushvalue(L, 1);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        lua_rawgeti(main_lua_state, LUA_REGISTRYINDEX, ref);
        lua_pcall(main_lua_state, 0, 0, 0);
        luaL_unref(main_lua_state, LUA_REGISTRYINDEX, ref);
    });
    return 0;
}

static int task_spawn_impl(lua_State* L) {
    return spawn_impl(L);
}

static int task_delay_impl(lua_State* L) {
    return delay_impl(L);
}

static int task_wait_impl(lua_State* L) {
    double seconds = luaL_optnumber(L, 1, 0);
    usleep(seconds * 1000000);
    return 0;
}

static int task_defer_impl(lua_State* L) {
    if (!lua_isfunction(L, 1)) {
        luaL_error(L, "expected function");
    }
    lua_pushvalue(L, 1);
    int ref = luaL_ref(L, LUA_REGISTRYINDEX);
    dispatch_async(dispatch_get_main_queue(), ^{
        lua_rawgeti(main_lua_state, LUA_REGISTRYINDEX, ref);
        lua_pcall(main_lua_state, 0, 0, 0);
        luaL_unref(main_lua_state, LUA_REGISTRYINDEX, ref);
    });
    return 0;
}

static int messagebox_impl(lua_State* L) {
    const char* text = luaL_checkstring(L, 1);
    const char* caption = luaL_optstring(L, 2, "XZX");
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:[NSString stringWithUTF8String:caption]
                                                                       message:[NSString stringWithUTF8String:text]
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        UIViewController* rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
    return 0;
}

extern "C" void InitLua(void) {
    std::lock_guard<std::mutex> lock(lua_mutex);
    if (!main_lua_state) {
        lua_State* roblox_lua = get_roblox_lua_state();
        if (roblox_lua) {
            main_lua_state = roblox_lua;
        } else {
            main_lua_state = luaL_newstate();
            luaL_openlibs(main_lua_state);
        }
        scan_roblox_memory();
        lua_register(main_lua_state, "print", print_impl);
        lua_register(main_lua_state, "warn", warn_impl);
        lua_register(main_lua_state, "error", error_impl);
        lua_register(main_lua_state, "loadstring", loadstring_impl);
        lua_register(main_lua_state, "HttpGet", httpget_impl);
        lua_register(main_lua_state, "game_HttpGet", httpget_impl);
        lua_register(main_lua_state, "base64encode", base64_encode);
        lua_register(main_lua_state, "base64decode", base64_decode);
        lua_register(main_lua_state, "base64codes", base64codes);
        lua_register(main_lua_state, "getgenv", getgenv_impl);
        lua_register(main_lua_state, "getrenv", getrenv_impl);
        lua_register(main_lua_state, "getreg", getreg_impl);
        lua_register(main_lua_state, "getgc", getgc_impl);
        lua_register(main_lua_state, "getinstances", getinstances_impl);
        lua_register(main_lua_state, "getnilinstances", getnilinstances_impl);
        lua_register(main_lua_state, "getscripts", getscripts_impl);
        lua_register(main_lua_state, "getloadedmodules", getloadedmodules_impl);
        lua_register(main_lua_state, "gethui", gethui_impl);
        lua_register(main_lua_state, "newcclosure", newcclosure_impl);
        lua_register(main_lua_state, "iscclosure", iscclosure_impl);
        lua_register(main_lua_state, "islclosure", islclosure_impl);
        lua_register(main_lua_state, "isexecutorclosure", isexecutorclosure_impl);
        lua_register(main_lua_state, "hookfunction", hookfunction_impl);
        lua_register(main_lua_state, "clonefunction", hookfunction_impl);
        lua_register(main_lua_state, "getnamecallmethod", getnamecallmethod_impl);
        lua_register(main_lua_state, "setnamecallmethod", setnamecallmethod_impl);
        lua_register(main_lua_state, "getrawmetatable", getrawmetatable_impl);
        lua_register(main_lua_state, "setrawmetatable", setrawmetatable_impl);
        lua_register(main_lua_state, "setclipboard", setclipboard_impl);
        lua_register(main_lua_state, "getclipboard", getclipboard_impl);
        lua_register(main_lua_state, "identifyexecutor", identifyexecutor_impl);
        lua_register(main_lua_state, "getexecutorname", getexecutorname_impl);
        lua_register(main_lua_state, "checkcaller", checkcaller_impl);
        lua_register(main_lua_state, "getthreadidentity", getthreadidentity_impl);
        lua_register(main_lua_state, "setthreadidentity", setthreadidentity_impl);
        lua_register(main_lua_state, "getthreadcontext", getthreadidentity_impl);
        lua_register(main_lua_state, "setthreadcontext", setthreadidentity_impl);
        lua_register(main_lua_state, "getfpscap", getfpscap_impl);
        lua_register(main_lua_state, "setfpscap", setfpscap_impl);
        lua_register(main_lua_state, "isrbxactive", isrbxactive_impl);
        lua_register(main_lua_state, "getcallingscript", getcallingscript_impl);
        lua_register(main_lua_state, "getscriptbytecode", getscriptbytecode_impl);
        lua_register(main_lua_state, "getscriptclosure", getscriptclosure_impl);
        lua_register(main_lua_state, "getscriptfunction", getscriptclosure_impl);
        lua_register(main_lua_state, "fireclickdetector", fireclickdetector_impl);
        lua_register(main_lua_state, "firetouchinterest", firetouchinterest_impl);
        lua_register(main_lua_state, "fireproximityprompt", fireproximityprompt_impl);
        lua_register(main_lua_state, "gethiddenproperty", gethiddenproperty_impl);
        lua_register(main_lua_state, "sethiddenproperty", sethiddenproperty_impl);
        lua_register(main_lua_state, "compareinstances", compareinstances_impl);
        lua_newtable(main_lua_state);
        lua_pushcfunction(main_lua_state, crypt_encrypt_impl);
        lua_setfield(main_lua_state, -2, "encrypt");
        lua_pushcfunction(main_lua_state, crypt_decrypt_impl);
        lua_setfield(main_lua_state, -2, "decrypt");
        lua_pushcfunction(main_lua_state, crypt_hash_impl);
        lua_setfield(main_lua_state, -2, "hash");
        lua_pushcfunction(main_lua_state, base64_encode);
        lua_setfield(main_lua_state, -2, "base64_encode");
        lua_pushcfunction(main_lua_state, base64_decode);
        lua_setfield(main_lua_state, -2, "base64_decode");
        lua_setglobal(main_lua_state, "crypt");
        lua_newtable(main_lua_state);
        lua_pushcfunction(main_lua_state, websocket_new_impl);
        lua_setfield(main_lua_state, -2, "new");
        lua_setglobal(main_lua_state, "WebSocket");
        lua_newtable(main_lua_state);
        lua_pushcfunction(main_lua_state, debug_getregistry_impl);
        lua_setfield(main_lua_state, -2, "getregistry");
        lua_pushcfunction(main_lua_state, debug_getupvalue_impl);
        lua_setfield(main_lua_state, -2, "getupvalue");
        lua_pushcfunction(main_lua_state, debug_setupvalue_impl);
        lua_setfield(main_lua_state, -2, "setupvalue");
        lua_pushcfunction(main_lua_state, debug_getconstants_impl);
        lua_setfield(main_lua_state, -2, "getconstants");
        lua_pushcfunction(main_lua_state, debug_setconstants_impl);
        lua_setfield(main_lua_state, -2, "setconstants");
        lua_pushcfunction(main_lua_state, debug_getproto_impl);
        lua_setfield(main_lua_state, -2, "getproto");
        lua_pushcfunction(main_lua_state, debug_getstack_impl);
        lua_setfield(main_lua_state, -2, "getstack");
        lua_pushcfunction(main_lua_state, debug_traceback_impl);
        lua_setfield(main_lua_state, -2, "traceback");
        lua_setglobal(main_lua_state, "debug");
        lua_register(main_lua_state, "request", request_impl);
        lua_register(main_lua_state, "readfile", readfile_impl);
        lua_register(main_lua_state, "writefile", writefile_impl);
        lua_register(main_lua_state, "appendfile", appendfile_impl);
        lua_register(main_lua_state, "listfiles", listfiles_impl);
        lua_register(main_lua_state, "isfile", isfile_impl);
        lua_register(main_lua_state, "isfolder", isfolder_impl);
        lua_register(main_lua_state, "makefolder", makefolder_impl);
        lua_register(main_lua_state, "delfile", delfile_impl);
        lua_register(main_lua_state, "compress", compress_impl);
        lua_register(main_lua_state, "decompress", decompress_impl);
        lua_register(main_lua_state, "delay", delay_impl);
        lua_register(main_lua_state, "spawn", spawn_impl);
        lua_newtable(main_lua_state);
        lua_pushcfunction(main_lua_state, task_spawn_impl);
        lua_setfield(main_lua_state, -2, "spawn");
        lua_pushcfunction(main_lua_state, task_delay_impl);
        lua_setfield(main_lua_state, -2, "delay");
        lua_pushcfunction(main_lua_state, task_wait_impl);
        lua_setfield(main_lua_state, -2, "wait");
        lua_pushcfunction(main_lua_state, task_defer_impl);
        lua_setfield(main_lua_state, -2, "defer");
        lua_setglobal(main_lua_state, "task");
        lua_register(main_lua_state, "messagebox", messagebox_impl);
        lua_newtable(main_lua_state);
        lua_pushstring(main_lua_state, "XZX");
        lua_setfield(main_lua_state, -2, "name");
        lua_pushstring(main_lua_state, "3.0.0");
        lua_setfield(main_lua_state, -2, "version");
        lua_pushnumber(main_lua_state, 98);
        lua_setfield(main_lua_state, -2, "unc");
        lua_pushnumber(main_lua_state, 95);
        lua_setfield(main_lua_state, -2, "sunc");
        lua_setglobal(main_lua_state, "xzx");
    }
}

extern "C" void ExecuteScript(const char* script) {
    std::lock_guard<std::mutex> lock(lua_mutex);
    if (!main_lua_state) InitLua();
    int old_identity = getthreadidentity_impl(main_lua_state);
    setthreadidentity_impl(main_lua_state, 8);
    lua_State* thread = lua_newthread(main_lua_state);
    int threadRef = luaL_ref(main_lua_state, LUA_REGISTRYINDEX);
    int status = luaL_loadstring(thread, script);
    if (status != 0) {
        const char* error = lua_tostring(thread, -1);
        NSLog(@"[XZX] Error: %s", error);
        luaL_unref(main_lua_state, LUA_REGISTRYINDEX, threadRef);
        setthreadidentity_impl(main_lua_state, old_identity);
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        lua_rawgeti(main_lua_state, LUA_REGISTRYINDEX, threadRef);
        lua_State* exec_thread = lua_tothread(main_lua_state, -1);
        if (exec_thread) {
            int result = lua_pcall(exec_thread, 0, 0, 0);
            if (result != 0) {
                const char* error = lua_tostring(exec_thread, -1);
                NSLog(@"[XZX] Execution error: %s", error);
            }
        }
        luaL_unref(main_lua_state, LUA_REGISTRYINDEX, threadRef);
    });
    setthreadidentity_impl(main_lua_state, old_identity);
}
