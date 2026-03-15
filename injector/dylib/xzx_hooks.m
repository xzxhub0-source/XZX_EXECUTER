#import "xzx_hooks.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void *original_methods[128];
static int method_count = 0;
static uintptr_t roblox_base = 0;
static BOOL hooks_active = NO;

void install_hook(void *target, void *replacement, void **original) {
    if (!target || !replacement) return;
    
    if (original) {
        *original = target;
    }
    
    original_methods[method_count++] = target;
    
    vm_address_t address = (vm_address_t)target;
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0, 
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);
    
    uint32_t branch_instruction = 0x14000000 | 
        (((uint32_t)((uintptr_t)replacement - (uintptr_t)target) >> 2) & 0x03FFFFFF);
    
    memcpy(target, &branch_instruction, 4);
    
    __builtin___clear_cache((char *)target, (char *)target + 4);
    
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0, 
               VM_PROT_READ | VM_PROT_EXECUTE);
}

void hook_roblox_functions(void) {
    if (hooks_active) return;
    hooks_active = YES;
    
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
    
    if (!roblox_base) return;
    
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (dataModelClass) {
        SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
        Method originalMethod = class_getClassMethod(dataModelClass, sharedSel);
        if (originalMethod) {
            IMP originalImp = method_getImplementation(originalMethod);
            IMP hookImp = imp_implementationWithBlock(^id(void) {
                notify_game_joined();
                id (*originalFunc)(id, SEL) = (id(*)(id, SEL))originalImp;
                return originalFunc(dataModelClass, sharedSel);
            });
            method_setImplementation(originalMethod, hookImp);
        }
    }
    
    Class workspaceClass = NSClassFromString(@"RobloxWorkspace");
    if (workspaceClass) {
        SEL getSel = NSSelectorFromString(@"sharedWorkspace");
        Method originalMethod = class_getClassMethod(workspaceClass, getSel);
        if (originalMethod) {
            IMP originalImp = method_getImplementation(originalMethod);
            IMP hookImp = imp_implementationWithBlock(^id(void) {
                id (*originalFunc)(id, SEL) = (id(*)(id, SEL))originalImp;
                id workspace = originalFunc(workspaceClass, getSel);
                return workspace;
            });
            method_setImplementation(originalMethod, hookImp);
        }
    }
}

void unhook_roblox_functions(void) {
    hooks_active = NO;
}

bool isPlayerInGame(void) {
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (!dataModelClass) return NO;
    
    SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
    if (![dataModelClass respondsToSelector:sharedSel]) return NO;
    
    id dataModel = ((id(*)(id, SEL))objc_msgSend)(dataModelClass, sharedSel);
    if (!dataModel) return NO;
    
    SEL placeIdSel = NSSelectorFromString(@"placeId");
    if (![dataModel respondsToSelector:placeIdSel]) return NO;
    
    id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
    return (placeId != nil);
}

uintptr_t get_datamodel_address(void) {
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (!dataModelClass) return 0;
    
    SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
    if (![dataModelClass respondsToSelector:sharedSel]) return 0;
    
    id dataModel = ((id(*)(id, SEL))objc_msgSend)(dataModelClass, sharedSel);
    return (uintptr_t)dataModel;
}
