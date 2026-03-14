#ifndef LuaExecutor_h
#define LuaExecutor_h

#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

void InitLua(void);
void ExecuteScript(NSString *script);
void RegisterXZXFunctions(void);

#ifdef __cplusplus
}
#endif

#endif
