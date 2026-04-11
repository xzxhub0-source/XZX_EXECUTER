#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;

static const NSInteger kDebounceShow = 3;
static const NSInteger kDebounceHide = 20;

@interface XZXCore ()
@property (nonatomic, assign) NSInteger positiveCount;
@property (nonatomic, assign) NSInteger negativeCount;
@property (nonatomic, strong) UIWindow *overlayWindow;
@property (nonatomic, strong) NSTimer  *watchdogTimer;
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
    dispatch_async(dispatch_get_main_queue(), ^{
        InitLua();
        NSLog(@"[XZX] Initialized");
        [self startGameMonitoring];
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        [NSThread sleepForTimeInterval:8.0];
        NSLog(@"[XZX] Detection loop started");

        while (YES) {
            @autoreleasepool {
                __block BOOL inGame = NO;
                dispatch_sync(dispatch_get_main_queue(), ^{
                    inGame = [self isInGameState];
                });

                if (inGame) {
                    self.positiveCount++;
                    self.negativeCount = 0;
                } else {
                    self.negativeCount++;
                    self.positiveCount = 0;
                }

                if (!self.inGame && self.positiveCount >= kDebounceShow) {
                    self.inGame = YES;
                    self.positiveCount = 0;
                    NSLog(@"[XZX] ✅ IN GAME — showing overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                        [self startWatchdog];
                    });
                } else if (self.inGame && self.negativeCount >= kDebounceHide) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] ❌ LEFT GAME — hiding overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

- (void)startWatchdog {
    [_watchdogTimer invalidate];
    _watchdogTimer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                                      target:self
                                                    selector:@selector(watchdogTick)
                                                    userInfo:nil
                                                     repeats:YES];
}

- (void)watchdogTick {
    if (!self.inGame) return;
    if (!_overlayWindow || _overlayWindow.hidden) {
        NSLog(@"[XZX] Watchdog: reviving overlay");
        _overlayWindow = nil;
        [self showOverlay];
    }
}

- (BOOL)isInGameState {
    @try {
        BOOL hasMetalLayer  = NO;
        BOOL hasWebView     = NO;
        BOOL statusBarHidden = NO;

        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;

            if (ws.statusBarManager.statusBarHidden) statusBarHidden = YES;

            for (UIWindow *window in ws.windows) {
                // Always skip our own overlay window
                if (window == _overlayWindow) continue;

                // Log every non-overlay VC so we can see exactly what Roblox exposes
                UIViewController *rvc = window.rootViewController;
                if (rvc) {
                    NSLog(@"[XZX] Window VC: %@ | key:%d",
                          NSStringFromClass([rvc class]), window.isKeyWindow);
                    // Log child VCs
                    for (UIViewController *child in rvc.childViewControllers) {
                        NSLog(@"[XZX]   Child VC: %@", NSStringFromClass([child class]));
                    }
                }

                // Metal check
                if ([self viewHasMetalLayer:window]) hasMetalLayer = YES;

                // WebView check — Roblox home feed uses WKWebView
                // If WKWebView is present → we're in the menu
                if ([self viewHasWebView:window]) {
                    NSLog(@"[XZX] WKWebView detected — menu state");
                    hasWebView = YES;
                }

                // Also check VC class name for game-specific controllers
                UIViewController *vc = window.rootViewController;
                while (vc.presentedViewController) vc = vc.presentedViewController;
                NSString *vcName = NSStringFromClass([vc class]).lowercaseString;
                if ([vcName containsString:@"game"]   ||
                    [vcName containsString:@"render"]  ||
                    [vcName containsString:@"play"]    ||
                    [vcName containsString:@"rbxgame"]) {
                    NSLog(@"[XZX] Game VC found: %@", NSStringFromClass([vc class]));
                    return YES; // Definitive: we're in-game
                }
            }
        }

        NSLog(@"[XZX] Metal:%d WebView:%d StatusHidden:%d",
              hasMetalLayer, hasWebView, statusBarHidden);

        // In-game:  Metal rendering + no WKWebView + fullscreen
        // Menu:     Metal rendering + WKWebView present (home feed)
        return (hasMetalLayer && !hasWebView && statusBarHidden);

    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection error: %@", e);
    }
    return NO;
}

// Roblox menu home feed is a WKWebView
- (BOOL)viewHasWebView:(UIView *)view {
    @try {
        if ([view isKindOfClass:[WKWebView class]]) return YES;
        NSString *cn = NSStringFromClass([view class]);
        if ([cn containsString:@"WebView"] ||
            [cn containsString:@"WKContent"] ||
            [cn containsString:@"WebContent"]) return YES;
        for (UIView *sub in view.subviews) {
            if ([self viewHasWebView:sub]) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (BOOL)viewHasMetalLayer:(UIView *)view {
    @try {
        if ([view.layer isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
        for (CALayer *sub in view.layer.sublayers ?: @[]) {
            if ([sub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            for (CALayer *subsub in sub.sublayers ?: @[]) {
                if ([subsub isKindOfClass:NSClassFromString(@"CAMetalLayer")]) return YES;
            }
        }
        for (UIView *sub in view.subviews) {
            if ([self viewHasMetalLayer:sub]) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    UIWindowScene *scene = nil;
    for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
        if ([s isKindOfClass:[UIWindowScene class]] &&
            s.activationState == UISceneActivationStateForegroundActive) {
            scene = (UIWindowScene *)s; break;
        }
    }
    if (!scene) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s; break;
            }
        }
    }
    if (!scene) { NSLog(@"[XZX] No scene"); return; }

    if (_overlayWindow && _overlayWindow.windowScene != scene) {
        _overlayWindow = nil;
    }

    if (!_overlayWindow) {
        XZXMainViewController *vc = [[XZXMainViewController alloc] init];
        _overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
        _overlayWindow.windowLevel = UIWindowLevelAlert + 1;
        _overlayWindow.backgroundColor = [UIColor clearColor];
        _overlayWindow.rootViewController = vc;
    }

    _overlayWindow.hidden = NO;
    [_overlayWindow makeKeyAndVisible];
    NSLog(@"[XZX] Overlay shown");
}

- (void)hideOverlay {
    [_watchdogTimer invalidate];
    _watchdogTimer = nil;
    _overlayWindow.hidden = YES;
    NSLog(@"[XZX] Overlay hidden");
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
