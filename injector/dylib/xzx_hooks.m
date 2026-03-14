#import "xzx_hooks.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <Foundation/Foundation.h>

static BOOL isPlayerInGameState = NO;
static NSTimer *gameStateTimer = nil;

void hook_roblox_functions(void) {
    // DO NOT use vm_protect or any memory modification
    // DO NOT attempt to hook C functions directly
    
    // Use ONLY Objective-C runtime swizzling - this is SAFE
    
    Class dataModelClass = NSClassFromString(@"RobloxDataModel");
    if (!dataModelClass) return;
    
    SEL originalSel = NSSelectorFromString(@"placeId");
    SEL swizzledSel = NSSelectorFromString(@"xzx_placeId");
    
    Method originalMethod = class_getInstanceMethod(dataModelClass, originalSel);
    if (!originalMethod) return;
    
    IMP swizzledImp = imp_implementationWithBlock(^id(id self) {
        isPlayerInGameState = YES;
        
        struct objc_super super = {
            .receiver = self,
            .super_class = class_getSuperclass(dataModelClass)
        };
        return ((id(*)(struct objc_super*, SEL))objc_msgSendSuper)(&super, originalSel);
    });
    
    BOOL added = class_addMethod(dataModelClass, swizzledSel, swizzledImp, method_getTypeEncoding(originalMethod));
    
    if (added) {
        Method swizzledMethod = class_getInstanceMethod(dataModelClass, swizzledSel);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

void unhook_roblox_functions(void) {
    // No need to unhook - let it be
}

BOOL isPlayerInGame(void) {
    return isPlayerInGameState;
}

// Safe way to check game state without memory hooks
void startGameStatePolling(void) {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        while (YES) {
            @autoreleasepool {
                Class dataModelClass = NSClassFromString(@"RobloxDataModel");
                if (dataModelClass) {
                    id dataModel = [dataModelClass performSelector:NSSelectorFromString(@"sharedDataModel")];
                    if (dataModel) {
                        id placeId = [dataModel performSelector:NSSelectorFromString(@"placeId")];
                        isPlayerInGameState = (placeId != nil);
                    } else {
                        isPlayerInGameState = NO;
                    }
                } else {
                    isPlayerInGameState = NO;
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}
