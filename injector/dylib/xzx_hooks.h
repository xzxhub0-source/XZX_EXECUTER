#ifndef XZX_HOOKS_H
#define XZX_HOOKS_H

#import <Foundation/Foundation.h>
#include <lua.h>

void hook_roblox_functions(void);
void unhook_roblox_functions(void);
void install_hook(void *target, void *replacement, void **original);
void notify_game_joined(void);
bool isPlayerInGame(void);
lua_State* getRobloxLuaState(void);   // NEW
void setupRemoteEventBridge(void);    // NEW

#endif
