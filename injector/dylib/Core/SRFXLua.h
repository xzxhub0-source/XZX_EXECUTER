#ifndef SRFXLua_h
#define SRFXLua_h

struct lua_State;

#ifdef __cplusplus
extern "C" {
#endif

void SRFXLuaInit(void);
void SRFXLuaExecute(const char *script);
void SRFXLuaRegister(const char *name, int (*func)(struct lua_State*));
struct lua_State* SRFXLuaState(void);

#ifdef __cplusplus
}
#endif

#endif
