#import "xzx_core.h"
#import "xzx_antidetection.h"
#import "xzx_ban_protection.h"
#import "xzx_injection_randomizer.h"
#import "xzx_hook_manager.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <mach/mach.h>
#import <mach-o/dyld.h>

static XZXCore *sharedCoreInstance = nil;
static uintptr_t roblox_base = 0;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCoreInstance = [[self alloc] init];
    });
    return sharedCoreInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInGame = NO;
        _editorWindow = nil;
    }
    return self;
}

+ (void)load {
    // Don't do anything in +load - it's too early
    NSLog(@"[XZX] Library loaded");
}

- (void)initialize {
    NSLog(@"[XZX] Starting initialization...");
    
    @try {
        // Initialize each component safely with checks
        [self safeInitAntiDetection];
        [self safeInitBanProtection];
        [self safeInitInjectionRandomizer];
        [self safeInitHookManager];
        
        [self scanRobloxMemory];
        [self startGameStateMonitoring];
        
        // Initialize Lua last
        InitLua();
        
        NSLog(@"[XZX] All systems initialized");
        
    } @catch (NSException *exception) {
        NSLog(@"[XZX] INIT FAILED: %@", exception);
        NSLog(@"[XZX] Reason: %@", exception.reason);
    }
}

- (void)safeInitAntiDetection {
    @try {
        Class cls = NSClassFromString(@"XZXAntiDetection");
        if (cls && [cls respondsToSelector:@selector(shared)]) {
            id instance = [cls shared];
            if (instance && [instance respondsToSelector:@selector(initializeProtection)]) {
                [instance initializeProtection];
                NSLog(@"[XZX] AntiDetection OK");
            } else {
                NSLog(@"[XZX] AntiDetection methods not found");
            }
        } else {
            NSLog(@"[XZX] AntiDetection class not found");
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] AntiDetection init failed: %@", e);
    }
}

- (void)safeInitBanProtection {
    @try {
        Class cls = NSClassFromString(@"XZXBanProtection");
        if (cls && [cls respondsToSelector:@selector(shared)]) {
            id instance = [cls shared];
            if (instance && [instance respondsToSelector:@selector(protectAccount)]) {
                [instance protectAccount];
                NSLog(@"[XZX] BanProtection OK");
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] BanProtection init failed: %@", e);
    }
}

- (void)safeInitInjectionRandomizer {
    @try {
        Class cls = NSClassFromString(@"XZXInjectionRandomizer");
        if (cls && [cls respondsToSelector:@selector(shared)]) {
            id instance = [cls shared];
            if (instance && [instance respondsToSelector:@selector(randomizeNextInjection)]) {
                [instance randomizeNextInjection];
                NSLog(@"[XZX] InjectionRandomizer OK");
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] InjectionRandomizer init failed: %@", e);
    }
}

- (void)safeInitHookManager {
    @try {
        Class cls = NSClassFromString(@"XZXHookManager");
        if (cls && [cls respondsToSelector:@selector(shared)]) {
            id instance = [cls shared];
            if (instance && [instance respondsToSelector:@selector(initializeHookSystem)]) {
                [instance initializeHookSystem];
                NSLog(@"[XZX] HookManager OK");
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] HookManager init failed: %@", e);
    }
}

- (void)scanRobloxMemory {
    @try {
        uint32_t count = _dyld_image_count();
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name && (strstr(name, "Roblox") || strstr(name, "RobloxPlayer"))) {
                roblox_base = (uintptr_t)_dyld_get_image_header(i);
                NSLog(@"[XZX] Found Roblox at: 0x%lx", (unsigned long)roblox_base);
                break;
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[XZX] Memory scan failed: %@", e);
    }
}

- (void)startGameStateMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            BOOL lastInGame = NO;
            while (YES) {
                @try {
                    BOOL currentlyInGame = [self checkIfInGame];
                    if (currentlyInGame && !lastInGame) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self onGameJoined];
                        });
                    } else if (!currentlyInGame && lastInGame) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self onGameLeft];
                        });
                    }
                    lastInGame = currentlyInGame;
                } @catch (NSException *e) {
                    NSLog(@"[XZX] Monitor error: %@", e);
                }
                [NSThread sleepForTimeInterval:1.0];
            }
        }
    });
}

- (BOOL)checkIfInGame {
    return YES;
}

- (void)onGameJoined {
    if (self.isInGame) return;
    self.isInGame = YES;
    NSLog(@"[XZX] Game joined");
    
    @try {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GameJoined" object:nil];
    } @catch (NSException *e) {
        NSLog(@"[XZX] Failed to post notification: %@", e);
    }
}

- (void)onGameLeft {
    self.isInGame = NO;
    NSLog(@"[XZX] Game left");
    
    @try {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"GameLeft" object:nil];
    } @catch (NSException *e) {
        NSLog(@"[XZX] Failed to post notification: %@", e);
    }
}

@end
