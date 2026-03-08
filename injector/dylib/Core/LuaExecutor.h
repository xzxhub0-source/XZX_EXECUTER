#ifndef LuaExecutor_h
#define LuaExecutor_h

#ifdef __cplusplus
extern "C" {
#endif

void InitLua(void);
void ExecuteScript(const char *script);

#ifdef __cplusplus
}
#endif

#endif
