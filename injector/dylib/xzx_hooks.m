#import "xzx_hooks.h"
#import "xzx_core.h"
#import <mach/mach.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>

static void *original_methods[128];
static int method_count = 0;
static uintptr_t roblox_base = 0;
static BOOL hooks_active = NO;

// FIX: was calling showOverlay without setting inGame = YES, so the monitor
// loop could never transition to "left game", and showOverlay's new guard
// would block it entirely.
void notify_game_joined(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        XZXCore *core = [XZXCore shared];
        if (!core.inGame) {
            core.inGame = YES;
            [core showOverlay];
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
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *name = _dyld_get_image_name(i);
        if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
            roblox_base = (uintptr_t)_dyld_get_image_header(i);
            break;
        }
    }
}

void unhook_roblox_functions(void) { hooks_active = NO; }

bool isPlayerInGame(void) {
    Class dataModelClass = NSClassFromString(@"RBXDataModel");
    if (!dataModelClass) dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (!dataModelClass) return false;

    SEL sharedSel = NSSelectorFromString(@"sharedDataModel");
    if (![dataModelClass respondsToSelector:sharedSel]) return false;

    id dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sharedSel);
    if (!dataModel) return false;

    SEL placeIdSel = NSSelectorFromString(@"placeId");
    if (![dataModel respondsToSelector:placeIdSel]) return false;

    id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, placeIdSel);
    return placeId && [placeId intValue] != 0;
}
