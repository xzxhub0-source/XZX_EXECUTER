#import "xzx_core.h"
#import "Core/LuaExecutor.h"
#import "XZXMainViewController.h"
#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>

static XZXCore *sharedCore = nil;
static dispatch_queue_t monitorQueue = nil;
static BOOL gameDetectionActive = NO;

// Menu and game both have Metal + hidden status bar.
// The ONLY reliable difference: menu has a WKWebView, in-game does not.
// Show after 3 consecutive in-game positives, hide after 20 consecutive negatives.
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
        _overlayWindow  = nil;
        _isInitialized  = NO;
        _inGame         = NO;
        _positiveCount  = 0;
        _negativeCount  = 0;
        monitorQueue = dispatch_queue_create("com.xzx.monitor", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)initialize {
    if (_isInitialized) return;
    _isInitialized = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        InitLua();
        NSLog(@"[XZX] Lua initialized");
        [self startGameMonitoring];
    });
}

- (void)startGameMonitoring {
    if (gameDetectionActive) return;
    gameDetectionActive = YES;

    dispatch_async(monitorQueue, ^{
        // 8s startup wait — let Roblox fully launch before we start scanning
        [NSThread sleepForTimeInterval:8.0];
        NSLog(@"[XZX] Detection started");

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
                    NSLog(@"[XZX] In-game confirmed — showing overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                        [self startWatchdog];
                    });
                } else if (self.inGame && self.negativeCount >= kDebounceHide) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    NSLog(@"[XZX] Left game — hiding overlay");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

// Watchdog: if we're supposed to be in-game but window died, revive it
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
        NSLog(@"[XZX] Watchdog: window gone — reviving");
        _overlayWindow = nil;
        [self showOverlay];
    }
}

// THE FIX: menu has WKWebView, in-game does not.
// Also exclude our own overlay window from all scanning.
- (BOOL)isInGameState {
    @try {
        BOOL hasMetalLayer = NO;
        BOOL statusBarHidden = NO;
        BOOL hasWebView = NO;

        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;

            if (ws.statusBarManager.statusBarHidden) {
                statusBarHidden = YES;
            }

            for (UIWindow *window in ws.windows) {
                // CRITICAL: exclude our own overlay window from all checks
                if (window == _overlayWindow) continue;

                if ([self viewHasMetalLayer:window]) hasMetalLayer = YES;
                if ([self viewHasWebView:window])    hasWebView = YES;
            }
        }

        NSLog(@"[XZX] Metal:%d StatusHidden:%d WebView:%d",
              hasMetalLayer, statusBarHidden, hasWebView);

        // In-game = Metal rendering + fullscreen + NO web view
        // Menu    = Metal rendering + fullscreen + HAS web view (home feed)
        return (hasMetalLayer && statusBarHidden && !hasWebView);

    } @catch (NSException *e) {
        NSLog(@"[XZX] Detection error: %@", e);
    }
    return NO;
}

// Check for WKWebView or any web-based view (Roblox menu home feed)
- (BOOL)viewHasWebView:(UIView *)view {
    @try {
        if ([view isKindOfClass:[WKWebView class]]) return YES;
        NSString *className = NSStringFromClass([view class]);
        if ([className containsString:@"WebView"] ||
            [className containsString:@"WKWeb"] ||
            [className containsString:@"BrowserView"]) return YES;
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
            scene = (UIWindowScene *)s;
            break;
        }
    }
    if (!scene) {
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
    }
    if (!scene) { NSLog(@"[XZX] No scene found"); return; }

    // If scene changed (load→game transition), rebuild window
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
