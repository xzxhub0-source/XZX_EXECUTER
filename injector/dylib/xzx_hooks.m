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
    NSArray *classNames = @[
        @"RBXDataModel",
        @"RobloxDataModel",
        @"DataModel",
        @"RBXGame",
        @"RobloxGame"
    ];

    Class dataModelClass = nil;
    for (NSString *name in classNames) {
        dataModelClass = NSClassFromString(name);
        if (dataModelClass) break;
    }
    if (!dataModelClass) return false;

    NSArray *sharedSelNames = @[@"sharedDataModel", @"shared", @"singleton", @"instance"];
    id dataModel = nil;
    for (NSString *selName in sharedSelNames) {
        SEL sel = NSSelectorFromString(selName);
        if ([dataModelClass respondsToSelector:sel]) {
            dataModel = ((id(*)(id, SEL))objc_msgSend)((id)dataModelClass, sel);
            if (dataModel) break;
        }
    }
    if (!dataModel) return false;

    NSArray *placeSelNames = @[@"placeId", @"PlaceId", @"currentPlaceId", @"gameId"];
    for (NSString *selName in placeSelNames) {
        SEL sel = NSSelectorFromString(selName);
        if ([dataModel respondsToSelector:sel]) {
            id placeId = ((id(*)(id, SEL))objc_msgSend)(dataModel, sel);
            if (placeId && [placeId intValue] != 0) return true;
        }
    }

    return false;
}
