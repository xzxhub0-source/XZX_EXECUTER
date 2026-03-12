#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>

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
        NSLog(@"[XZX] Core instance created");
    }
    return self;
}

- (void)initialize {
    NSLog(@"[XZX] initialize called");
    
    @try {
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        
        [self startGameStateMonitoring];
        NSLog(@"[XZX] Monitoring started");
        
    } @catch (NSException *exception) {
        NSLog(@"[XZX] CRASH: %@", exception);
    }
}

- (void)startGameStateMonitoring {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        @autoreleasepool {
            BOOL lastInGame = NO;
            while (YES) {
                @try {
                    [NSThread sleepForTimeInterval:1.0];
                    BOOL currentlyInGame = YES;
                    
                    if (currentlyInGame && !lastInGame) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self onGameJoined];
                        });
                    }
                    lastInGame = currentlyInGame;
                } @catch (NSException *e) {
                    NSLog(@"[XZX] Monitor error: %@", e);
                }
            }
        }
    });
}

- (void)onGameJoined {
    self.isInGame = YES;
    NSLog(@"[XZX] Game joined");
}

- (void)onGameLeft {
    self.isInGame = NO;
    NSLog(@"[XZX] Game left");
}

void notify_game_joined(void) {
    [[XZXCore shared] onGameJoined];
}

void notify_game_left(void) {
    [[XZXCore shared] onGameLeft];
}

@end
