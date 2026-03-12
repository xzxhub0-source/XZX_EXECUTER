#import "xzx_core.h"
#import "xzx_antidetection.h"
#import "xzx_ban_protection.h"
#import "xzx_injection_randomizer.h"
#import "xzx_hook_manager.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

static XZXCore *sharedCoreInstance = nil;

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedCoreInstance = [[XZXCore alloc] init];
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

// REMOVED +load method completely - no automatic initialization

- (void)initialize {
    NSLog(@"[XZX] Manual initialize called");
    
    @try {
        // Initialize Lua first (most basic)
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        // Initialize protection systems
        [[XZXAntiDetection shared] initializeProtection];
        [[XZXBanProtection shared] protectAccount];
        [[XZXInjectionRandomizer shared] randomizeNextInjection];
        [[XZXHookManager shared] initializeHookSystem];
        
        [self startGameStateMonitoring];
        NSLog(@"[XZX] All systems initialized");
        
    } @catch (NSException *exception) {
        NSLog(@"[XZX] INIT ERROR: %@", exception);
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
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GameJoined" object:nil];
}

- (void)onGameLeft {
    self.isInGame = NO;
    NSLog(@"[XZX] Game left");
    [[NSNotificationCenter defaultCenter] postNotificationName:@"GameLeft" object:nil];
}

@end
