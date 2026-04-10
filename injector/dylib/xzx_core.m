#import "xzx_core.h"
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
// Gate: must see Roblox home screen WebView before in-game detection is trusted.
// Prevents the launch loading screen (Metal=YES, WebView=NO) from
// falsely triggering in-game detection on first open.
@property (nonatomic, assign) BOOL hasSeenHomeScreen;
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
        _positiveCount = 0;
        _negativeCount = 0;
        _hasSeenHomeScreen = NO;
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
        // Wait for Roblox to finish its initial launch
        [NSThread sleepForTimeInterval:5.0];

        // Fallback: if WebView never appears within 15s, unlock detection anyway.
        // This handles Roblox versions that don't use WKWebView for the home screen.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(15.0 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (!self.hasSeenHomeScreen) {
                self.hasSeenHomeScreen = YES;
                NSLog(@"[XZX] Home screen fallback timer fired - detection unlocked");
            }
        });

        while (YES) {
            @autoreleasepool {
                __block BOOL hasMetalLayer = NO;
                __block BOOL hasWebView = NO;

                dispatch_sync(dispatch_get_main_queue(), ^{
                    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if ([scene isKindOfClass:[UIWindowScene class]]) {
                            UIWindowScene *ws = (UIWindowScene *)scene;
                            for (UIWindow *window in ws.windows) {
                                if ([self viewHasMetalLayer:window]) hasMetalLayer = YES;
                                if ([self viewHasWebView:window]) hasWebView = YES;
                            }
                        }
                    }
                });

                if (!self.hasSeenHomeScreen && hasWebView) {
                    self.hasSeenHomeScreen = YES;
                    NSLog(@"[XZX] Home screen confirmed - detection active");
                }

                BOOL raw = self.hasSeenHomeScreen && hasMetalLayer && !hasWebView;

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
                    NSLog(@"[XZX] Game detected - showing UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self showOverlay];
                    });
                } else if (self.inGame && self.negativeCount >= kDebounceThreshold) {
                    self.inGame = NO;
                    self.negativeCount = 0;
                    self.hasSeenHomeScreen = NO;
                    NSLog(@"[XZX] Left game - hiding UI");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self hideOverlay];
                    });
                }
            }
            [NSThread sleepForTimeInterval:1.0];
        }
    });
}

// Recursively checks for CAMetalLayer. Must be called on main thread.
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

// Recursively checks for WKWebView. Must be called on main thread.
- (BOOL)viewHasWebView:(UIView *)view {
    @try {
        NSString *cn = NSStringFromClass([view class]);
        if ([cn containsString:@"WKWebView"] ||
            [cn containsString:@"WebView"]) return YES;
        for (UIView *sub in view.subviews) {
            if ([self viewHasWebView:sub]) return YES;
        }
    } @catch (NSException *e) {}
    return NO;
}

- (BOOL)isGameEngineActive {
    // This method is now unused — logic moved into startGameMonitoring
    // for efficiency. Kept to satisfy header declaration.
    return self.inGame;
}

- (void)showOverlay {
    if (_overlayWindow && !_overlayWindow.hidden) return;

    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindowScene *scene = nil;
        for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
            if ([s isKindOfClass:[UIWindowScene class]]) {
                scene = (UIWindowScene *)s;
                break;
            }
        }
        if (!scene) { NSLog(@"[XZX] No scene found"); return; }

        UIViewController *vc = [[NSClassFromString(@"XZXMainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"XZX.MainViewController") alloc] init];
        if (!vc) vc = [[NSClassFromString(@"MainViewController") alloc] init];
        if (!vc) { NSLog(@"[XZX] ERROR: MainViewController not found"); return; }

        if (!self.overlayWindow) {
            self.overlayWindow = [[UIWindow alloc] initWithWindowScene:scene];
            self.overlayWindow.windowLevel = UIWindowLevelAlert + 1;
            self.overlayWindow.backgroundColor = [UIColor clearColor];
            self.overlayWindow.rootViewController = vc;
        }

        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyAndVisible];
        NSLog(@"[XZX] Overlay shown");
    });
}

- (void)hideOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.overlayWindow.hidden = YES;
        NSLog(@"[XZX] Overlay hidden");
    });
}

- (BOOL)isOverlayVisible { return _overlayWindow && !_overlayWindow.hidden; }
- (BOOL)isInGame { return _inGame; }

@end
