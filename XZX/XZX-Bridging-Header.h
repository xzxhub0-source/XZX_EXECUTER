#ifndef XZX_Bridging_Header_h
#define XZX_Bridging_Header_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Include Lua executor header - relative path from repository root
#include "injector/dylib/Core/LuaExecutor.h"

// C functions from LuaExecutor.mm
void InitLua(void);
void ExecuteScript(const char *script);

#endif
