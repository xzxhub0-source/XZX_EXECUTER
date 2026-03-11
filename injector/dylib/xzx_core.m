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
static BOOL is_initialized = NO;

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
    NSLog(@"[XZX] Library loaded - delaying initialization");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), 
                   dispatch_get_main_queue(), ^{
        @try {
            NSLog(@"[XZX] Starting initialization...");
            [[XZXCore shared] initialize];
        } @catch (NSException *exception) {
            NSLog(@"[XZX] INITIALIZATION CRASH: %@", exception);
            NSLog(@"[XZX] Reason: %@", exception.reason);
            NSLog(@"[XZX] Stack: %@", exception.callStackSymbols);
        }
    });
}

- (void)initialize {
    NSLog(@"[XZX] initialize started");
    
    @try {
        // First verify we can access basic functionality
        NSLog(@"[XZX] Testing Objective-C runtime...");
        if (![NSObject class]) {
            NSLog(@"[XZX] CRITICAL: Objective-C runtime not available");
            return;
        }
        
        // Initialize components one by one with checks
        NSLog(@"[XZX] Initializing AntiDetection...");
        id antiDetection = [XZXAntiDetection shared];
        if (antiDetection) {
            [antiDetection initializeProtection];
            NSLog(@"[XZX] AntiDetection OK");
        } else {
            NSLog(@"[XZX] WARNING: AntiDetection returned nil");
        }
        
        NSLog(@"[XZX] Initializing BanProtection...");
        id banProtection = [XZXBanProtection shared];
        if (banProtection) {
            [banProtection protectAccount];
            NSLog(@"[XZX] BanProtection OK");
        } else {
            NSLog(@"[XZX] WARNING: BanProtection returned nil");
        }
        
        NSLog(@"[XZX] Initializing InjectionRandomizer...");
        id injectionRandomizer = [XZXInjectionRandomizer shared];
        if (injectionRandomizer) {
            [injectionRandomizer randomizeNextInjection];
            NSLog(@"[XZX] InjectionRandomizer OK");
        } else {
            NSLog(@"[XZX] WARNING: InjectionRandomizer returned nil");
        }
        
        NSLog(@"[XZX] Initializing HookManager...");
        id hookManager = [XZXHookManager shared];
        if (hookManager) {
            [hookManager initializeHookSystem];
            NSLog(@"[XZX] HookManager OK");
        } else {
            NSLog(@"[XZX] WARNING: HookManager returned nil");
        }
        
        NSLog(@"[XZX] Scanning Roblox memory...");
        [self scanRobloxMemory];
        NSLog(@"[XZX] Memory scan complete");
        
        NSLog(@"[XZX] Starting game state monitoring...");
        [self startGameStateMonitoring];
        NSLog(@"[XZX] Monitoring started");
        
        NSLog(@"[XZX] Initializing Lua...");
        InitLua();
        NSLog(@"[XZX] Lua initialized successfully");
        
        NSLog(@"[XZX] All systems initialized successfully");
        
    } @catch (NSException *exception) {
        NSLog(@"[XZX] CRASH DURING INITIALIZATION: %@", exception);
        NSLog(@"[XZX] Exception name: %@", exception.name);
        NSLog(@"[XZX] Exception reason: %@", exception.reason);
        NSLog(@"[XZX] Call stack: %@", exception.callStackSymbols);
    } @finally {
        NSLog(@"[XZX] Initialize completed");
    }
}

- (void)scanRobloxMemory {
    @try {
        uint32_t count = _dyld_image_count();
        NSLog(@"[XZX] Found %u loaded images", count);
        
        for (uint32_t i = 0; i < count; i++) {
            const char *name = _dyld_get_image_name(i);
            if (name) {
                NSLog(@"[XZX] Image %u: %s", i, name);
                if (strstr(name, "Roblox") || strstr(name, "RobloxPlayer")) {
                    roblox_base = (uintptr_t)_dyld_get_image_header(i);
                    NSLog(@"[XZX] Found Roblox at base: 0x%lx", (unsigned long)roblox_base);
                    break;
                }
            }
        }
        
        if (roblox_base == 0) {
            NSLog(@"[XZX] WARNING: Could not find Roblox binary");
        }
    } @catch (NSException *exception) {
        NSLog(@"[XZX] Memory scan error: %@", exception);
    }
}

- (void)startGameStateMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            BOOL lastInGame = NO;
            int checkCount = 0;
            
            while (YES) {
                @try {
                    checkCount++;
                    BOOL currentlyInGame = [self checkIfInGame];
                    
                    if (currentlyInGame && !lastInGame) {
                        NSLog(@"[XZX] Game joined detected");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self onGameJoined];
                        });
                    } else if (!currentlyInGame && lastInGame) {
                        NSLog(@"[XZX] Game left detected");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self onGameLeft];
                        });
                    }
                    
                    lastInGame = currentlyInGame;
                    
                    if (checkCount % 60 == 0) {
                        NSLog(@"[XZX] Monitor running, inGame: %d", currentlyInGame);
                    }
                    
                } @catch (NSException *exception) {
                    NSLog(@"[XZX] Monitor thread error: %@", exception);
                }
                
                [NSThread sleepForTimeInterval:1.0];
            }
        }
    });
}

- (BOOL)checkIfInGame {
    // Simple implementation to avoid crashes
    return YES;
}

- (void)onGameJoined {
    if (self.isInGame) {
        NSLog(@"[XZX] Already in game, ignoring duplicate join");
        return;
    }
    
    @try {
        self.isInGame = YES;
        NSLog(@"[XZX] Game joined event fired");
        
        [[XZXAntiDetection shared] randomizeInjectionPattern];
        [[XZXBanProtection shared] simulateHumanBehavior];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GameJoined" object:nil];
        });
    } @catch (NSException *exception) {
        NSLog(@"[XZX] onGameJoined error: %@", exception);
    }
}

- (void)onGameLeft {
    @try {
        self.isInGame = NO;
        NSLog(@"[XZX] Game left event fired");
        
        [[XZXAntiDetection shared] cleanTraces];
        [[XZXBanProtection shared] removeTraces];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"GameLeft" object:nil];
        });
    } @catch (NSException *exception) {
        NSLog(@"[XZX] onGameLeft error: %@", exception);
    }
}

void notify_game_joined(void) {
    [[XZXCore shared] onGameJoined];
}

void notify_game_left(void) {
    [[XZXCore shared] onGameLeft];
}

@end
