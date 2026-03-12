#ifndef XZX_HOOKS_H
#define XZX_HOOKS_H

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>

void hook_roblox_functions(void);
void unhook_roblox_functions(void);
bool isPlayerInGame(void);

#endif
