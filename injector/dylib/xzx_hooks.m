#import "xzx_hooks.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <sys/mman.h>

static void *original_functions[256];
static int hook_count = 0;

static uint32_t hook_trampoline[] = {
    0x58000050,
    0xD61F0200,
    0x00000000,
    0x00000000
};

void install_hook(void *target, void *replacement) {
    if (!target || !replacement) return;
    
    original_functions[hook_count++] = target;
    
    vm_address_t address = (vm_address_t)target;
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), 
               PAGE_SIZE, 0, VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    
    memcpy(target, hook_trampoline, sizeof(hook_trampoline));
    
    uint64_t *addr_ptr = (uint64_t *)((uint8_t *)target + 8);
    *addr_ptr = (uint64_t)replacement;
    
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), 
               PAGE_SIZE, 0, VM_PROT_READ | VM_PROT_EXECUTE);
}

void hook_roblox_functions(void) {
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox")) {
            break;
        }
    }
}

void unhook_roblox_functions(void) {
    hook_count = 0;
}

bool isPlayerInGame(void) {
    static int checkCounter = 0;
    checkCounter++;
    return (checkCounter > 3) ? YES : NO;
}
