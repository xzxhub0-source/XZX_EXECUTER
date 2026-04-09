#import "xzx_core.h"
#import "xzx_hooks.h"
#import "Core/LuaExecutor.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <objc/message.h>

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
        _overlayWindow = nil;
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
    if (_overlayWindow) _overlayWindow.hidden = YES;
    NSLog(@"[XZX] Initialized, watching for game...");
    [self startGameMonitoring];
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:5.0];

        while (YES) {
            @autoreleasepool {
                BOOL raw = [self isInGameCheck];

                if (raw) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] In-game confirmed");
                    dispatch_after(
                        dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)),
                        dispatch_get_main_queue(), ^{
                            [self showOverlay];
                        });
                }

                if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Left game");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (BOOL)isInGameCheck {
    @try {
        NSArray *classNames = @[
            @"RBXDataModel",
            @"RobloxDataModel",
            @"DataModel",
            @"RBXGame",
            @"RobloxGame"
        ];

        Class dmClass = nil;
        for (NSString *name in classNames) {
            dmClass = NSClassFromString(name);
            if (dmClass) break;
        }

        if (dmClass) {
            return (BOOL)isPlayerInGame();
        }

        return NO;
    } @catch (NSException *e) {
        NSLog(@"[XZX] isInGameCheck error: %@", e);
    }
    return NO;
}

- (void)showOverlay {
    if (!self.inGame) {
        NSLog(@"[XZX] showOverlay called while not in game — ignored");
        return;
    }
    if (_overlayWindow && !_overlayWindow.hidden) return;

    UIWindowScene *scene = (UIWindowScene *)
        [UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    if (!scene) { NSLog(@"[XZX] No scene"); return; }

    if (!self.overlayWindow) {
        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) { NSLog(@"[XZX] ERROR: Could not resolve MainViewController"); return; }

        self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        self.overlayWindow.backgroundColor = [UIColor clearColor];
        self.overlayWindow.hidden = YES;
        self.overlayWindow.rootViewController = vc;
    }

    self.overlayWindow.hidden = NO;
    [self.overlayWindow makeKeyAndVisible];
    NSLog(@"[XZX] Overlay shown");
}

- (void)hideOverlay {
    if (!_overlayWindow) return;
    _overlayWindow.hidden = YES;
    UIWindow *robloxWin = [UIApplication sharedApplication].windows.firstObject;
    if (robloxWin) [robloxWin makeKeyWindow];
    NSLog(@"[XZX] Overlay hidden");
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame         { return _inGame; }

@end
