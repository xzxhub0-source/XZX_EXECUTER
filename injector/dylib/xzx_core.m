#import "xzx_core.h"
#import "xzx_hooks.h"
#import "xzx_uibridge.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;
static const NSInteger kDebounceThreshold = 3;

@interface XZXCore ()
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@end

@implementation XZXCore

+ (instancetype)shared {
    static dispatch_once_t once;
    dispatch_once(&once, ^{ sharedCore = [[self alloc] init]; });
    return sharedCore;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isInitialized = NO;
        _inGame        = NO;
        _positiveCount = 0;
        _negativeCount = 0;
        monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    InitLua();
    NSLog(@"[XZX] Lua initialized");
    [self startGameMonitoring];
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // Wait for Roblox's runtime + DataModel to finish loading.
        // Without this, isPlayerInGame() always returns false for the first
        // few seconds, positiveCount never increments, BUT if the undefined
        // symbol bug existed it would fire immediately. With the correct
        // isPlayerInGame() now in place, this delay ensures we don't query
        // DataModel before it exists.
        [NSThread sleepForTimeInterval:5.0];
        NSLog(@"[XZX] Monitoring placeId...");

        while (YES) {
            @autoreleasepool {
                BOOL inGameNow = isPlayerInGame();

                if (inGameNow) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                // Need 3 consecutive positives before showing UI.
                // Prevents false triggers during loading screen transitions.
                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected — creating in-game UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                }
                // Need 3 consecutive negatives before hiding UI.
                // Prevents flickering on brief disconnects or teleports.
                else if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Left game — removing UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (void)showOverlay {
    if (!self.inGame) {
        NSLog(@"[XZX] showOverlay called while not in game — ignored");
        return;
    }
    [[XZXUIBridge shared] createInGameUI];
    [[XZXUIBridge shared] showUI];
    static dispatch_once_t onceBridge;
    dispatch_once(&onceBridge, ^{
        setupRemoteEventBridge();
    });
}

- (void)hideOverlay {
    [[XZXUIBridge shared] hideUI];
    [[XZXUIBridge shared] destroyInGameUI];
}

- (BOOL)isOverlayVisible {
    return self.inGame;
}

- (BOOL)isInGame {
    return _inGame;
}

@end
