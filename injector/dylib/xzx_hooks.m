#import "xzx_hooks.h"
#import "xzx_core.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void* original_functions[256];
static int hook_count = 0;

typedef void (*TaskSchedulerHook)(void*, void*);
static TaskSchedulerHook original_task_scheduler = NULL;

void hook_task_scheduler(void* scheduler, void* task) {
    notify_game_joined();
    if (original_task_scheduler) {
        original_task_scheduler(scheduler, task);
    }
}

void install_hook(void* target, void* replacement, void** original) {
    if (!target || !replacement) return;
    
    if (original) {
        *original = target;
    }
    
    original_functions[hook_count++] = target;
    
    vm_address_t address = (vm_address_t)target;
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), 
               PAGE_SIZE, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    
    uint32_t branch_instruction = 0x14000000 | 
        (((uint32_t)((uintptr_t)replacement - (uintptr_t)target) >> 2) & 0x03FFFFFF);
    
    memcpy(target, &branch_instruction, 4);
    
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), 
               PAGE_SIZE, 0, VM_PROT_READ | VM_PROT_EXECUTE);
}

void hook_roblox_functions(void) {
    uint32_t count = _dyld_image_count();
    uintptr_t roblox_base = 0;
    
    for (uint32_t i = 0; i < count; i++) {
        const char* name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    
    if (!roblox_base) return;
    
    uintptr_t task_scheduler_addr = roblox_base + 0x12345678;
    install_hook((void*)task_scheduler_addr, hook_task_scheduler, 
                 (void**)&original_task_scheduler);
}

void unhook_roblox_functions(void) {
    for (int i = 0; i < hook_count; i++) {
        void* target = original_functions[i];
        vm_address_t address = (vm_address_t)target;
        vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), 
                   PAGE_SIZE, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
        
        uint32_t nop = 0xD503201F;
        memcpy(target, &nop, 4);
        
        vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), 
                   PAGE_SIZE, 0, VM_PROT_READ | VM_PROT_EXECUTE);
    }
    
    hook_count = 0;
}
