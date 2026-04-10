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
        // Wait for Roblox runtime to fully load before polling.
        // Without this, DataModel isn't available yet and isPlayerInGame()
        // returns false for the first few seconds, then may briefly return true
        // from a stale previous session placeId — causing wrong triggers.
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

                // Entered game — require kDebounceThreshold consecutive positives
                // to avoid triggering during loading screen transitions.
                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected — creating in-game UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                }
                // Left game — require kDebounceThreshold consecutive negatives
                // to avoid hiding on brief disconnects or teleports.
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
    // Guard: only show when the monitor has confirmed we are in game.
    if (!self.inGame) {
        NSLog(@"[XZX] showOverlay called while not in game — ignored");
        return;
    }
    [[XZXUIBridge shared] createInGameUI];
    [[XZXUIBridge shared] showUI];
    // Set up the RemoteEvent bridge once after the UI exists in CoreGui.
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
