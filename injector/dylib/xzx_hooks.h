#ifndef XZX_HOOKS_H
#define XZX_HOOKS_H

#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <mach/mach.h>

void hook_roblox_functions(void);
void unhook_roblox_functions(void);
void install_hook(void *target, void *replacement);
bool isPlayerInGame(void);
uintptr_t get_datamodel_address(void);

#endif
