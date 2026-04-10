#ifndef LuaExecutor_h
#define LuaExecutor_h

struct lua_State;

#ifdef __cplusplus
extern "C" {
#endif

void InitLua(void);
void ExecuteScript(const char *script);
void RegisterFunction(const char *name, int (*func)(struct lua_State*));
struct lua_State* GetLuaState(void);  // NEW: expose Lua state for hooks

#ifdef __cplusplus
}
#endif

#endif
