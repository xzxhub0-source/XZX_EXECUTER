#import "xzx_hooks.h"
#import "xzx_core.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void *original_methods[128];
static int method_count = 0;
static BOOL hooks_active = NO;

void notify_game_joined(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (![[XZXCore shared] isInGame]) {
            [[XZXCore shared] showOverlay];
        }
    });
}

void install_hook(void *target, void *replacement, void **original) {
    if (!target || !replacement) return;
    if (original) *original = target;
    original_methods[method_count++] = target;

    vm_address_t address = (vm_address_t)target;
    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
               VM_PROT_READ | VM_PROT_WRITE | VM_PROT_EXECUTE);

    uint32_t branch = 0x14000000 |
        (((uint32_t)((uintptr_t)replacement - (uintptr_t)target) >> 2) & 0x03FFFFFF);
    memcpy(target, &branch, 4);
    __builtin___clear_cache((char *)target, (char *)target + 4);

    vm_protect(mach_task_self(), address & ~(PAGE_SIZE - 1), PAGE_SIZE, 0,
               VM_PROT_READ | VM_PROT_EXECUTE);
}

void hook_roblox_functions(void) {
    if (hooks_active) return;
    hooks_active = YES;
}

void unhook_roblox_functions(void) { hooks_active = NO; }

bool isPlayerInGame(void) {
    @try {
        NSArray *classNames = @[@"RobloxDataModel", @"RBXDataModel", @"DataModel"];
        Class dataModelClass = nil;
        for (NSString *name in classNames) {
            dataModelClass = NSClassFromString(name);
            if (dataModelClass) break;
        }
        if (!dataModelClass) return false;

        SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
        if (![dataModelClass respondsToSelector:sharedSel]) return false;
        id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
        if (!dataModel) return false;

        SEL placeIdSel = NSSelectorFromString(@"placeId");
        if (![dataModel respondsToSelector:placeIdSel]) return false;
        id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
        return (placeId && [placeId intValue] != 0);
    } @catch (NSException *e) {
        NSLog(@"[XZX] isPlayerInGame error: %@", e);
        return false;
    }
}
