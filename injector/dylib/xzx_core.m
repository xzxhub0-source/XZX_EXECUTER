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
static const NSInteger kRequiredConfirmations = 2;

@interface XZXCore ()
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@property (nonatomic, assign) NSInteger gameConfirmedCount;
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
        _inGame = NO;
        _overlayAllowed = NO;
        _positiveCount = 0;
        _negativeCount = 0;
        _gameConfirmedCount = 0;
        monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    InitLua();
    
    // Ensure nothing is visible
    if (_overlayWindow) _overlayWindow.hidden = YES;
    _overlayAllowed = NO;
    
    NSLog(@"[XZX] Initialized, overlay locked. Will unlock only after confirmed in-game.");
    [self startGameMonitoring];
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;
    
    dispatch_async(monitorQueue, ^{
        // Wait a full 15 seconds for Roblox to settle (login, menu, etc.)
        [NSThread sleepForTimeInterval:15.0];
        
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
                
                // Transition to in-game
                if (!self.inGame && self.positiveCount >= kDebounceThreshold) {
                    self.inGame = YES;
                    self.gameConfirmedCount++;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] Game detected (placeId > 0) - confirmation %ld of %ld",
                          (long)self.gameConfirmedCount, (long)kRequiredConfirmations);
                    
                    if (self.gameConfirmedCount >= kRequiredConfirmations && !self.overlayAllowed) {
                        self.overlayAllowed = YES;
                        NSLog(@"[XZX] Overlay now allowed - showing UI");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [self showOverlay];
                        });
                    }
                }
                
                // Transition out of game
                if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    self.gameConfirmedCount = 0;
                    self.overlayAllowed = NO;  // revoke permission immediately
                    NSLog(@"[XZX] Left game (placeId = 0) - overlay locked again");
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
            @"RobloxDataModel",
            @"RBXDataModel",
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

- (BOOL)isRobloxForeground {
    return [UIApplication sharedApplication].applicationState == UIApplicationStateActive;
}

- (void)showOverlay {
    // Absolute gates
    if (!self.overlayAllowed) {
        NSLog(@"[XZX] showOverlay blocked - overlay not allowed");
        return;
    }
    if (!self.inGame) {
        NSLog(@"[XZX] showOverlay blocked - not in game");
        return;
    }
    if (![self isRobloxForeground]) {
        NSLog(@"[XZX] showOverlay blocked - Roblox not in foreground");
        return;
    }
    if (_overlayWindow && !_overlayWindow.hidden) return;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) {
            NSLog(@"[XZX] No window scene");
            return;
        }
        
        UIViewController *vc = nil;
        vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) {
            NSLog(@"[XZX] ERROR: MainViewController not found");
            return;
        }
        
        if (!self.overlayWindow) {
            self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
            self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
            self.overlayWindow.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = vc;
            self.overlayWindow.hidden = YES;
        }
        
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown (finally allowed)");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.overlayWindow) {
            self.overlayWindow.hidden = YES;
            // Return focus to Roblox
            UIWindow *robloxWindow = nil;
            for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                if ([scene isKindOfClass:[UIWindowScene class]]) {
                    UIWindowScene *ws = (UIWindowScene *)scene;
                    for (UIWindow *win in ws.windows) {
                        if (win != self.overlayWindow) {
                            robloxWindow = win;
                            break;
                        }
                    }
                }
            }
            [robloxWindow makeKeyWindow];
        }
        NSLog(@"[XZX] Overlay hidden");
    });
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
